/// «Salta» chiede cosa fare (04, regole 31–33; tela, 152–155): rimandare la
/// tappa più tardi oggi, domani o in un altro giorno, oppure saltarla e
/// basta. Una tappa già saltata si rimanda dallo stesso foglio, senza
/// «Saltala e basta».
///
/// Saltare e basta è il segno di sempre, anche senza rete. Rimandare è
/// spostare, e vuole la rete come ogni spostamento (04, regola 26): senza, le
/// tre scelte sono spente e dicono perché. I gesti senza rete restano quattro.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/orari.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_tappa.dart';

/// Quando si rimanda: dice l'evento (07, `tappa_rimandata`).
enum QuandoRimandare {
  oggi('oggi'),
  domani('domani'),
  altroGiorno('altro_giorno');

  const QuandoRimandare(this.codice);
  final String codice;
}

/// Quello che si è scelto nel foglio.
sealed class SceltaSalta {
  const SceltaSalta();
}

/// Saltarla e basta: il segno di sempre.
final class SaltalaEBasta extends SceltaSalta {
  const SaltalaEBasta();
}

/// Rimandarla a [giorno], alle [alle].
final class Rimandala extends SceltaSalta {
  const Rimandala(this.giorno, this.alle, this.quando);
  final Giorno giorno;
  final Duration alle;
  final QuandoRimandare quando;
}

/// Il pulsante «Salta»: apre il foglio, poi fa quello che si è scelto (tela,
/// 152). Da «Adesso», dalla giornata, dalla mappa e dalla navigazione.
/// [adesso] è l'orologio di chi chiama: «Adesso» ha il suo.
Future<void> saltaLaTappa(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
  DateTime? adesso,
}) async {
  await _chiedi(
    context,
    viaggio: viaggio,
    tappa: tappa,
    daSaltare: true,
    adesso: adesso ?? DateTime.now(),
  );
}

/// «Rimandala» su una tappa già saltata (tela, 155). Dice se l'ha spostata.
Future<bool> rimandaLaTappa(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
}) => _chiedi(
  context,
  viaggio: viaggio,
  tappa: tappa,
  daSaltare: false,
  adesso: DateTime.now(),
);

/// Apre il foglio e fa quello che si è scelto. Dice se la tappa è stata
/// rimandata.
Future<bool> _chiedi(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
  required bool daSaltare,
  required DateTime adesso,
}) async {
  final archivio = Servizi.of(context).archivio;
  final (giorni, tappe) = await (
    archivio.osservaGiorni(viaggio.id).first,
    archivio.osservaTappe(viaggio.id).first,
  ).wait;
  if (!context.mounted) return false;
  // La tappa com'è adesso nella copia, non com'era quando chi chiama l'ha
  // letta: dal foglio della tappa la si può aver appena segnata saltata, e
  // rimandandola va riportata da fare.
  tappa = tappe.where((t) => t.id == tappa.id).firstOrNull ?? tappa;
  final suo = giorni.where((g) => g.id == tappa.giornoId).firstOrNull;
  final dove = suo == null
      ? null
      : tappeDelGiorno(
          suo,
          tappe,
        ).where((c) => c.tappa.id == tappa.id).firstOrNull;
  final rimandi = doveRimandare<Giorno, Tappa>(
    giorni: [
      for (final g in giorni)
        (
          giorno: g,
          finestra: g.finestra,
          occupati: occupatiDel(g, tappe, tranne: tappa.id),
        ),
    ],
    adesso: adesso,
    durata: tappa.durata,
    daDove: suo == null || dove == null
        ? null
        : (data: suo.finestra.data, fine: dove.inizio + dove.durata),
  );
  final scelta = await apriFoglio<SceltaSalta>(
    context,
    FoglioSalta(
      tappa: tappa,
      rimandi: rimandi,
      daSaltare: daSaltare,
      oggi: soloData(adesso),
    ),
  );
  if (scelta == null || !context.mounted) return false;
  switch (scelta) {
    case SaltalaEBasta():
      await segnaLaTappa(
        context,
        viaggio: viaggio,
        tappa: tappa,
        stato: StatoTappa.saltata,
      );
      return false;
    case Rimandala(:final giorno, :final alle, :final quando):
      return _rimanda(
        context,
        viaggio: viaggio,
        tappa: tappa,
        giorno: giorno,
        alle: alle,
        quando: quando,
        daSaltare: daSaltare,
      );
  }
}

/// Sposta la tappa, con la sua versione, e se era segnata la riporta da
/// fare: lo stato non viaggia con la versione, va con il segno (02 §2).
/// Prima lo spostamento, così se non riesce la tappa resta com'era. Dice se
/// è riuscito.
Future<bool> _rimanda(
  BuildContext context, {
  required Viaggio viaggio,
  required Tappa tappa,
  required Giorno giorno,
  required Duration alle,
  required QuandoRimandare quando,
  required bool daSaltare,
}) async {
  final servizi = Servizi.of(context);
  final spostata = await spostaLaTappa(
    context,
    tappa,
    alle,
    giornoId: giorno.id,
  );
  if (!spostata || !context.mounted) return spostata;
  if (tappa.statoTappa != StatoTappa.daFare) {
    await segnaLaTappa(
      context,
      viaggio: viaggio,
      tappa: tappa,
      stato: StatoTappa.daFare,
    );
  }
  await servizi.misurazione.registra(Eventi.tappaRimandata, {
    'viaggio_id': viaggio.id,
    'quando': quando.codice,
    'da': daSaltare ? 'salta' : 'tappa',
    'durante_il_viaggio': segnataDuranteIlViaggio(
      viaggio.statoA(DateTime.now()),
    ),
  });
  unawaited(servizi.misurazione.invia());
  if (context.mounted) {
    mostraMessaggio(context, 'Rimandata ${_aQuando(quando, giorno, alle)}.');
  }
  return true;
}

String _aQuando(QuandoRimandare quando, Giorno giorno, Duration alle) =>
    switch (quando) {
      QuandoRimandare.oggi => 'a più tardi, alle ${ora(alle)}',
      QuandoRimandare.domani => 'a domani alle ${ora(alle)}',
      QuandoRimandare.altroGiorno =>
        'a ${giornoBreve(giorno.finestra.data).toLowerCase()} alle '
            '${ora(alle)}',
    };

/// Il foglio: le tre scelte per rimandare, e «Saltala e basta» (tela,
/// 152–154). Con «Un altro giorno» passa all'elenco dei giorni (153).
class FoglioSalta extends StatefulWidget {
  const FoglioSalta({
    super.key,
    required this.tappa,
    required this.rimandi,
    required this.oggi,
    this.daSaltare = true,
  });

  final Tappa tappa;

  /// Il giorno di adesso, per sapere qual è domani.
  final DateTime oggi;

  /// I giorni da oggi in poi, con l'ora a cui la tappa ci andrebbe.
  final List<Rimando<Giorno>> rimandi;

  /// Dal pulsante «Salta»: c'è anche «Saltala e basta». Da una tappa già
  /// saltata no (tela, 155).
  final bool daSaltare;

  @override
  State<FoglioSalta> createState() => _FoglioSaltaState();
}

class _FoglioSaltaState extends State<FoglioSalta> {
  bool _giorni = false;

  Rimando<Giorno>? get _oggi => widget.rimandi.where((r) => r.oggi).firstOrNull;

  /// Il giorno dopo oggi, se è del viaggio. Prima del viaggio non c'è un
  /// domani da proporre: c'è l'elenco dei giorni.
  Rimando<Giorno>? get _domani {
    final oggi = widget.oggi;
    final domani = DateTime.utc(oggi.year, oggi.month, oggi.day + 1);
    return widget.rimandi.where((r) => soloData(r.data) == domani).firstOrNull;
  }

  void _scegli(Rimando<Giorno> r, QuandoRimandare quando) =>
      Navigator.of(context).pop(Rimandala(r.giorno, r.ora!, quando));

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) => _giorni ? _elencoGiorni(rete) : _scelte(rete),
  );

  Widget _scelte(bool rete) {
    final t = widget.tappa;
    final oggi = _oggi;
    final domani = _domani;
    String sotto(Rimando<Giorno>? r, String quando) {
      if (!rete) return 'Serve la rete';
      if (r == null) return 'Non è un giorno del viaggio';
      if (!r.entra) return 'Non entra così com\'è';
      return quando;
    }

    return Foglio(
      titolo: widget.daSaltare
          ? 'Salta «${t.titolo}»?'
          : 'Rimanda «${t.titolo}»',
      inBasso: widget.daSaltare
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PulsanteGrande(
                  etichetta: 'Saltala e basta',
                  secondario: true,
                  onPressed: () =>
                      Navigator.of(context).pop(const SaltalaEBasta()),
                ),
                const SizedBox(height: 10),
                const PulsanteAnnulla(),
              ],
            )
          : const PulsanteAnnulla(),
      children: [
        Text(
          widget.daSaltare
              ? 'Rimandala, e torna da fare al suo nuovo posto. Oppure saltala '
                    'e basta: conta come segnata.'
              : 'Torna da fare al suo nuovo posto, e per la verifica va '
                    'segnata di nuovo.',
          style: Testi.corpo.copyWith(color: Colori.ardesia),
        ),
        if (!rete) ...[
          const SizedBox(height: 14),
          Avviso(
            fondo: Colori.foschia,
            icona: icona(
              ios: CupertinoIcons.wifi_slash,
              android: Icons.wifi_off_rounded,
            ),
            inizio: 'Senza rete non si sposta.',
            testo: widget.daSaltare
                ? 'Saltala adesso: la rimandi dalla tappa quando torna la rete.'
                : 'Torna qui quando c\'è la rete.',
          ),
        ],
        const EtichettaSezione('Rimandala'),
        RigaScheda(
          suFoglio: true,
          simbolo: icona(ios: CupertinoIcons.clock, android: Icons.schedule),
          titolo: 'Più tardi oggi',
          sottotitolo: sotto(
            oggi,
            'Alle ${ora(oggi?.ora ?? Duration.zero)} · lì è libero',
          ),
          onTap: rete && oggi != null && oggi.entra
              ? () => _scegli(oggi, QuandoRimandare.oggi)
              : null,
        ),
        const SizedBox(height: 8),
        RigaScheda(
          suFoglio: true,
          simbolo: icona(
            ios: CupertinoIcons.calendar,
            android: Icons.calendar_today_rounded,
          ),
          titolo: 'Domani',
          sottotitolo: sotto(
            domani,
            domani == null
                ? ''
                : '${giornoBreve(domani.data)} alle '
                      '${ora(domani.ora ?? Duration.zero)}',
          ),
          onTap: rete && domani != null && domani.entra
              ? () => _scegli(domani, QuandoRimandare.domani)
              : null,
        ),
        const SizedBox(height: 8),
        RigaScheda(
          suFoglio: true,
          simbolo: icona(
            ios: CupertinoIcons.calendar,
            android: Icons.calendar_month_rounded,
          ),
          titolo: 'Un altro giorno',
          sottotitolo: !rete
              ? 'Serve la rete'
              : widget.rimandi.any((r) => r.entra)
              ? 'Scegli quando'
              : 'Non entra in nessun giorno',
          onTap: rete && widget.rimandi.any((r) => r.entra)
              ? () => setState(() => _giorni = true)
              : null,
        ),
      ],
    );
  }

  /// I giorni da oggi in poi, all'orario proposto (tela, 153). Uno dove non
  /// entra resta, spento, e dice perché.
  Widget _elencoGiorni(bool rete) => Foglio(
    titolo: 'Quando la rimandi?',
    indietro: () => setState(() => _giorni = false),
    inBasso: const PulsanteAnnulla(),
    children: [
      Text(
        '${widget.tappa.titolo} · ${durataBreve(widget.tappa.durata)}. Va '
        'all\'orario proposto di quel giorno: lo cambi dopo, dalla tappa.',
        style: Testi.corpo.copyWith(color: Colori.ardesia),
      ),
      const SizedBox(height: 14),
      for (final r in widget.rimandi) ...[
        RigaScheda(
          suFoglio: true,
          simbolo: icona(
            ios: CupertinoIcons.calendar,
            android: Icons.calendar_today_rounded,
          ),
          titolo: r.oggi
              ? '${giornoBreve(r.data)} · oggi'
              : giornoBreve(r.data),
          sottotitolo: !rete
              ? 'Serve la rete'
              : r.entra
              ? 'Alle ${ora(r.ora!)}'
              : 'Non entra così com\'è',
          onTap: rete && r.entra
              ? () => _scegli(
                  r,
                  r.oggi ? QuandoRimandare.oggi : QuandoRimandare.altroGiorno,
                )
              : null,
        ),
        const SizedBox(height: 8),
      ],
      Text(
        'I giorni passati non ci sono: si rimanda solo in avanti.',
        style: Testi.didascalia.copyWith(color: Colori.grafite),
      ),
    ],
  );
}
