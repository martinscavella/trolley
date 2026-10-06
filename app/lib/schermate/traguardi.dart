import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/traguardi.dart';
import '../servizi.dart';

/// L'icona di un traguardo.
IconData iconaTraguardo(Traguardo t) => switch (t) {
  Traguardo.primoViaggioVerificato => icona(
    ios: CupertinoIcons.star,
    android: Icons.star_outline_rounded,
  ),
  Traguardo.inCompagnia => icona(
    ios: CupertinoIcons.person_2,
    android: Icons.group_outlined,
  ),
  Traguardo.weekendLungo => icona(
    ios: CupertinoIcons.sun_max,
    android: Icons.wb_sunny_outlined,
  ),
  Traguardo.unaSettimana => icona(
    ios: CupertinoIcons.clock,
    android: Icons.schedule_rounded,
  ),
  Traguardo.ogniGiornoUnaTappa => Icons.check_rounded,
  Traguardo.organizzare => icona(
    ios: CupertinoIcons.person_badge_plus,
    android: Icons.person_add_alt_1_outlined,
  ),
  Traguardo.trePaesi => icona(
    ios: CupertinoIcons.globe,
    android: Icons.public_rounded,
  ),
  Traguardo.dieciCitta => icona(
    ios: CupertinoIcons.location,
    android: Icons.place_outlined,
  ),
  Traguardo.quattroStagioni => icona(
    ios: CupertinoIcons.calendar,
    android: Icons.calendar_month_outlined,
  ),
};

/// Un traguardo come una medaglia (tela, 60 e 62): pieno di cobalto se
/// preso, tratteggiato se da prendere.
class Medaglia extends StatelessWidget {
  const Medaglia({
    super.key,
    required this.traguardo,
    required this.preso,
    this.sotto,
  });

  final Traguardo traguardo;
  final bool preso;

  /// Da dove viene, o quanto manca: «Porto, ott 2026», «1 di 3».
  final String? sotto;

  @override
  Widget build(BuildContext context) => Semantics(
    label: [traguardo.nome, preso ? 'preso' : 'da prendere', ?sotto].join(', '),
    child: ExcludeSemantics(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preso ? Colori.cobalto : null,
              border: preso
                  ? Border.all(
                      color: Colori.bianco.withValues(alpha: 0.5),
                      width: 2,
                      strokeAlign: -4,
                    )
                  : Border.all(color: Colori.piombo, width: 2.5),
            ),
            child: Icon(
              iconaTraguardo(traguardo),
              size: 28,
              color: preso ? Colori.bianco : Colori.piombo,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            traguardo.nome,
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(
              color: preso ? Colori.inchiostro : Colori.grafite,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (sotto != null)
            Text(
              sotto!,
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(
                color: Colori.grafite,
                fontSize: 12,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Le medaglie in una scheda bianca, tre per riga.
class GrigliaMedaglie extends StatelessWidget {
  const GrigliaMedaglie({super.key, required this.medaglie});

  final List<Medaglia> medaglie;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 18, 10, 18),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(20),
    ),
    child: LayoutBuilder(
      builder: (context, vincoli) {
        final larghezza = (vincoli.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 14,
          children: [
            for (final m in medaglie) SizedBox(width: larghezza, child: m),
          ],
        );
      },
    ),
  );
}

/// «Traguardi» (tela, 62): presi e da prendere, con quanto manca. Si
/// prendono solo con i viaggi verificati; non scadono e non dipendono dal
/// piano (10, regola 7). Si legge dalla copia, anche senza rete.
class SchermataTraguardi extends StatefulWidget {
  const SchermataTraguardi({super.key});

  @override
  State<SchermataTraguardi> createState() => _SchermataTraguardiState();
}

class _SchermataTraguardiState extends State<SchermataTraguardi> {
  late Stream<List<TraguardoPreso>> _presi;
  late Future<List<(Partecipazione, Viaggio)>> _miei;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _presi = archivio.osservaTraguardi();
    _miei = archivio.mieiViaggi();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TraguardoPreso>>(
      stream: _presi,
      builder: (context, presi) => FutureBuilder<List<(Partecipazione, Viaggio)>>(
        future: _miei,
        builder: (context, letti) {
          final miei = letti.data ?? const <(Partecipazione, Viaggio)>[];
          final viaggi = <String, Viaggio>{for (final (_, v) in miei) v.id: v};
          final verificati = <ViaggioVerificato>[
            for (final (p, v) in miei)
              if (p.verificato == true && v.inizio != null && v.fine != null)
                (
                  id: v.id,
                  inizio: soloData(v.inizio!),
                  fine: soloData(v.fine!),
                  paese: v.destinazionePaese,
                  citta: v.destinazioneCitta,
                  persone: 1,
                  responsabile: false,
                  fattePerGiorno: const <int>[],
                ),
          ];
          final presiPerTipo = <Traguardo, TraguardoPreso>{
            for (final t in presi.data ?? const <TraguardoPreso>[])
              ?Traguardo.leggi(t.tipo): t,
          };
          String? daDove(TraguardoPreso t) {
            final v = viaggi[t.viaggioId];
            final inizio = v?.inizio;
            if (v == null || inizio == null) return null;
            return '${titoloViaggio(v)}, ${meseBreve(inizio)} ${inizio.year}';
          }

          final daPrendere = [
            for (final t in Traguardo.values)
              if (!presiPerTipo.containsKey(t)) t,
          ];
          return Pagina(
            corpo: Builder(
              builder: (context) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top,
                  20,
                  MediaQuery.paddingOf(context).bottom + 32,
                ),
                children: [
                  const TitoloPagina(
                    'Traguardi',
                    sottotitolo:
                        'Si prendono solo con i viaggi verificati. Non scadono '
                        'e non dipendono dal piano.',
                  ).entra(context),
                  if (presiPerTipo.isNotEmpty) ...[
                    _Etichetta(
                      'Presi · ${presiPerTipo.length}',
                      colore: Colori.cobalto,
                    ),
                    GrigliaMedaglie(
                      medaglie: [
                        for (final MapEntry(key: t, value: preso)
                            in presiPerTipo.entries)
                          Medaglia(
                            traguardo: t,
                            preso: true,
                            sotto: daDove(preso),
                          ),
                      ],
                    ).entra(context, ritardo: Ritmo.passo),
                    const SizedBox(height: 8),
                  ],
                  if (daPrendere.isNotEmpty) ...[
                    _Etichetta('Da prendere', colore: Colori.grafite),
                    GrigliaMedaglie(
                      medaglie: [
                        for (final t in daPrendere)
                          Medaglia(
                            traguardo: t,
                            preso: false,
                            sotto: t.soglia == null
                                ? null
                                : '${contati(t, verificati)} di ${t.soglia}',
                          ),
                      ],
                    ).entra(context, ritardo: Ritmo.passo * 2),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo, {required this.colore});

  final String testo;
  final Color colore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
    child: Text(
      testo.toUpperCase(),
      style: Testi.sezione.copyWith(color: colore),
    ),
  );
}

/// La riga «Traguardi · 3 presi» del profilo (tela, 64).
class RigaTraguardi extends StatelessWidget {
  const RigaTraguardi({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TraguardoPreso>>(
    stream: Servizi.of(context).archivio.osservaTraguardi(),
    builder: (context, presi) {
      final n = presi.data?.length ?? 0;
      final quanti = n == 0
          ? 'nessuno'
          : n == 1
          ? '1 preso'
          : '$n presi';
      return Premibile(
        onTap: () => apri<void>(context, const SchermataTraguardi()),
        scala: 0.98,
        etichetta: 'Traguardi, $quanti',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colori.bianco,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colori.foschia,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    iconaTraguardo(Traguardo.primoViaggioVerificato),
                    size: 22,
                    color: Colori.inchiostro,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Traguardi',
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                ),
                Text(
                  quanti,
                  style: Testi.secondario.copyWith(color: Colori.grafite),
                ),
                const SizedBox(width: 6),
                Icon(
                  icona(
                    ios: CupertinoIcons.chevron_forward,
                    android: Icons.chevron_right_rounded,
                  ),
                  size: 16,
                  color: Colori.grafite,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
