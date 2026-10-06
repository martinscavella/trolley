import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/timbro.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/chiusura.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../dominio/traguardi.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'mappamondo.dart';
import 'passaporto.dart';
import 'spese.dart';
import 'traguardi.dart';

/// Quello che il riepilogo mostra, letto una volta dalla copia.
class _Dati {
  const _Dati({
    required this.viaggio,
    required this.giorni,
    required this.tappe,
    required this.fatte,
    required this.persone,
    required this.verificato,
    required this.presi,
    required this.novita,
  });

  final Viaggio viaggio;
  final int giorni;
  final int tappe;
  final int fatte;
  final int persone;
  final bool verificato;

  /// I traguardi presi con questo viaggio.
  final List<Traguardo> presi;
  final Novita novita;
}

/// Il riepilogo di chiusura (10, regola 2; tela, 60 e 61): giorni, tappe
/// fatte, chi c'era, quanto si è speso e la propria parte, che cosa c'è di
/// nuovo, i saldi ancora aperti. Verificato: il timbro e i traguardi presi.
/// Non verificato: lo stesso riepilogo, senza timbro né traguardi, senza
/// rimproveri e senza dire che cosa sarebbe servito (10, casi limite).
/// Si legge dalla copia, anche senza rete.
class SchermataRiepilogo extends StatefulWidget {
  const SchermataRiepilogo({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataRiepilogo> createState() => _SchermataRiepilogoState();
}

class _SchermataRiepilogoState extends State<SchermataRiepilogo> {
  late Future<_Dati?> _dati;
  bool _avviata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _dati = _leggi();
  }

  Future<_Dati?> _leggi() async {
    final archivio = Servizi.of(context).archivio;
    final viaggio = await archivio.leggiViaggio(widget.viaggioId);
    if (viaggio == null) return null;
    final giorni = await archivio.leggiGiorni(widget.viaggioId);
    final ids = {for (final g in giorni) g.id};
    final tappe = [
      for (final t in await archivio.leggiTappe(widget.viaggioId))
        if (ids.contains(t.giornoId)) t,
    ];
    final presenti = await archivio.leggiPresenti(widget.viaggioId);
    final mia = await archivio.miaPartecipazione(widget.viaggioId);
    final presi = [
      for (final t in await archivio.leggiTraguardi())
        if (t.viaggioId == widget.viaggioId) ?Traguardo.leggi(t.tipo),
    ];
    final oggi = DateTime.now();
    // Anche i viaggi passati: chi ricorda di essere stato in Portogallo nel
    // 2019 non ci arriva per la prima volta.
    MetaChiusa? meta(Viaggio v) {
      final inizio = v.inizioRicordo;
      if (inizio == null) return null;
      return (
        id: v.id,
        inizio: inizio,
        paese: v.destinazionePaese,
        citta: v.destinazioneCitta,
      );
    }

    final questo = meta(viaggio);
    final chiusi = [
      for (final (_, v) in await archivio.mieiViaggi())
        if (v.statoA(oggi) == StatoViaggio.chiuso && v.eliminatoIl == null)
          ?meta(v),
    ];
    return _Dati(
      viaggio: viaggio,
      giorni: giorni.length,
      tappe: tappe.length,
      fatte: tappe.where((t) => t.statoTappa == StatoTappa.completata).length,
      persone: presenti.length,
      verificato: mia?.verificato ?? false,
      presi: [
        for (final t in Traguardo.values)
          if (presi.contains(t)) t,
      ],
      novita: questo == null
          ? const Novita(paeseNuovo: false, cittaNuova: false, volte: 1)
          : novitaDelViaggio(questo, chiusi),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Dati?>(
    future: _dati,
    builder: (context, letti) {
      final d = letti.data;
      if (d == null) {
        return Pagina(
          corpo: Center(
            child: letti.connectionState == ConnectionState.done
                ? Text(
                    'Questo viaggio non è sul telefono.',
                    style: Testi.corpo.copyWith(color: Colori.grafite),
                  )
                : const IndicatoreAttivita(),
          ),
        );
      }
      final v = d.viaggio;
      final (inizio, fine) = (v.inizio, v.fine);
      final destinazione = v.destinazione;
      final dove = destinazione == null
          ? titoloViaggio(v)
          : [
              destinazione.nome,
              if (destinazione.citta != null) ?destinazione.nomePaese,
            ].join(', ');
      return Pagina(
        corpo: Builder(
          builder: (context) => ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 4,
              20,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Biglietto(
                    codice: codiceViaggio(v),
                    nome: dove,
                    nomeComeTitolo: true,
                    grandezzaCodice: 56,
                    sinistra: descrizioneStato(StatoViaggio.chiuso)
                        .toUpperCase(),
                    destra: inizio == null || fine == null
                        ? null
                        : '${intervalloBreve(inizio, fine)} ${fine.year}'
                              .toUpperCase(),
                    colore: Colori.inchiostro,
                    campi: [
                      CampoMatrice('Giorni', '${d.giorni}'),
                      CampoMatrice('Tappe fatte', '${d.fatte} di ${d.tappe}'),
                      CampoMatrice('Persone', '${d.persone}'),
                    ],
                  ),
                  if (d.verificato)
                    const Positioned(
                      right: 18,
                      top: 38,
                      child: TimbroScritto('VERIFICATO', grande: true),
                    ),
                ],
              ).entra(context),
              const SizedBox(height: 12),
              ConConto(
                viaggioId: v.id,
                builder: (context, conto) =>
                    _Conti(viaggio: v, conto: conto, novita: d.novita),
              ).entra(context, ritardo: Ritmo.passo),
              RigaDaGrattare(
                paese: d.novita.paeseNuovo ? v.destinazionePaese : null,
              ).entra(context, ritardo: Ritmo.passo),
              if (d.verificato && d.presi.isNotEmpty) ...[
                const SizedBox(height: 22),
                const TitoloSezione('Traguardi presi'),
                GrigliaMedaglie(
                  medaglie: [
                    for (final t in d.presi)
                      Medaglia(traguardo: t, preso: true),
                  ],
                ).entra(context, ritardo: Ritmo.passo * 2),
              ],
              if (!d.verificato) ...[
                const SizedBox(height: 12),
                Avviso(
                  icona: icona(
                    ios: CupertinoIcons.globe,
                    android: Icons.public_rounded,
                  ),
                  inizio: '${titoloViaggio(v)} è nel tuo passaporto,',
                  testo: 'e sul mappamondo.',
                ).entra(context, ritardo: Ritmo.passo * 2),
              ],
              const SizedBox(height: 18),
              PulsanteGrande(
                etichetta: 'Guarda il passaporto',
                icona: icona(
                  ios: CupertinoIcons.tickets,
                  android: Icons.confirmation_number_outlined,
                ),
                onPressed: () =>
                    apri<void>(context, const SchermataPassaporto()),
              ).entra(context, ritardo: Ritmo.passo * 3),
            ],
          ),
        ),
      );
    },
  );
}

/// «Speso in tutto» e «Di nuovo» (tela, 60), e sotto i saldi se restano
/// aperti.
class _Conti extends StatelessWidget {
  const _Conti({
    required this.viaggio,
    required this.conto,
    required this.novita,
  });

  final Viaggio viaggio;
  final ContoViaggio? conto;
  final Novita novita;

  @override
  Widget build(BuildContext context) {
    final c = conto;
    final destinazione = viaggio.destinazione;
    final paese = destinazione?.nomePaese;
    final citta = destinazione?.citta;
    final (etichetta, valore, sotto) = novita.paeseNuovo && paese != null
        ? (
            'Di nuovo',
            paese,
            novita.cittaNuova && citta != null ? 'e la città di $citta' : null,
          )
        : novita.cittaNuova && citta != null
        ? ('Di nuovo', citta, paese)
        : (
            'Ancora una volta',
            citta ?? paese ?? titoloViaggio(viaggio),
            novita.volte > 1 ? 'per la ${novita.volte}ª volta' : null,
          );
    final io = c?.io;
    final mio = c == null || io == null ? 0 : c.saldi.di(io);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Cifra(
                  etichetta: 'Speso in tutto',
                  valore: c == null
                      ? '…'
                      : scriviImporto(c.totale().centesimi, c.mia),
                  sotto: c == null || !c.diviso
                      ? null
                      : 'la tua parte '
                            '${scriviImporto(c.laMiaParte.centesimi, c.mia)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Cifra(
                  etichetta: etichetta,
                  valore: valore,
                  sotto: sotto,
                ),
              ),
            ],
          ),
        ),
        if (c != null && c.diviso && (mio != 0 || c.passaggi.isNotEmpty)) ...[
          const SizedBox(height: 10),
          RigaSaldi(
            conto: c,
            viaggio: viaggio,
            sotto: 'I saldi restano aperti finché non li chiudete',
          ),
        ],
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etichetta, required this.valore, this.sotto});

  final String etichetta;
  final String valore;
  final String? sotto;

  @override
  Widget build(BuildContext context) => Container(
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
          valore,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Testi.titoli(
            20,
            altezza: 1.2,
          ).copyWith(color: Colori.inchiostro),
        ),
        if (sotto != null)
          Text(sotto!, style: Testi.didascalia.copyWith(color: Colori.grafite)),
      ],
    ),
  );
}
