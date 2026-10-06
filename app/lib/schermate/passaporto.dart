import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/timbro.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/ricordo.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'viaggio.dart';
import 'viaggio_passato.dart';

/// Il passaporto (10-chiusura-e-ricordo.md; tela, 65): tutti i viaggi chiusi,
/// verificati o no, per anno e dal più recente, come biglietti d'inchiostro.
/// Quelli verificati per chi guarda hanno il timbro. Un biglietto apre il
/// viaggio concluso. In fondo, «Prima di Trolley», i viaggi passati aggiunti
/// a mano: bianchi, tratteggiati, con il timbro «importato» (regola 6), e il
/// «+» in alto per aggiungerne. Si legge dalla copia, anche senza rete.
class SchermataPassaporto extends StatefulWidget {
  const SchermataPassaporto({super.key});

  @override
  State<SchermataPassaporto> createState() => _SchermataPassaportoState();
}

class _SchermataPassaportoState extends State<SchermataPassaporto> {
  late Stream<List<(Partecipazione, Viaggio)>> _miei;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _miei = Servizi.of(context).archivio.osservaMieiViaggi();
    unawaited(segnaAperturaSenzaRete(context, 'passaporto'));
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<(Partecipazione, Viaggio)>>(
        stream: _miei,
        builder: (context, letti) {
          final viaggi = delPassaporto(letti.data ?? const [], DateTime.now());
          final pagine = perAnno([
            for (final pv in viaggi)
              if (!pv.$2.importato) pv,
          ], (pv) => pv.$2.inizio ?? pv.$2.creato);
          final passati = [
            for (final (_, v) in viaggi)
              if (v.importato) v,
          ];
          var n = 0;
          return Pagina(
            azioni: [
              PulsanteTondo(
                icona: icona(ios: CupertinoIcons.add, android: Icons.add),
                etichetta: 'Aggiungi un viaggio passato',
                onPressed: () =>
                    apriFoglio<void>(context, const FoglioViaggioPassato()),
              ),
            ],
            corpo: Builder(
              builder: (context) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top,
                  20,
                  MediaQuery.paddingOf(context).bottom + 32,
                ),
                children: [
                  TitoloPagina(
                    'Passaporto',
                    sottotitolo: viaggi.isEmpty
                        ? 'Qui finisce ogni viaggio chiuso, verificato o no. '
                              'Quelli fatti prima di Trolley li aggiungi tu, '
                              'con il +.'
                        : '${quanti(viaggi.length, 'viaggio', 'viaggi')}, '
                              'dal più recente. Ogni viaggio chiuso finisce '
                              'qui, verificato o no.',
                  ).entra(context),
                  for (final (anno, delAnno) in pagine) ...[
                    EtichettaSezione('$anno'),
                    for (final (p, v) in delAnno)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Pagina(
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
                        child: _Passato(viaggio: v),
                      ).entra(context, ritardo: Ritmo.passo * min(++n, 8)),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

/// Un viaggio del passaporto: il biglietto d'inchiostro, con quando e quanti
/// giorni, e il timbro se è verificato.
class _Pagina extends StatelessWidget {
  const _Pagina({required this.viaggio, required this.verificato});

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
class _Passato extends StatelessWidget {
  const _Passato({required this.viaggio});

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
