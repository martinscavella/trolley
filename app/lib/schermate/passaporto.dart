import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/barra.dart';
import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/mappamondo.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/timbro.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/mappa.dart';
import '../dominio/ricordo.dart';
import '../dominio/traguardi.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'impostazioni.dart';
import 'mappamondo.dart';
import 'traguardi.dart';
import 'viaggio.dart';
import 'viaggio_passato.dart';

/// Il passaporto, una sezione dell'app (10-chiusura-e-ricordo.md; tela, 123
/// e 65): i numeri del ricordo, il mappamondo che si vede già, con il paese
/// da grattare, i traguardi presi e i primi da prendere, e sotto tutti i
/// viaggi chiusi, verificati o no, per anno e dal più recente, come biglietti
/// d'inchiostro. Quelli verificati per chi guarda hanno il timbro. Un
/// biglietto apre il viaggio concluso. In fondo, «Prima di Trolley», i viaggi
/// passati aggiunti a mano: bianchi, tratteggiati, con il timbro «importato»
/// (regola 6), e il «+» in alto per aggiungerne. Si legge dalla copia, anche
/// senza rete.
class SchermataPassaporto extends StatefulWidget {
  const SchermataPassaporto({super.key});

  @override
  State<SchermataPassaporto> createState() => _SchermataPassaportoState();
}

class _SchermataPassaportoState extends State<SchermataPassaporto> {
  late Stream<List<(Partecipazione, Viaggio)>> _miei;
  late Stream<Set<String>> _scoperti;
  late Stream<List<TraguardoPreso>> _presi;
  ElencoDestinazioni? _elenco;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _miei = archivio.osservaMieiViaggi();
    _scoperti = archivio.osservaPaesiScoperti();
    _presi = archivio.osservaTraguardi();
    ElencoDestinazioni.carica().then((elenco) {
      if (mounted) setState(() => _elenco = elenco);
    });
    unawaited(segnaAperturaSenzaRete(context, 'passaporto'));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Set<String>>(
    stream: _scoperti,
    builder: (context, scoperti) => StreamBuilder<List<TraguardoPreso>>(
      stream: _presi,
      builder: (context, presi) =>
          StreamBuilder<List<(Partecipazione, Viaggio)>>(
            stream: _miei,
            builder: (context, letti) => _pagina(
              context,
              viaggi: delPassaporto(letti.data ?? const [], DateTime.now()),
              scoperti: scoperti.data,
              presi: {
                for (final t in presi.data ?? const <TraguardoPreso>[])
                  ?Traguardo.leggi(t.tipo),
              },
            ),
          ),
    ),
  );

  Widget _pagina(
    BuildContext context, {
    required List<(Partecipazione, Viaggio)> viaggi,
    required Set<String>? scoperti,
    required Set<Traguardo> presi,
  }) {
    final pagine = perAnno([
      for (final pv in viaggi)
        if (!pv.$2.importato) pv,
    ], (pv) => pv.$2.inizio ?? pv.$2.creato);
    final passati = [
      for (final (_, v) in viaggi)
        if (v.importato) v,
    ];
    final mete = meteDi(viaggi);
    final paesi = paesiGrattati(mete);
    final citta = cittaGrattate(mete).length;
    // Finché non si sa che cosa è già scoperto, non si dice da grattare.
    final daScoprire = scoperti == null
        ? const <String>[]
        : daGrattare(
            visiteDi(viaggi),
            scoperti: scoperti,
            oggi: DateTime.now(),
          );
    final punti = puntiDeiPaesi(_elenco, mete);
    var n = 3;
    return Pagina(
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            BarraPrincipale.ingombro + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            TitoloPagina(
              'Passaporto',
              sottotitolo: viaggi.isEmpty
                  ? 'Qui finisce ogni viaggio chiuso, verificato o no. '
                        'Quelli fatti prima di Trolley li aggiungi tu, con il +.'
                  : null,
              accanto: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulsanteTondo(
                    icona: icona(ios: CupertinoIcons.add, android: Icons.add),
                    etichetta: 'Aggiungi un viaggio passato',
                    onPressed: () =>
                        apriFoglio<void>(context, const FoglioViaggioPassato()),
                  ),
                  const SizedBox(width: 8),
                  const PulsanteProfilo(),
                ],
              ),
            ).entra(context),
            Row(
              children: [
                for (final (i, (etichetta, quanti)) in [
                  ('Viaggi', viaggi.length),
                  ('Paesi', paesi.length),
                  ('Città', citta),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _Numero(etichetta, quanti)),
                ],
              ],
            ).entra(context, ritardo: Ritmo.passo),
            const SizedBox(height: 12),
            _SchedaMappamondo(
              paesi: paesi,
              citta: citta,
              daScoprire: daScoprire.toSet(),
              punti: punti,
              centro:
                  (paesi.isEmpty ? null : punti[paesi.first]) ??
                  centroSenzaViaggi,
            ).entra(context, ritardo: Ritmo.passo * 2),
            const SizedBox(height: 10),
            _SchedaTraguardi(presi: presi)
                .entra(context, ritardo: Ritmo.passo * 3),
            const SizedBox(height: 8),
            for (final (anno, delAnno) in pagine) ...[
              EtichettaSezione('$anno'),
              for (final (p, v) in delAnno)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PaginaPassaporto(
                    viaggio: v,
                    verificato: p.verificato == true,
                  ),
                ).entra(context, ritardo: Ritmo.passo * min(++n, 8)),
            ],
            if (passati.isNotEmpty) ...[
              const EtichettaSezione('Prima di Trolley'),
              for (final v in passati)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PaginaPassata(viaggio: v),
                ).entra(context, ritardo: Ritmo.passo * min(++n, 8)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uno dei tre numeri del ricordo: viaggi chiusi, paesi, città.
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

/// La freccia delle schede che si aprono.
Widget _freccia() => Icon(
  icona(ios: CupertinoIcons.chevron_right, android: Icons.chevron_right),
  size: 16,
  color: Colori.grafite,
);

/// Il mappamondo che si vede già (tela, 123): il globo, piccolo e fermo,
/// con i paesi grattati, quanti paesi e città, e il paese da grattare.
/// Toccandolo si apre il mappamondo vero, dove si gira e si gratta.
class _SchedaMappamondo extends StatelessWidget {
  const _SchedaMappamondo({
    required this.paesi,
    required this.citta,
    required this.daScoprire,
    required this.punti,
    required this.centro,
  });

  final List<String> paesi;
  final int citta;
  final Set<String> daScoprire;
  final Map<String, Coordinate> punti;
  final Coordinate centro;

  @override
  Widget build(BuildContext context) {
    final quanto = [
      quanti(paesi.length, 'paese', 'paesi'),
      quanti(citta, 'città', 'città'),
    ].join(' · ');
    final daGrattare = daScoprire.isEmpty
        ? null
        : '${quanti(daScoprire.length, 'paese', 'paesi')} da grattare';
    return Premibile(
      onTap: () => apri<void>(context, const SchermataMappamondo()),
      scala: 0.985,
      etichetta: ['Mappamondo', quanto, ?daGrattare].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 124,
                child: IgnorePointer(
                  child: Mappamondo(
                    grattati: {
                      for (final p in paesi)
                        if (!daScoprire.contains(p)) p,
                    },
                    centro: centro,
                    punti: punti,
                    etichetta: '',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mappamondo',
                      style: Testi.titoli(17)
                          .copyWith(color: Colori.inchiostro),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quanto,
                      style: Testi.secondario.copyWith(color: Colori.grafite),
                    ),
                    if (daGrattare != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFD5DAE3), Colori.argento],
                          ),
                        ),
                        child: Text(
                          daGrattare,
                          style: Testi.didascalia.copyWith(
                            color: Colori.inchiostro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _freccia(),
            ],
          ),
        ),
      ),
    );
  }
}

/// I traguardi (tela, 123): quanti presi, le medaglie prese in cobalto e poi
/// le prime da prendere. Toccandoli si aprono tutti, con quanto manca.
class _SchedaTraguardi extends StatelessWidget {
  const _SchedaTraguardi({required this.presi});

  final Set<Traguardo> presi;

  /// Una medaglia piccola, e lo spazio fra due.
  static const _lato = 40.0;
  static const _fra = 10.0;

  @override
  Widget build(BuildContext context) {
    final valore = switch (presi.length) {
      0 => 'nessuno',
      1 => '1 preso',
      final n => '$n presi',
    };
    final ordine = [
      for (final t in Traguardo.values)
        if (presi.contains(t)) t,
      for (final t in Traguardo.values)
        if (!presi.contains(t)) t,
    ];
    return Premibile(
      onTap: () => apri<void>(context, const SchermataTraguardi()),
      scala: 0.985,
      etichetta: 'Traguardi, $valore',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Traguardi',
                      style: Testi.titoli(17)
                          .copyWith(color: Colori.inchiostro),
                    ),
                  ),
                  Text(
                    valore,
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                  const SizedBox(width: 6),
                  _freccia(),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, vincoli) {
                  final quante = ((vincoli.maxWidth + _fra) / (_lato + _fra))
                      .floor();
                  return Row(
                    children: [
                      for (final (i, t) in ordine.take(quante).indexed) ...[
                        if (i > 0) const SizedBox(width: _fra),
                        _MedagliaPiccola(t, preso: presi.contains(t)),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedagliaPiccola extends StatelessWidget {
  const _MedagliaPiccola(this.traguardo, {required this.preso});

  final Traguardo traguardo;
  final bool preso;

  @override
  Widget build(BuildContext context) => Container(
    width: _SchedaTraguardi._lato,
    height: _SchedaTraguardi._lato,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: preso ? Colori.cobalto : null,
      border: preso
          ? Border.all(
              color: Colori.bianco.withValues(alpha: 0.5),
              width: 1.5,
              strokeAlign: -3,
            )
          : Border.all(color: Colori.piombo, width: 2),
    ),
    child: Icon(
      iconaTraguardo(traguardo),
      size: 18,
      color: preso ? Colori.bianco : Colori.piombo,
    ),
  );
}

/// Un viaggio del passaporto: il biglietto d'inchiostro, con quando e quanti
/// giorni, e il timbro se è verificato. Anche nella scheda di un paese del
/// mappamondo (tela, 147).
class PaginaPassaporto extends StatelessWidget {
  const PaginaPassaporto({
    super.key,
    required this.viaggio,
    required this.verificato,
  });

  final Viaggio viaggio;
  final bool verificato;

  @override
  Widget build(BuildContext context) {
    final v = viaggio;
    final (inizio, fine) = (v.inizio, v.fine);
    final quando = inizio == null || fine == null
        ? quandoViaggio(v)
        : '${intervalloBreve(inizio, fine)} · '
              '${quanti(giorniDiCalendario(inizio, fine), 'giorno', 'giorni')}';
    return BigliettoBasso(
      codice: codiceViaggio(v),
      titolo: titoloViaggio(v),
      sottotitolo: quando,
      colore: Colori.inchiostro,
      timbro: verificato ? const TimbroScritto('VERIFICATO') : null,
      etichetta: [
        titoloViaggio(v),
        quando,
        if (verificato) 'verificato',
      ].join(', '),
      onTap: () => apri<void>(context, SchermataViaggio(viaggioId: v.id)),
    );
  }
}

/// Un viaggio passato, aggiunto a mano (tela, 65 e 98): bianco, tratteggiato,
/// con il timbro «importato». Toccandolo, lo si cambia o lo si toglie.
class PaginaPassata extends StatelessWidget {
  const PaginaPassata({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final v = viaggio;
    final sotto = sottotitoloViaggioPassato(v);
    return BigliettoBasso(
      codice: codiceViaggio(v),
      titolo: titoloViaggio(v),
      sottotitolo: sotto,
      tratteggiato: true,
      timbro: const TimbroScritto('IMPORTATO', colore: Colori.inchiostro),
      etichetta: '${titoloViaggio(v)}, $sotto, importato',
      onTap: () => gestiViaggioPassato(context, v),
    );
  }
}
