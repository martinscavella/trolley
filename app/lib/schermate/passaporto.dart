import 'dart:async';
import 'dart:math';

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

/// Il passaporto (10-chiusura-e-ricordo.md; tela, 65): tutti i viaggi chiusi,
/// verificati o no, per anno e dal più recente, come biglietti d'inchiostro.
/// Quelli verificati per chi guarda hanno il timbro. Un biglietto apre il
/// viaggio concluso. Si legge dalla copia, anche senza rete.
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
          final pagine = perAnno(viaggi, (pv) => pv.$2.inizio ?? pv.$2.creato);
          var n = 0;
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
                  TitoloPagina(
                    'Passaporto',
                    sottotitolo: viaggi.isEmpty
                        ? 'Qui finisce ogni viaggio chiuso, verificato o no. '
                              'Il primo arriva il giorno dopo la fine del '
                              'primo viaggio.'
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
