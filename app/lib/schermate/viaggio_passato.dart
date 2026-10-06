import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/periodo.dart';
import '../dominio/ricordo.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'scelta_destinazione.dart';

/// Un viaggio passato, inserito come ricordo (tela, 67; 10, regole 5–6):
/// dove, il mese e l'anno in cui è cominciato, i giorni se ci si ricorda.
/// Dice prima che sarà importato e non darà traguardi. Con [viaggio] lo
/// cambia. Richiede la rete: senza, lo dice prima.
class FoglioViaggioPassato extends StatefulWidget {
  const FoglioViaggioPassato({super.key, this.viaggio});

  final Viaggio? viaggio;

  @override
  State<FoglioViaggioPassato> createState() => _FoglioViaggioPassatoState();
}

class _FoglioViaggioPassatoState extends State<FoglioViaggioPassato> {
  late Destinazione? _destinazione = widget.viaggio?.destinazione;
  late Periodo? _quando = widget.viaggio?.periodo;
  late final _giorni = TextEditingController(
    text: widget.viaggio?.giorniRicordati?.toString() ?? '',
  );
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    ElencoDestinazioni.carica();
  }

  @override
  void dispose() {
    _giorni.dispose();
    super.dispose();
  }

  Future<void> _scegliDestinazione() async {
    final scelta = await apri<Destinazione>(
      context,
      const SchermataDestinazione(),
    );
    if (scelta != null && mounted) setState(() => _destinazione = scelta);
  }

  /// Il mese e l'anno, con il selettore di sistema: fino a questo mese.
  Future<void> _scegliQuando() async {
    final oggi = DateTime.now();
    final iniziale = _quando?.primoGiorno;
    final scelta = await AdaptiveDatePicker.show(
      context: context,
      mode: CupertinoDatePickerMode.monthYear,
      initialDate: iniziale == null
          ? DateTime(oggi.year - 1, oggi.month)
          : DateTime(iniziale.year, iniziale.month),
      firstDate: DateTime(1950),
      lastDate: DateTime(oggi.year, oggi.month),
    );
    if (scelta != null && mounted) {
      setState(() => _quando = MeseDi(scelta.year, scelta.month));
    }
  }

  String? get _problema => problemaViaggioPassato(
    dove: _destinazione != null,
    quando: _quando,
    giorni: _giorni.text,
    oggi: DateTime.now(),
  );

  Future<void> _salva() async {
    final servizi = Servizi.of(context);
    final navigatore = Navigator.of(context);
    final viaggio = widget.viaggio;
    final giorni = leggiGiorni(_giorni.text);
    setState(() => _inCorso = true);
    try {
      if (viaggio == null) {
        await servizi.archivio.aggiungiViaggioPassato(
          destinazione: _destinazione!,
          quando: _quando!,
          giorni: giorni,
        );
        // Curiosità, non adozione (07): niente dove, niente quando.
        await servizi.misurazione.registra(Eventi.passaportoCompilato, {});
      } else {
        await servizi.archivio.cambiaViaggioPassato(
          viaggio,
          destinazione: _destinazione!,
          quando: _quando!,
          giorni: giorni,
        );
      }
      HapticFeedback.mediumImpact();
      navigatore.pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinazione = _destinazione;
    final quando = _quando;
    final mese = quando == null
        ? null
        : conMaiuscola(nomiDeiMesi[quando.primoGiorno.month - 1]);
    return Foglio(
      titolo: 'Un viaggio passato',
      inBasso: ConLaRete(
        builder: (context, rete) {
          final motivo = rete ? _problema : motivoSenzaRete;
          return AzioniFoglio(
            motivo: motivo,
            azione: PulsanteGrande(
              etichetta: widget.viaggio == null ? 'Aggiungi' : 'Salva',
              inCorso: _inCorso,
              onPressed: motivo == null ? _salva : null,
            ),
          );
        },
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: Text(
            'Per ricordare i viaggi fatti prima di Trolley.',
            style: Testi.secondario.copyWith(color: Colori.grafite),
          ),
        ),
        CampoScelta(
          etichetta: 'Dove',
          simbolo: icona(
            ios: CupertinoIcons.location,
            android: Icons.place_outlined,
          ),
          segnaposto: 'Una città o un paese',
          valore: destinazione == null
              ? null
              : [
                  destinazione.nome,
                  if (destinazione.tipo != TipoDestinazione.paese)
                    ?destinazione.nomePaese,
                ].join(', '),
          onTap: _scegliDestinazione,
        ).entra(context),
        if (destinazione != null &&
            destinazione.tipo == TipoDestinazione.aMano &&
            destinazione.paese == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Senza paese, questo viaggio non comparirà sul mappamondo.',
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Quando',
            style: Testi.etichetta.copyWith(color: Colori.ardesia),
          ),
        ),
        // Il mese e l'anno in cui è cominciato: si toccano tutti e due per
        // sceglierli insieme.
        Semantics(
          button: true,
          label: quando == null
              ? 'Quando: scegli il mese e l\'anno'
              : 'Quando: ${quando.testo}',
          excludeSemantics: true,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Gettone(
                etichetta: mese ?? 'Mese',
                scelto: quando != null,
                onTap: _scegliQuando,
              ),
              Gettone(
                etichetta: quando == null
                    ? 'Anno'
                    : '${quando.primoGiorno.year}',
                scelto: quando != null,
                onTap: _scegliQuando,
              ),
            ],
          ),
        ).entra(context, ritardo: Ritmo.passo),
        const SizedBox(height: 18),
        Campo(
          controller: _giorni,
          etichetta: 'Quanti giorni, se ti ricordi',
          segnaposto: 'Facoltativo',
          tastiera: TextInputType.number,
          onCambia: (_) => setState(() {}),
        ).entra(context, ritardo: Ritmo.passo * 2),
        const SizedBox(height: 18),
        Avviso(
          fondo: Colori.foschia,
          icona: icona(
            ios: CupertinoIcons.tickets,
            android: Icons.confirmation_number_outlined,
          ),
          inizio: 'Sarà segnato come importato:',
          testo:
              'riempie il passaporto e il mappamondo, ma non dà traguardi. '
              'Non possiamo sapere com\'è andato.',
        ),
      ],
    );
  }
}

/// Toccando un viaggio passato nel passaporto (tela, 98): il menu di sistema
/// per cambiarlo o toglierlo. L'ha aggiunto a mano chi guarda, e a mano lo
/// toglie; un viaggio vero chiuso invece resta per sempre (10, regola 8).
Future<void> gestiViaggioPassato(BuildContext context, Viaggio viaggio) {
  final rete = Servizi.of(context).rete.disponibile;
  return scegliAzione(
    context,
    [
      AzioneMenu(
        'Cambia',
        () => apriFoglio<void>(context, FoglioViaggioPassato(viaggio: viaggio)),
      ),
      if (rete)
        AzioneMenu(
          'Togli dal passaporto',
          () => _togli(context, viaggio),
          pericolo: true,
        ),
    ],
    titolo: '${titoloViaggio(viaggio)} · ${quandoViaggioPassato(viaggio)}',
    messaggio: rete
        ? 'L\'hai aggiunto a mano: puoi cambiarlo o toglierlo dal passaporto.'
        : 'L\'hai aggiunto a mano. Per cambiarlo o toglierlo serve la '
              'connessione.',
  );
}

Future<void> _togli(BuildContext context, Viaggio viaggio) async {
  try {
    await Servizi.of(context).archivio.togliViaggioPassato(viaggio);
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      mostraMessaggio(
        context,
        '${titoloViaggio(viaggio)} non è più nel passaporto.',
      );
    }
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
  }
}
