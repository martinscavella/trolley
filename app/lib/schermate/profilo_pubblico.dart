/// «Il tuo profilo pubblico» (5.1; tela, 68 e 105–107): prima cosa vedono gli
/// altri e cosa non vedono mai, poi il numero, poi «Accendi», che accetta le
/// condizioni d'uso. Acceso è «Così ti vedono» (5.3; tela, 75): l'anteprima,
/// cosa piace, quali viaggi ci stanno (109), l'interruttore per spegnerlo.
/// Sospeso, dice perché e a chi scrivere.
///
/// Dipende dalla rete: lo stato lo dice il server, e senza i controlli si
/// spengono con il motivo. Si misura accendere e spegnere (07,
/// `profilo_pubblico_attivato`, H7).
library;

import 'dart:async';

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
import '../dati/errori.dart';
import '../dati/pagine.dart';
import '../dati/destinazioni.dart';
import '../dominio/itinerario.dart';
import '../dominio/parte_pubblica.dart';
import '../dominio/profilo_pubblico.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'pagine_del_sito.dart';
import 'verifica_telefono.dart';
import 'viaggi_sul_profilo.dart';

class SchermataProfiloPubblico extends StatefulWidget {
  const SchermataProfiloPubblico({super.key});

  @override
  State<SchermataProfiloPubblico> createState() =>
      _SchermataProfiloPubblicoState();
}

class _SchermataProfiloPubblicoState extends State<SchermataProfiloPubblico> {
  /// Lo stato della parte pubblica, e il proprio profilo com'è per gli
  /// altri con le scelte dei viaggi (5.3). Se il profilo non si legge, la
  /// schermata resta quella della 5.1.
  Future<(StatoPartePubblica?, ProfiloPubblico?)>? _letto;

  /// I gusti come li si sta scegliendo: si scrivono a ogni tocco.
  List<Interesse>? _gusti;
  bool _inCorso = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _letto ??= _leggi();
  }

  Future<(StatoPartePubblica?, ProfiloPubblico?)> _leggi() =>
      (Servizi.of(context).partePubblica.stato(), _leggiIlMio()).wait;

  Future<ProfiloPubblico?> _leggiIlMio() async {
    try {
      final mio = await Servizi.of(context).partePubblica.ilMioProfilo();
      _gusti = mio?.gusti;
      return mio;
    } on Object {
      return null;
    }
  }

  void _ricarica() {
    final servizi = Servizi.of(context);
    setState(() {
      _letto = _leggi();
    });
    // Accendere, spegnere, il numero, i gusti cambiano la versione del
    // profilo sul server: la copia la riprende, o il prossimo cambio di
    // valuta sarebbe rifiutato come superato.
    unawaited(servizi.archivio.scaricaProfilo().then((_) {}, onError: (_) {}));
  }

  Future<void> _scegliGusto(Interesse gusto) async {
    final prima = _gusti ?? const <Interesse>[];
    final scelti = prima.contains(gusto)
        ? ({...prima}..remove(gusto))
        : {...prima, gusto};
    setState(
      () => _gusti = [
        for (final g in gusti)
          if (scelti.contains(g)) g,
      ],
    );
    final servizi = Servizi.of(context);
    try {
      final salvati = await servizi.partePubblica.scegliGusti(scelti);
      if (mounted) setState(() => _gusti = salvati);
      unawaited(
        servizi.archivio.scaricaProfilo().then((_) {}, onError: (_) {}),
      );
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      mostraMessaggio(context, e.messaggio, errore: true);
      setState(() => _gusti = prima);
    }
  }

  Future<void> _sceltaDeiViaggi() async {
    await apri<void>(context, const SchermataViaggiSulProfilo());
    if (!mounted) return;
    setState(() {
      _letto = _leggi();
    });
  }

  /// Un gesto sul server, poi lo stato com'è diventato.
  Future<void> _fai(Future<void> Function() gesto) async {
    setState(() => _inCorso = true);
    try {
      await gesto();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    }
    if (!mounted) return;
    setState(() => _inCorso = false);
    _ricarica();
  }

  Future<void> _verificaIlTelefono() async {
    final verificato = await apri<bool>(context, const SchermataIlTuoNumero());
    if (verificato == true && mounted) _ricarica();
  }

  Future<void> _accendi() => _fai(() async {
    final servizi = Servizi.of(context);
    await servizi.partePubblica.accendi(condizioni: versioneCondizioni);
    await servizi.misurazione.registra(Eventi.profiloPubblicoAttivato);
    unawaited(servizi.misurazione.invia());
  });

  Future<void> _spegni() => _fai(() async {
    final servizi = Servizi.of(context);
    await servizi.partePubblica.spegni();
    await servizi.misurazione.registra(Eventi.profiloPubblicoSpento);
    unawaited(servizi.misurazione.invia());
  });

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) =>
          FutureBuilder<(StatoPartePubblica?, ProfiloPubblico?)>(
            future: _letto,
            builder: (context, letto) {
              final padding = EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top,
                20,
                MediaQuery.paddingOf(context).bottom + 32,
              );
              if (letto.connectionState != ConnectionState.done) {
                return const Center(child: IndicatoreAttivita());
              }
              final stato = letto.data?.$1;
              if (letto.hasError || stato == null) {
                return ListView(
                  padding: padding,
                  children: [
                    const TitoloPagina('Il tuo profilo pubblico'),
                    _NonSiLegge(
                      errore: letto.error is ParallelWaitError
                          ? (letto.error! as ParallelWaitError).errors.$1
                          : letto.error,
                      onRiprova: _ricarica,
                    ).entra(context),
                  ],
                );
              }
              return ListView(
                padding: padding,
                children: _contenuto(context, stato, letto.data?.$2),
              );
            },
          ),
    ),
  );

  List<Widget> _contenuto(
    BuildContext context,
    StatoPartePubblica stato,
    ProfiloPubblico? mio,
  ) {
    final passo = passoDi(stato);
    if (passo == PassoProfiloPubblico.acceso && mio != null) {
      return _cosiTiVedono(context, stato, mio);
    }
    final sulProfilo = mio?.tuttiIViaggi.where((v) => v.sulProfilo).length;
    const spento =
        'Per farti trovare da altri viaggiatori, e trovarne. È spento: lo '
        'accendi tu, e lo spegni quando vuoi.';
    final telefono = stato.telefono;
    return [
      TitoloPagina(
        'Il tuo profilo pubblico',
        sottotitolo: switch (passo) {
          PassoProfiloPubblico.sospeso =>
            'Chi modera la parte pubblica l\'ha sospeso.',
          PassoProfiloPubblico.acceso =>
            'È acceso: altri viaggiatori ti possono trovare.',
          _ => spento,
        },
      ).entra(context),
      if (passo == PassoProfiloPubblico.sospeso)
        ..._sospeso(context, stato)
      else ...[
        if (passo == PassoProfiloPubblico.acceso) ...[
          ConLaRete(
            builder: (context, rete) => _Interruttore(
              acceso: true,
              sotto: rete
                  ? 'Spento, sparisci dalla parte pubblica'
                  : motivoSenzaRete,
              onCambia: rete && !_inCorso ? (_) => _spegni() : null,
            ),
          ).entra(context, ritardo: Ritmo.passo),
          const SizedBox(height: 12),
        ],
        ConLaRete(
          builder: (context, rete) => _CosaVedono(
            etichetta: 'Cosa vedono gli altri',
            si: true,
            righe: const [
              'I viaggi chiusi che scegli tu',
              'Il mappamondo e i traguardi',
              'Il nome e cosa ti piace',
            ],
            // Si sceglie prima di accendere (tela, 105 → 109).
            azione: sulProfilo == null
                ? null
                : ('$sulProfilo · Scegli', rete ? _sceltaDeiViaggi : null),
          ),
        ).entra(context, ritardo: Ritmo.passo),
        const SizedBox(height: 12),
        const _CosaVedono(
          etichetta: 'Cosa non vedono mai',
          si: false,
          righe: [
            'I viaggi in programma o in corso, in nessuna forma',
            'Documenti, spese, cose da portare',
            'Con chi hai viaggiato',
            'Il tuo numero di telefono',
          ],
        ).entra(context, ritardo: Ritmo.passo * 2),
        const SizedBox(height: 12),
        ...switch (passo) {
          PassoProfiloPubblico.acceso => [
            if (telefono != null)
              Text(
                'Telefono verificato · ${numeroNascosto(telefono)}',
                textAlign: TextAlign.center,
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            _Condizioni(testo: '**Condizioni d\'uso** accettate'),
          ],
          PassoProfiloPubblico.minorenne => [
            Avviso(
              icona: icona(
                ios: CupertinoIcons.person,
                android: Icons.person_outline,
              ),
              testo:
                  'La parte pubblica c\'è solo dai 18 anni. Il resto di '
                  'Trolley è tutto tuo.',
            ).entra(context, ritardo: Ritmo.passo * 3),
          ],
          PassoProfiloPubblico.chiusa => [
            Avviso(
              icona: icona(
                ios: CupertinoIcons.clock,
                android: Icons.schedule_rounded,
              ),
              testo:
                  'Per ora la parte pubblica non accoglie profili nuovi: '
                  'riprova tra qualche giorno.',
            ).entra(context, ritardo: Ritmo.passo * 3),
          ],
          PassoProfiloPubblico.serveIlTelefono => [
            Avviso(
              icona: icona(
                ios: CupertinoIcons.device_phone_portrait,
                android: Icons.smartphone_rounded,
              ),
              testo:
                  'Serve un numero di telefono verificato: un numero vale '
                  'per un account solo. Non compare sul profilo.',
            ).entra(context, ritardo: Ritmo.passo * 3),
            const SizedBox(height: 16),
            ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Verifica il telefono',
                icona: icona(
                  ios: CupertinoIcons.device_phone_portrait,
                  android: Icons.smartphone_rounded,
                ),
                motivo: rete ? null : motivoSenzaRete,
                onPressed: _verificaIlTelefono,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La parte pubblica c\'è solo dai 18 anni.',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
          PassoProfiloPubblico.daAccendere => [
            _TelefonoVerificato(numero: telefono!)
                .entra(context, ritardo: Ritmo.passo * 3),
            const SizedBox(height: 16),
            ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Accendi il profilo pubblico',
                icona: icona(
                  ios: CupertinoIcons.person_2,
                  android: Icons.group_outlined,
                ),
                inCorso: _inCorso,
                motivo: rete ? null : motivoSenzaRete,
                onPressed: _accendi,
              ),
            ),
            const SizedBox(height: 8),
            _Condizioni(
              testo:
                  'Accendendolo accetti le **condizioni d\'uso** della parte '
                  'pubblica: le regole per stare con gli altri viaggiatori.',
            ),
          ],
          _ => const <Widget>[],
        },
      ],
    ];
  }

  /// Acceso (tela, 75): l'anteprima, cosa ti piace, quali viaggi,
  /// l'interruttore.
  List<Widget> _cosiTiVedono(
    BuildContext context,
    StatoPartePubblica stato,
    ProfiloPubblico mio,
  ) {
    final telefono = stato.telefono;
    final scelti = _gusti ?? mio.gusti;
    final sulProfilo = mio.tuttiIViaggi.where((v) => v.sulProfilo).length;
    return [
      const TitoloPagina(
        'Così ti vedono',
        sottotitolo:
            'Il profilo pubblico è acceso. Gli altri vedono solo questo.',
      ).entra(context),
      _Anteprima(profilo: mio).entra(context, ritardo: Ritmo.passo),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          header: true,
          child: Text(
            'Cosa ti piace',
            style: Testi.titoloSezione.copyWith(color: Colori.inchiostro),
          ),
        ),
      ),
      const SizedBox(height: 12),
      ConLaRete(
        builder: (context, rete) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in gusti)
              Gettone(
                etichetta: g.nome,
                scelto: scelti.contains(g),
                onTap: rete ? () => _scegliGusto(g) : null,
              ),
          ],
        ),
      ).entra(context, ritardo: Ritmo.passo),
      const SizedBox(height: 18),
      ConLaRete(
        builder: (context, rete) => _RigaVai(
          titolo: 'Viaggi sul profilo',
          sotto: rete
              ? '$sulProfilo di ${mio.tuttiIViaggi.length} · scegli quali'
              : motivoSenzaRete,
          onTap: rete ? _sceltaDeiViaggi : null,
        ),
      ).entra(context, ritardo: Ritmo.passo * 2),
      const SizedBox(height: 10),
      ConLaRete(
        builder: (context, rete) => _Interruttore(
          acceso: true,
          sotto: rete
              ? 'Spento, sparisci dalla ricerca e non vedi gli altri'
              : motivoSenzaRete,
          onCambia: rete && !_inCorso ? (_) => _spegni() : null,
        ),
      ).entra(context, ritardo: Ritmo.passo * 2),
      const SizedBox(height: 14),
      if (telefono != null)
        Text(
          'Telefono verificato · ${numeroNascosto(telefono)}',
          textAlign: TextAlign.center,
          style: Testi.didascalia.copyWith(color: Colori.grafite),
        ),
      const _Condizioni(testo: '**Condizioni d\'uso** accettate'),
    ];
  }

  List<Widget> _sospeso(BuildContext context, StatoPartePubblica stato) {
    final contatto = Servizi.of(context).archivio.osservaContattoModerazione();
    return [
      _Sospeso(
        dal: stato.sospesoIl!,
        motivo: stato.motivoSospensione ?? '',
      ).entra(context, ritardo: Ritmo.passo),
      const SizedBox(height: 12),
      Avviso(
        icona: icona(ios: CupertinoIcons.bag, android: Icons.luggage_outlined),
        testo:
            'I tuoi viaggi, i documenti e le spese restano tuoi: la '
            'sospensione riguarda solo la parte pubblica.',
      ).entra(context, ritardo: Ritmo.passo * 2),
      const SizedBox(height: 12),
      StreamBuilder<String?>(
        stream: contatto,
        builder: (context, letto) => Avviso(
          icona: icona(
            ios: CupertinoIcons.checkmark_shield,
            android: Icons.verified_user_outlined,
          ),
          inizio: 'Pensi che sia un errore?',
          testo: letto.data == null
              ? 'Scrivi a chi modera: l\'indirizzo è nelle condizioni d\'uso.'
              : 'Scrivi a ${letto.data}, con la data della sospensione.',
        ),
      ).entra(context, ritardo: Ritmo.passo * 2),
      const SizedBox(height: 14),
      const _Condizioni(
        testo:
            'Le **condizioni d\'uso** dicono che cosa non si fa nella parte '
            'pubblica.',
      ),
    ];
  }
}

/// Lo stato non si è letto: senza rete, o il server non risponde.
class _NonSiLegge extends StatelessWidget {
  const _NonSiLegge({required this.errore, required this.onRiprova});

  final Object? errore;
  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Avviso(
        icona: icona(
          ios: CupertinoIcons.wifi_slash,
          android: Icons.wifi_off_rounded,
        ),
        errore: true,
        testo: errore is ErroreTrolley
            ? (errore as ErroreTrolley).messaggio
            : 'La parte pubblica si guarda con la connessione.',
      ),
      const SizedBox(height: 16),
      ConLaRete(
        builder: (context, rete) => PulsanteGrande(
          etichetta: 'Riprova',
          secondario: true,
          motivo: rete ? null : motivoSenzaRete,
          onPressed: onRiprova,
        ),
      ),
    ],
  );
}

/// «Cosa vedono gli altri», «Cosa non vedono mai» (tela, 68): righe con la
/// spunta verde o il divieto rosso.
class _CosaVedono extends StatelessWidget {
  const _CosaVedono({
    required this.etichetta,
    required this.si,
    required this.righe,
    this.azione,
  });

  final String etichetta;
  final bool si;
  final List<String> righe;

  /// A destra della prima riga, in cobalto: «9 · Scegli» (tela, 105).
  final (String, VoidCallback?)? azione;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            etichetta.toUpperCase(),
            style: Testi.sezione.copyWith(color: Colori.grafite),
          ),
        ),
        const SizedBox(height: 4),
        for (final (i, testo) in righe.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: i == 0
                ? null
                : const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEF0F4), width: 1.5),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  si
                      ? icona(
                          ios: CupertinoIcons.checkmark_alt,
                          android: Icons.check_rounded,
                        )
                      : icona(ios: CupertinoIcons.nosign, android: Icons.block),
                  size: 20,
                  color: si ? Colori.verde : Colori.pericolo,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    testo,
                    style: Testi.secondario.copyWith(
                      fontSize: 15,
                      color: Colori.inchiostro,
                    ),
                  ),
                ),
                if (azione case (final scritta, final onTap) when i == 0) ...[
                  const SizedBox(width: 8),
                  Premibile(
                    onTap: onTap,
                    etichetta: 'Scegli quali viaggi vanno sul profilo',
                    child: ExcludeSemantics(
                      child: Text(
                        scritta,
                        style: Testi.secondario.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: onTap == null ? Colori.piombo : Colori.cobalto,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

/// L'anteprima del proprio profilo pubblico (tela, 75): com'è per gli altri.
class _Anteprima extends StatelessWidget {
  const _Anteprima({required this.profilo});

  final ProfiloPubblico profilo;

  @override
  Widget build(BuildContext context) {
    final p = profilo;
    return Pannello(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(nome: p.nome, dimensione: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nome,
                      style: Testi.titoli(18)
                          .copyWith(color: Colori.inchiostro),
                    ),
                    Text(
                      [
                        quanti(p.viaggi.length, 'viaggio', 'viaggi'),
                        quanti(p.paesi.length, 'paese', 'paesi'),
                        quanti(p.traguardi, 'traguardo', 'traguardi'),
                      ].join(' · '),
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.paesi.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final paese in p.paesi)
                  Pillola((nomeDelPaese(paese) ?? paese).toUpperCase()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Una riga bianca che porta altrove, senza icona (tela, 75: «Viaggi sul
/// profilo»).
class _RigaVai extends StatelessWidget {
  const _RigaVai({
    required this.titolo,
    required this.sotto,
    required this.onTap,
  });

  final String titolo;
  final String sotto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    etichetta: '$titolo, $sotto',
    child: ExcludeSemantics(
      child: Pannello(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        raggio: 18,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    sotto,
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
            Icon(
              icona(
                ios: CupertinoIcons.chevron_forward,
                android: Icons.chevron_right,
              ),
              size: 18,
              color: onTap == null ? Colori.piombo : Colori.grafite,
            ),
          ],
        ),
      ),
    ),
  );
}

/// La riga con l'interruttore (tela, 106).
class _Interruttore extends StatelessWidget {
  const _Interruttore({
    required this.acceso,
    required this.sotto,
    required this.onCambia,
  });

  final bool acceso;
  final String sotto;
  final ValueChanged<bool>? onCambia;

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    raggio: 18,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profilo pubblico',
                style: Testi.evidenza.copyWith(color: Colori.inchiostro),
              ),
              Text(
                sotto,
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AdaptiveSwitch(value: acceso, onChanged: onCambia),
      ],
    ),
  );
}

/// Il numero è verificato (tela, 105).
class _TelefonoVerificato extends StatelessWidget {
  const _TelefonoVerificato({required this.numero});

  final String numero;

  @override
  Widget build(BuildContext context) => Pannello(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    raggio: 16,
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colori.menta,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icona(
              ios: CupertinoIcons.checkmark_alt,
              android: Icons.check_rounded,
            ),
            size: 20,
            color: Colori.verde,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Telefono verificato',
                style: Testi.evidenza.copyWith(
                  fontSize: 15,
                  color: Colori.inchiostro,
                ),
              ),
              Text(
                '${numeroNascosto(numero)} · non lo vede nessuno',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Sospeso, da quando e perché (tela, 107).
class _Sospeso extends StatelessWidget {
  const _Sospeso({required this.dal, required this.motivo});

  final DateTime dal;
  final String motivo;

  @override
  Widget build(BuildContext context) => Pannello(
    raggio: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colori.rosa,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icona(ios: CupertinoIcons.nosign, android: Icons.block),
                size: 22,
                color: Colori.pericolo,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'È sospeso',
                    style: Testi.titoli(20).copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    'Dal ${dataBreve(dal.toLocal())}. Gli altri non ti vedono '
                    'più.',
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1.5, thickness: 1.5, color: Color(0xFFEEF0F4)),
        const SizedBox(height: 12),
        Text('IL MOTIVO', style: Testi.sezione.copyWith(color: Colori.grafite)),
        const SizedBox(height: 6),
        Text(
          motivo,
          style: Testi.secondario.copyWith(
            fontSize: 15,
            color: Colori.inchiostro,
          ),
        ),
      ],
    ),
  );
}

/// La riga che porta alle condizioni d'uso, spenta senza rete.
class _Condizioni extends StatelessWidget {
  const _Condizioni({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ConLaRete(
      builder: (context, rete) => TestoConRimando(
        testo,
        allineamento: TextAlign.center,
        onTap: rete
            ? () => apriLaPagina(context, PaginaDelSito.condizioni)
            : null,
        motivo: motivoSenzaRete,
      ),
    ),
  );
}
