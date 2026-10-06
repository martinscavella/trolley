import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/chiusura.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/chiusura.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'riepilogo.dart';

/// Chiude i propri viaggi finiti (10, regola 1), e apre il riepilogo di
/// quelli finiti da poco, una volta su questo telefono. Lo fa l'elenco dei
/// viaggi dopo aver riscaricato la copia. Senza rete non fa niente: riproverà.
Future<void> chiudiViaggiFiniti(BuildContext context) async {
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final oggi = DateTime.now();
  final daMostrare = <String>[];
  for (final v in await viaggiDaChiudere(archivio, oggi)) {
    try {
      await chiudiIlViaggio(
        viaggioId: v.id,
        archivio: archivio,
        misurazione: servizi.misurazione,
      );
    } on ErroreTrolley catch (e) {
      if (e.serveLaRete) break;
      continue;
    }
    final fine = v.fine;
    if (fine != null &&
        riepilogoDaSolo(fine: fine, oggi: oggi) &&
        !await archivio.riepilogoVisto(v.id)) {
      daMostrare.add(v.id);
    }
  }
  for (final id in daMostrare) {
    if (!context.mounted) return;
    await archivio.segnaRiepilogoVisto(id);
    if (!context.mounted) return;
    await apriAPienoSchermo<void>(context, SchermataRiepilogo(viaggioId: id));
  }
}

/// «Chiudi il viaggio» prima della fine (tela, 94 e 63): solo chi ne è
/// responsabile, mentre è in corso, dopo una conferma. Richiede la rete.
Future<void> chiudiAMano(BuildContext context, Viaggio viaggio) async {
  final fine = viaggio.fine;
  final quando = fine == null
      ? ''
      : soloData(fine) == soloData(DateTime.now())
      ? 'Si chiuderebbe da solo stasera. '
      : 'Si chiuderebbe da solo ${giornoDellaSettimana(fine)} sera. ';
  var conferma = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: 'Chiudere il viaggio adesso?',
    message:
        '${quando}Dopo, ${titoloViaggio(viaggio)} va nel passaporto e non si '
        'aggiungono più tappe; le spese e i saldi restano.',
    actions: [
      AlertAction(
        title: 'Annulla',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Chiudi',
        style: AlertActionStyle.destructive,
        onPressed: () => conferma = true,
      ),
    ],
  );
  if (!conferma || !context.mounted) return;
  final servizi = Servizi.of(context);
  try {
    await chiudiIlViaggio(
      viaggioId: viaggio.id,
      archivio: servizi.archivio,
      misurazione: servizi.misurazione,
      aMano: true,
    );
    await servizi.archivio.segnaRiepilogoVisto(viaggio.id);
    if (context.mounted) {
      await apriAPienoSchermo<void>(
        context,
        SchermataRiepilogo(viaggioId: viaggio.id),
      );
    }
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
  }
}

/// «Chiudi il viaggio», in fondo a un viaggio in corso (tela, 94): solo per
/// chi ne è responsabile.
class PulsanteChiudiViaggio extends StatelessWidget {
  const PulsanteChiudiViaggio({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: Servizi.of(context).archivio.mioRuolo(viaggio.id),
    builder: (context, ruolo) {
      if (!siChiudeAMano(
        stato: viaggio.statoA(DateTime.now()),
        responsabile: ruolo.data == 'creatore',
      )) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Chiudi il viaggio',
                secondario: true,
                pericolo: true,
                motivo: rete ? null : motivoSenzaRete,
                onPressed: () => chiudiAMano(context, viaggio),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Solo per chi è responsabile, mentre il viaggio è in corso. '
              'Altrimenti si chiude da solo il giorno dopo la fine.',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ),
      );
    },
  );
}

/// L'ingresso al riepilogo in un viaggio concluso (tela, 93).
class IngressoRiepilogo extends StatefulWidget {
  const IngressoRiepilogo({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  State<IngressoRiepilogo> createState() => _IngressoRiepilogoState();
}

class _IngressoRiepilogoState extends State<IngressoRiepilogo> {
  late Future<String> _testo;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    _testo = _leggi();
  }

  Future<String> _leggi() async {
    final archivio = Servizi.of(context).archivio;
    final id = widget.viaggio.id;
    final giorni = await archivio.leggiGiorni(id);
    final ids = {for (final g in giorni) g.id};
    final fatte = (await archivio.leggiTappe(id))
        .where((t) => ids.contains(t.giornoId))
        .where((t) => t.statoTappa == StatoTappa.completata)
        .length;
    final presi = (await archivio.leggiTraguardi())
        .where((t) => t.viaggioId == id)
        .length;
    return [
      '${quanti(giorni.length, 'giorno', 'giorni')}, '
          '${quanti(fatte, 'tappa fatta', 'tappe fatte')}.',
      if (presi > 0) 'Traguardi: $presi.',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _testo,
    builder: (context, testo) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Premibile(
        onTap: () => apriAPienoSchermo<void>(
          context,
          SchermataRiepilogo(viaggioId: widget.viaggio.id),
        ),
        scala: 0.98,
        etichetta: 'Il riepilogo del viaggio. ${testo.data ?? ''}',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colori.bianco,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colori.cobaltoChiaro,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icona(
                      ios: CupertinoIcons.star,
                      android: Icons.star_outline_rounded,
                    ),
                    size: 22,
                    color: Colori.cobalto,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Il riepilogo del viaggio',
                        style: Testi.evidenza.copyWith(
                          color: Colori.inchiostro,
                        ),
                      ),
                      if (testo.data case final t?) ...[
                        const SizedBox(height: 2),
                        Text(
                          t,
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  icona(
                    ios: CupertinoIcons.chevron_right,
                    android: Icons.chevron_right_rounded,
                  ),
                  size: 16,
                  color: Colori.grafite,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
