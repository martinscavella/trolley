import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../configurazione.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dati/pagine.dart';
import '../dominio/ricordo.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'i_tuoi_dati.dart';
import 'mappamondo.dart';
import 'pagine_del_sito.dart';
import 'passaporto.dart';
import 'scelta_valuta.dart';
import 'traguardi.dart';

/// Il profilo, la misurazione, l'uscita.
class SchermataImpostazioni extends StatefulWidget {
  const SchermataImpostazioni({super.key});

  @override
  State<SchermataImpostazioni> createState() => _SchermataImpostazioniState();
}

class _SchermataImpostazioniState extends State<SchermataImpostazioni> {
  bool? _misurazioneAttiva;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_misurazioneAttiva == null) {
      Servizi.of(context).misurazione.attiva.then((attiva) {
        if (mounted) setState(() => _misurazioneAttiva = attiva);
      });
    }
  }

  Future<void> _cambiaMisurazione(bool attiva) async {
    setState(() => _misurazioneAttiva = attiva);
    await Servizi.of(context).misurazione.imposta(attiva: attiva);
  }

  /// La valuta in cui si vedono le spese (06, regola 4). È del profilo: vale
  /// su ogni telefono, e cambiarla richiede la rete.
  Future<void> _cambiaValuta(String attuale) async {
    final archivio = Servizi.of(context).archivio;
    final scelta = await apri<String>(
      context,
      SchermataValuta(
        titolo: 'La tua valuta',
        spiegazione:
            'Le spese si mostrano convertite in questa. Di solito è quella '
            'del tuo conto: il cambio lo fa la banca, e la spesa arriva già '
            'convertita.',
        scelta: attuale,
      ),
      dalBasso: true,
    );
    if (scelta == null || scelta == attuale || !mounted) return;
    try {
      await archivio.cambiaValuta(scelta);
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  Future<void> _esci() async {
    final servizi = Servizi.of(context);
    final auth = servizi.supabase.auth;
    // I documenti non sono sul server: chi esce deve sapere dove restano.
    final documenti = await servizi.documenti.osservaQuanti().first;
    if (!mounted) return;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Vuoi uscire?',
      message: [
        'I tuoi viaggi restano salvati: li ritrovi quando rientri, anche da '
            'un altro telefono.',
        if (documenti > 0)
          'I documenti invece restano solo su questo telefono: li ritrovi '
              'qui, rientrando.',
      ].join(' '),
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Esci',
          style: AlertActionStyle.destructive,
          onPressed: () => auth.signOut(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
    final t = Tavolozza.of(context);
    final email = servizi.supabase.auth.currentUser?.email;
    return Pagina(
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 4,
            20,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            StreamBuilder<Utente?>(
              stream: servizi.archivio.osservaProfilo(),
              builder: (context, snapshot) {
                final nome = snapshot.data?.nome ?? '';
                return Row(
                  children: [
                    Avatar(nome: nome, dimensione: 68).sboccia(context),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              nome,
                              style: Testi.titoloFoglio.copyWith(
                                color: t.testo,
                              ),
                            ),
                          ),
                          if (email != null)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Testi.secondario.copyWith(
                                color: t.testoSecondario,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ).entra(context, da: 8);
              },
            ),
            const SizedBox(height: 18),
            const _Ricordo(),
            const SizedBox(height: 8),
            const RigaTraguardi().entra(context, ritardo: Ritmo.passo * 3),
            const SizedBox(height: 18),
            const EtichettaSezione('Impostazioni'),
            StreamBuilder<Utente?>(
              stream: servizi.archivio.osservaProfilo(),
              builder: (context, profilo) {
                final codice =
                    profilo.data?.valutaPredefinita ?? valutaIniziale;
                return ConLaRete(
                  builder: (context, rete) => RigaScheda(
                    simbolo: icona(
                      ios: CupertinoIcons.money_euro_circle,
                      android: Icons.payments_outlined,
                    ),
                    titolo: 'La tua valuta',
                    valore: nomeCortoValuta(codice),
                    onTap: rete ? () => _cambiaValuta(codice) : null,
                  ),
                );
              },
            ).entra(context, ritardo: Ritmo.passo * 4),
            ConLaRete(
              builder: (context, rete) => Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Text(
                  rete
                      ? 'Le spese restano nella valuta in cui le hai pagate: '
                            'questa serve a sommarle.'
                      : 'Per cambiare la valuta serve la connessione.',
                  style: Testi.didascalia.copyWith(color: t.testoSecondario),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const EtichettaSezione('Privacy'),
            Pannello(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              raggio: 18,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Misurazione',
                      style: Testi.evidenza.copyWith(color: t.testo),
                    ),
                  ),
                  if (_misurazioneAttiva != null)
                    AdaptiveSwitch(
                      value: _misurazioneAttiva!,
                      onChanged: _cambiaMisurazione,
                    ),
                ],
              ),
            ).entra(context, ritardo: Ritmo.passo * 5),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: ConLaRete(
                builder: (context, rete) => TestoConRimando(
                  'Trolley registra le azioni che fai, come "creato un '
                  'viaggio" o "aperto un invito", per capire quali funzioni '
                  'servono davvero. Mai i contenuti: né testi, né documenti, '
                  'né dove ti trovi. Se la spegni non perdi nessuna funzione. '
                  '**Cosa misuriamo**',
                  onTap: rete
                      ? () => apriLaPagina(context, PaginaDelSito.misurazione)
                      : null,
                  motivo: motivoSenzaRete,
                  stile: Testi.didascalia.copyWith(color: t.testoSecondario),
                ),
              ),
            ).entra(context, ritardo: Ritmo.passo * 5),
            const SizedBox(height: 14),
            RigaScheda(
              simbolo: icona(
                ios: CupertinoIcons.arrow_down_doc,
                android: Icons.download_rounded,
              ),
              titolo: 'I tuoi dati',
              sottotitolo: "Scaricarli, o chiudere l'account",
              onTap: () => apri<void>(context, const SchermataITuoiDati()),
            ).entra(context, ritardo: Ritmo.passo * 5),
            const SizedBox(height: 8),
            ConLaRete(
              builder: (context, rete) => RigaScheda(
                simbolo: icona(
                  ios: CupertinoIcons.checkmark_shield,
                  android: Icons.verified_user_outlined,
                ),
                titolo: 'Informativa sulla privacy',
                sottotitolo: rete
                    ? 'Che cosa trattiamo, e perché'
                    : motivoSenzaRete,
                onTap: rete
                    ? () => apriLaPagina(context, PaginaDelSito.privacy)
                    : null,
              ),
            ).entra(context, ritardo: Ritmo.passo * 5),
            const SizedBox(height: 20),
            PulsanteGrande(
              etichetta: 'Esci',
              secondario: true,
              pericolo: true,
              onPressed: _esci,
            ).entra(context, ritardo: Ritmo.passo * 6),
            const SizedBox(height: 20),
            Text(
              'Trolley $versioneApp · prova privata',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: t.testoTerziario),
            ),
          ],
        ),
      ),
    );
  }
}

/// I numeri del ricordo e le due righe che ci portano (tela, 64): quanti
/// viaggi, paesi e città, il passaporto e il mappamondo. Dalla copia.
class _Ricordo extends StatelessWidget {
  const _Ricordo();

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<Set<String>>(
      stream: archivio.osservaPaesiScoperti(),
      builder: (context, scoperti) =>
          StreamBuilder<List<(Partecipazione, Viaggio)>>(
            stream: archivio.osservaMieiViaggi(),
            builder: (context, letti) {
              final viaggi = delPassaporto(
                letti.data ?? const [],
                DateTime.now(),
              );
              final mete = meteDi(viaggi);
              final paesi = paesiGrattati(mete).length;
              final citta = cittaGrattate(mete).length;
              final daScoprire = scoperti.hasData
                  ? daGrattare(
                      visiteDi(viaggi),
                      scoperti: scoperti.data!,
                      oggi: DateTime.now(),
                    ).length
                  : 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final (i, (etichetta, n)) in [
                        ('Viaggi', viaggi.length),
                        ('Paesi', paesi),
                        ('Città', citta),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _Numero(etichetta, n)),
                      ],
                    ],
                  ).entra(context, ritardo: Ritmo.passo),
                  const SizedBox(height: 14),
                  RigaScheda(
                    simbolo: icona(
                      ios: CupertinoIcons.tickets,
                      android: Icons.confirmation_number_outlined,
                    ),
                    titolo: 'Passaporto',
                    valore: quanti(viaggi.length, 'viaggio', 'viaggi'),
                    onTap: () =>
                        apri<void>(context, const SchermataPassaporto()),
                  ).entra(context, ritardo: Ritmo.passo * 2),
                  const SizedBox(height: 8),
                  RigaScheda(
                    simbolo: icona(
                      ios: CupertinoIcons.globe,
                      android: Icons.public_rounded,
                    ),
                    titolo: 'Mappamondo',
                    valore: daScoprire > 0
                        ? '$daScoprire da grattare'
                        : quanti(paesi, 'paese', 'paesi'),
                    onTap: () =>
                        apri<void>(context, const SchermataMappamondo()),
                  ).entra(context, ritardo: Ritmo.passo * 2),
                ],
              );
            },
          ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.etichetta, this.n);

  final String etichetta;
  final int n;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$etichetta: $n',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etichetta.toUpperCase(),
              style: Testi.sezione.copyWith(color: Colori.grafite),
            ),
            const SizedBox(height: 4),
            Text(
              '$n',
              style: Testi.titoli(20).copyWith(color: Colori.inchiostro),
            ),
          ],
        ),
      ),
    ),
  );
}
