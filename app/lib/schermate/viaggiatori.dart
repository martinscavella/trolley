/// I pezzi della parte pubblica che tornano in più schermate (5.3; tela,
/// 73–75 e 109): un viaggio com'è sul profilo, una riga per un viaggiatore
/// trovato, i tre numeri del profilo, «cosa avete in comune».
library;

import 'package:flutter/material.dart';

import '../aspetto/biglietto.dart';
import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/timbro.dart';
import '../dati/destinazioni.dart';
import '../dominio/calendario.dart';
import '../dominio/profilo_pubblico.dart';

/// Il nome della meta: la città, o il paese di un viaggio in un paese intero.
String metaPubblica(ViaggioPubblico v) =>
    v.citta ?? nomeDelPaese(v.paese) ?? 'Senza meta';

/// Sotto la meta: `aprile 2026 · 9 giorni`; per un importato il periodo com'è
/// stato scritto, e i giorni se li si ricorda.
String quandoPubblico(ViaggioPubblico v) {
  final mese = v.mese;
  final quando = mese != null
      ? '${nomiDeiMesi[mese.month - 1]} ${mese.year}'
      : v.periodo ?? 'quando non si sa';
  final giorni = v.giorni;
  return giorni == null
      ? quando
      : '$quando · ${quanti(giorni, 'giorno', 'giorni')}';
}

/// «Su Trolley da marzo», o «da marzo 2025» se non è quest'anno.
String suTrolleyDa(DateTime dal, DateTime oggi) {
  final mese = nomiDeiMesi[dal.month - 1];
  return dal.year == oggi.year
      ? 'su Trolley da $mese'
      : 'su Trolley da $mese ${dal.year}';
}

/// «Portogallo e Giappone · Cibo, Arte e musei».
String? inComuneInParole(InComune c) {
  final parti = [
    if (c.paesi.isNotEmpty)
      insieme([for (final p in c.paesi) nomeDelPaese(p) ?? p]),
    if (c.gusti.isNotEmpty) [for (final g in c.gusti) g.nome].join(', '),
  ];
  return parti.isEmpty ? null : parti.join(' · ');
}

/// Un viaggio sul profilo (tela, 73): il biglietto d'inchiostro, con il
/// timbro se è verificato; un importato bianco e tratteggiato, come nel
/// passaporto.
class BigliettoPubblico extends StatelessWidget {
  const BigliettoPubblico({super.key, required this.viaggio});

  final ViaggioPubblico viaggio;

  @override
  Widget build(BuildContext context) {
    final v = viaggio;
    final meta = metaPubblica(v);
    final quando = quandoPubblico(v);
    return BigliettoBasso(
      codice: codiceDestinazione(meta),
      titolo: meta,
      sottotitolo: quando,
      colore: Colori.inchiostro,
      tratteggiato: v.importato,
      timbro: v.importato
          ? const TimbroScritto('IMPORTATO', colore: Colori.inchiostro)
          : v.verificato
          ? const TimbroScritto('VERIFICATO')
          : null,
      etichetta: [
        meta,
        quando,
        if (v.importato) 'importato',
        if (v.verificato) 'verificato',
      ].join(', '),
      onTap: null,
    );
  }
}

/// Viaggi, paesi, traguardi: i tre numeri in cima al profilo (tela, 73).
class NumeriDelProfilo extends StatelessWidget {
  const NumeriDelProfilo({super.key, required this.profilo});

  final ProfiloPubblico profilo;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, (etichetta, n)) in [
        ('Viaggi', profilo.viaggi.length),
        ('Paesi', profilo.paesi.length),
        ('Traguardi', profilo.traguardi),
      ].indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            label: '$n ${etichetta.toLowerCase()}',
            excludeSemantics: true,
            child: Pannello(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              raggio: 16,
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
        ),
      ],
    ],
  );
}

/// Un viaggiatore trovato (tela, 74): l'iniziale, il nome, una riga che dice
/// perché è lì, e quante cose avete in comune.
class RigaViaggiatore extends StatelessWidget {
  const RigaViaggiatore({
    super.key,
    required this.nome,
    required this.sotto,
    required this.inComune,
    required this.onTap,
  });

  final String nome;
  final String sotto;
  final int inComune;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    etichetta: [
      nome,
      sotto,
      if (inComune > 0) '$inComune in comune',
    ].join(', '),
    child: ExcludeSemantics(
      child: Pannello(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        raggio: 18,
        child: Row(
          children: [
            Avatar(nome: nome),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    sotto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
            if (inComune > 0) ...[
              const SizedBox(width: 10),
              Pillola('$inComune IN COMUNE'),
            ],
          ],
        ),
      ),
    ),
  );
}
