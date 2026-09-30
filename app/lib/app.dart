import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dati/database.dart';
import 'dati/errori.dart';
import 'misurazione/misurazione.dart';
import 'schermate/accesso.dart';
import 'schermate/nuovo_profilo.dart';
import 'schermate/viaggi.dart';
import 'schermate/viaggio.dart';
import 'servizi.dart';
import 'tema.dart';

enum _Fase { caricamento, accesso, profilo, pronto, errore }

/// Da dove è arrivato un codice d'invito. Finisce negli eventi: serve a sapere
/// quanto lavora il link e quanto il codice digitato.
enum ViaInvito { link, codice }

class TrolleyApp extends StatefulWidget {
  const TrolleyApp({super.key});

  @override
  State<TrolleyApp> createState() => _TrolleyAppState();
}

class _TrolleyAppState extends State<TrolleyApp> {
  final _navigatore = GlobalKey<NavigatorState>();
  final _messaggi = GlobalKey<ScaffoldMessengerState>();

  late Servizi _servizi;
  StreamSubscription<AuthState>? _accesso;
  StreamSubscription<String>? _codici;
  bool _avviato = false;

  _Fase _fase = _Fase.caricamento;

  /// Un invito arrivato prima che la persona potesse entrare: si tiene finché
  /// non ha un accesso e un profilo, poi si apre da solo.
  (String, ViaInvito)? _invitoInAttesa;
  bool _invitoInCorso = false;

  static const _chiaveIngressoCompletato = 'primo_ingresso_completato';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _servizi = Servizi.of(context);
    if (_avviato) return;
    _avviato = true;
    _accesso = _servizi.supabase.auth.onAuthStateChange.listen(
      (_) => _valutaFase(),
    );
    _codici = _servizi.ingresso.codici.listen(
      (codice) => _riceviInvito(codice, ViaInvito.link),
    );
  }

  @override
  void dispose() {
    _accesso?.cancel();
    _codici?.cancel();
    super.dispose();
  }

  Future<void> _valutaFase() async {
    if (_servizi.supabase.auth.currentSession == null) {
      _cambiaFase(_Fase.accesso);
      return;
    }
    var profilo = await _servizi.archivio.profiloLocale();
    if (profilo == null) {
      try {
        profilo = await _servizi.archivio.scaricaProfilo();
      } on ErroreTrolley {
        _cambiaFase(_Fase.errore);
        return;
      }
    }
    if (profilo == null) {
      _cambiaFase(_Fase.profilo);
      return;
    }
    await _entra();
  }

  Future<void> _entra() async {
    _cambiaFase(_Fase.pronto);
    await _servizi.db
        .into(_servizi.db.impostazioni)
        .insertOnConflictUpdate(
          ImpostazioniCompanion.insert(
            chiave: _chiaveIngressoCompletato,
            valore: DateTime.now().toUtc().toIso8601String(),
          ),
        );
    unawaited(_servizi.misurazione.invia());
    if (_invitoInAttesa != null) {
      await _apriInvito();
    } else {
      unawaited(_servizi.archivio.aggiornaCopia().catchError((_) {}));
    }
  }

  void _cambiaFase(_Fase fase) {
    if (!mounted || _fase == fase) return;
    setState(() => _fase = fase);
    if (fase != _Fase.pronto) {
      _navigatore.currentState?.popUntil((r) => r.isFirst);
    }
  }

  Future<void> _riceviInvito(String codice, ViaInvito via) async {
    if (_invitoInCorso && _invitoInAttesa?.$1 == codice) return;

    // Un codice che arriva prima che la persona sia mai entrata dall'app su questo
    // telefono è un'installazione portata da un invito (ADR-004).
    final ingressoCompletato =
        await (_servizi.db.select(_servizi.db.impostazioni)
              ..where((i) => i.chiave.equals(_chiaveIngressoCompletato)))
            .getSingleOrNull();
    if (ingressoCompletato == null) {
      await _servizi.misurazione.registra(Eventi.installazioneDaInvito, {
        'via': via.name,
      });
    }

    _invitoInAttesa = (codice, via);
    if (_fase == _Fase.pronto) {
      await _apriInvito();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _apriInvito() async {
    final invito = _invitoInAttesa;
    if (invito == null || _invitoInCorso) return;
    final (codice, via) = invito;
    _invitoInCorso = true;
    try {
      final viaggioId = await _servizi.archivio.accettaInvito(codice);
      _invitoInAttesa = null;
      await _servizi.misurazione.registra(Eventi.viaggioCorrettoAperto, {
        'via': via.name,
      });
      unawaited(_servizi.misurazione.invia());
      _navigatore.currentState?.popUntil((r) => r.isFirst);
      await _navigatore.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => SchermataViaggio(viaggioId: viaggioId),
        ),
      );
    } on ErroreTrolley catch (e) {
      // Senza rete l'invito resta in attesa e si riprova al prossimo ingresso;
      // un codice sbagliato invece si scarta, e la persona lo sa.
      if (!e.serveLaRete) _invitoInAttesa = null;
      _messaggi.currentState?.showSnackBar(
        SnackBar(content: Text(e.messaggio)),
      );
    } finally {
      _invitoInCorso = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitoInAttesa = _invitoInAttesa != null;
    return MaterialApp(
      title: 'Trolley',
      navigatorKey: _navigatore,
      scaffoldMessengerKey: _messaggi,
      theme: temaChiaro,
      darkTheme: temaScuro,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: switch (_fase) {
        _Fase.caricamento => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        _Fase.accesso => SchermataAccesso(invitoInAttesa: invitoInAttesa),
        _Fase.profilo => SchermataNuovoProfilo(
          invitoInAttesa: invitoInAttesa,
          onCreato: _entra,
        ),
        _Fase.pronto => SchermataViaggi(
          onCodice: (codice) => _riceviInvito(codice, ViaInvito.codice),
        ),
        _Fase.errore => _SchermataSenzaRete(onRiprova: _valutaFase),
      },
    );
  }
}

/// Primo ingresso su questo telefono, e manca la rete per sapere chi sei.
class _SchermataSenzaRete extends StatelessWidget {
  const _SchermataSenzaRete({required this.onRiprova});

  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Serve la connessione',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'È la prima volta che entri da questo telefono: per scaricare i '
              'tuoi viaggi serve la rete. Dopo, li potrai leggere anche offline.',
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRiprova, child: const Text('Riprova')),
          ],
        ),
      ),
    ),
  );
}
