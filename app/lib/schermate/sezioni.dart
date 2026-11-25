/// Le sezioni dell'app e la barra che resta (ADR-013; tela, 122–126):
/// Viaggi, Mappa, il «+», Passaporto, e Community quando c'è. Ogni sezione
/// ha la sua pila di pagine; la barra sta fuori dalle pile, e cambiando
/// sezione la voce bianca scivola da una voce all'altra mentre il contenuto
/// si dissolve. Ogni sezione ricorda dov'era.
///
/// Community compare solo se l'ultima volta che il server l'ha detto la
/// parte pubblica c'era per questa persona — aperta, o chiusa ai nuovi; per
/// il team sempre — ed è maggiorenne (11, regola 1; 01, regola 2). Il
/// telefono lo ricorda (Archivio.osservaCommunity): la barra non aspetta la
/// rete per sapere che voci ha.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/barra.dart';
import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/archivio.dart';
import '../dati/lettura.dart';
import '../dominio/mappa.dart';
import '../servizi.dart';
import 'community.dart';
import 'mappa.dart';
import 'nuovo_viaggio.dart';
import 'passaporto.dart';
import 'viaggi.dart';

enum Sezione { viaggi, mappa, passaporto, community }

/// Il viaggio su cui aprire la mappa, e la volta che lo si è chiesto: la
/// stessa richiesta fatta due volte riporta la mappa su quel viaggio anche
/// se nel frattempo se ne era scelto un altro.
typedef RichiestaMappa = ({String viaggio, int volta});

class SchermataSezioni extends StatefulWidget {
  const SchermataSezioni({super.key, required this.onCodice});

  /// Un codice d'invito digitato a mano, dalla sezione Viaggi.
  final ValueChanged<String> onCodice;

  /// Le sezioni aperte. Ce n'è una sola, e le pagine del navigatore
  /// principale, che non ci stanno dentro, la trovano da qui. Nelle prove di
  /// una schermata sola non c'è.
  static StatoSezioni? get aperta => StatoSezioni._aperta;

  @override
  State<SchermataSezioni> createState() => StatoSezioni();
}

class StatoSezioni extends State<SchermataSezioni> {
  static StatoSezioni? _aperta;

  Sezione _attiva = Sezione.viaggi;

  /// Le sezioni già aperte: le altre non si costruiscono finché non le si
  /// guarda (la mappa non chiede riquadri, Community non chiama il server).
  final _costruite = <Sezione>{Sezione.viaggi};

  final _pile = {
    for (final s in Sezione.values) s: GlobalKey<NavigatorState>(),
  };
  final _cime = {for (final s in Sezione.values) s: _Cima()};
  final _ritocchi = {for (final s in Sezione.values) s: _Segnale()};
  final _mappa = ValueNotifier<RichiestaMappa?>(null);

  late Stream<bool> _community;
  bool _avviata = false;

  Sezione get attiva => _attiva;

  @override
  void initState() {
    super.initState();
    _aperta = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    _community = Servizi.of(context).archivio.osservaCommunity();
  }

  @override
  void dispose() {
    if (_aperta == this) _aperta = null;
    for (final r in _ritocchi.values) {
      r.dispose();
    }
    _mappa.dispose();
    super.dispose();
  }

  /// Va nella sezione [sezione], com'era. Con [viaggio], la mappa si apre su
  /// quello.
  void vaiA(Sezione sezione, {String? viaggio}) {
    if (sezione == Sezione.mappa && viaggio != null) {
      _mappa.value = (viaggio: viaggio, volta: (_mappa.value?.volta ?? 0) + 1);
    }
    if (sezione == _attiva) return;
    setState(() {
      _attiva = sezione;
      _costruite.add(sezione);
    });
  }

  /// Va in [sezione], sulla sua pagina, chiudendo quello che le sta sopra:
  /// «Guarda il passaporto» alla fine del riepilogo.
  void apriLaSezione(Sezione sezione) {
    _chiudiSopra();
    _pile[sezione]?.currentState?.popUntil((r) => r.isFirst);
    vaiA(sezione);
  }

  /// Apre [pagina] nella sezione Viaggi, sopra l'elenco, chiudendo quello
  /// che c'era: un invito, una notifica, un viaggio appena creato. Una pagina
  /// senza barra passa sopra.
  void apriNeiViaggi(Widget pagina) {
    _chiudiSopra();
    vaiA(Sezione.viaggi);
    final pila = _pile[Sezione.viaggi]!.currentState;
    pila?.popUntil((r) => r.isFirst);
    if (pagina is ConLaBarra) {
      unawaited(pila?.push(rotta<void>(pagina)));
    } else {
      unawaited(
        Navigator.of(context, rootNavigator: true).push(rotta<void>(pagina)),
      );
    }
  }

  /// Dopo essere usciti da un viaggio: ogni sezione torna alla sua pagina,
  /// perché nessuna mostri più quel viaggio, e si torna all'elenco.
  void tornaAiViaggi() {
    _chiudiSopra();
    for (final pila in _pile.values) {
      pila.currentState?.popUntil((r) => r.isFirst);
    }
    vaiA(Sezione.viaggi);
  }

  void _chiudiSopra() =>
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);

  /// Toccare una voce: la sua sezione. Ritoccare quella attiva torna alla
  /// pagina della sezione, e da lì in cima.
  void _tocca(Sezione sezione) {
    if (sezione != _attiva) {
      vaiA(
        sezione,
        viaggio: sezione == Sezione.mappa ? _viaggioInVista() : null,
      );
      return;
    }
    final pila = _pile[sezione]!.currentState;
    if (pila != null && pila.canPop()) {
      pila.popUntil((r) => r.isFirst);
    } else {
      _ritocchi[sezione]!.suona();
    }
  }

  /// Il viaggio della pagina in cima alla sezione attiva, se ne mostra uno.
  String? _viaggioInVista() => switch (_cime[_attiva]!.cima) {
    RottaTrolley(pagina: final ConLaBarra pagina) => pagina.viaggioInVista,
    _ => null,
  };

  /// Indietro su Android: la pagina in cima alla sezione; dalla pagina della
  /// sezione, Viaggi; da Viaggi si esce.
  Future<void> _indietro() async {
    final pila = _pile[_attiva]!.currentState;
    if (pila != null && await pila.maybePop()) return;
    if (_attiva != Sezione.viaggi) {
      vaiA(Sezione.viaggi);
      return;
    }
    await SystemNavigator.pop();
  }

  Widget _paginaDi(Sezione sezione) => switch (sezione) {
    Sezione.viaggi => SchermataViaggi(onCodice: widget.onCodice),
    Sezione.mappa => SezioneMappa(richiesta: _mappa),
    Sezione.passaporto => const SchermataPassaporto(),
    Sezione.community => const SchermataCommunity(),
  };

  Widget _pila(Sezione sezione) => Ritocco(
    segnale: _ritocchi[sezione]!,
    child: Navigator(
      key: _pile[sezione],
      observers: [_cime[sezione]!],
      onGenerateRoute: (_) => RottaTrolley<void>(
        builder: (_) => _paginaDi(sezione),
        trascinabile: false,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return StreamBuilder<bool>(
      stream: _community,
      builder: (context, community) {
        final conCommunity = community.data == true;
        if (!conCommunity &&
            _attiva == Sezione.community &&
            community.hasData) {
          // La parte pubblica non c'è più: si torna ai viaggi.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) vaiA(Sezione.viaggi);
          });
        }
        // Quella attiva per ultima: sta sopra mentre l'altra sfuma.
        final ordine = [
          for (final s in Sezione.values)
            if (_costruite.contains(s) && s != _attiva) s,
          _attiva,
        ];
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (fatto, _) {
            if (!fatto) unawaited(_indietro());
          },
          child: ColoredBox(
            color: Colori.nebbia,
            child: Stack(
              children: [
                for (final s in ordine)
                  Positioned.fill(
                    key: ValueKey(s),
                    child: PassaggioSezione(
                      attiva: s == _attiva,
                      child: _pila(s),
                    ),
                  ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: mq.padding.bottom > 0 ? mq.padding.bottom - 6 : 20,
                  child: _barra(conCommunity)
                      .entra(context, ritardo: Ritmo.lungo, da: 40),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barra(bool conCommunity) {
    VoceBarra voce(
      Sezione sezione,
      String etichetta, {
      IconData? icona,
      Widget Function(Color)? simbolo,
    }) => VoceBarra(
      icona: icona,
      simbolo: simbolo,
      etichetta: etichetta,
      attiva: sezione == _attiva,
      onTap: () => _tocca(sezione),
    );

    return BarraPrincipale(
      prima: [
        voce(
          Sezione.viaggi,
          'Viaggi',
          icona: icona(
            ios: CupertinoIcons.briefcase,
            android: Icons.luggage_outlined,
          ),
        ),
        voce(
          Sezione.mappa,
          'Mappa',
          icona: icona(
            ios: CupertinoIcons.globe,
            android: Icons.public_rounded,
          ),
        ),
      ],
      dopo: [
        voce(
          Sezione.passaporto,
          'Passaporto',
          simbolo: (colore) => SimboloPassaporto(colore: colore),
        ),
        if (conCommunity || _attiva == Sezione.community)
          voce(
            Sezione.community,
            'Community',
            icona: icona(
              ios: CupertinoIcons.person_2,
              android: Icons.group_outlined,
            ),
          ),
      ],
      etichettaAggiungi: 'Nuovo viaggio',
      onAggiungi: () =>
          apri<void>(context, const SchermataNuovoViaggio(), dalBasso: true),
    );
  }
}

/// Tiene a mente la pagina in cima a una pila.
class _Cima extends NavigatorObserver {
  Route<dynamic>? cima;

  @override
  void didPush(Route<dynamic> rotta, Route<dynamic>? prima) => cima = rotta;

  @override
  void didPop(Route<dynamic> rotta, Route<dynamic>? prima) => cima = prima;

  @override
  void didRemove(Route<dynamic> rotta, Route<dynamic>? prima) {
    if (rotta == cima) cima = prima;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == cima) cima = newRoute;
  }
}

class _Segnale extends ChangeNotifier {
  void suona() => notifyListeners();
}

/// La sezione Mappa (08; tela, 50–58 e 125): il viaggio che conta oggi —
/// quello in corso, fra due quello scelto oggi, altrimenti il prossimo,
/// altrimenti l'ultimo concluso —, o quello della pagina da cui si è toccata
/// «Mappa». Si cambia dall'alto. Senza viaggi con le date lo dice.
class SezioneMappa extends StatefulWidget {
  const SezioneMappa({
    super.key,
    required this.richiesta,
    this.orologio = DateTime.now,
  });

  final ValueListenable<RichiestaMappa?> richiesta;
  final DateTime Function() orologio;

  @override
  State<SezioneMappa> createState() => _SezioneMappaState();
}

class _SezioneMappaState extends State<SezioneMappa> {
  late Stream<List<ViaggioInElenco>> _viaggi;
  bool _avviata = false;

  /// Il viaggio scelto oggi fra due in corso, letto una volta.
  String? _sceltoOggi;
  bool _letto = false;

  @override
  void initState() {
    super.initState();
    widget.richiesta.addListener(_richiesta);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _viaggi = archivio.osservaViaggiInElenco();
    unawaited(
      archivio.viaggioSceltoOggi(widget.orologio()).then((scelto) {
        if (!mounted) return;
        setState(() {
          _sceltoOggi = scelto;
          _letto = true;
        });
      }),
    );
  }

  @override
  void dispose() {
    widget.richiesta.removeListener(_richiesta);
    super.dispose();
  }

  void _richiesta() => setState(() {});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ViaggioInElenco>>(
    stream: _viaggi,
    builder: (context, letti) {
      final viaggi = [
        for (final v in letti.data ?? const <ViaggioInElenco>[]) v.viaggio,
      ];
      if (!letti.hasData || !_letto) {
        return const Pagina(corpo: Center(child: IndicatoreAttivita()));
      }
      final oggi = widget.orologio();
      final richiesta = widget.richiesta.value;
      final chiesto = viaggi
          .where((v) => v.id == richiesta?.viaggio && v.inizio != null)
          .firstOrNull;
      final id =
          chiesto?.id ??
          viaggioPerLaMappa(
            viaggi: viaggi,
            idDi: (v) => v.id,
            statoDi: (v) => v.statoA(oggi),
            inizioDi: (v) => v.inizio,
            sceltoOggi: _sceltoOggi,
          );
      if (id == null) return const _MappaVuota();
      return SchermataMappa(
        viaggioId: id,
        richiesta: richiesta?.volta ?? 0,
        inSezione: true,
        orologio: widget.orologio,
      );
    },
  );
}

/// La Mappa quando nessun viaggio ha le date (tela, 125).
class _MappaVuota extends StatelessWidget {
  const _MappaVuota();

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top,
          20,
          BarraPrincipale.ingombro + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const TitoloPagina('Mappa'),
          Pannello(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            raggio: 24,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colori.cobaltoChiaro,
                  ),
                  child: Icon(
                    icona(
                      ios: CupertinoIcons.globe,
                      android: Icons.public_rounded,
                    ),
                    size: 34,
                    color: Colori.cobalto,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ancora niente da mettere sulla mappa',
                  textAlign: TextAlign.center,
                  style: Testi.titoli(
                    18,
                    altezza: 1.25,
                  ).copyWith(color: Colori.inchiostro),
                ),
                const SizedBox(height: 10),
                Text(
                  'Qui vanno le tappe dei viaggi con le date. Quando '
                  'un\'idea prende le date, o ne crei uno con il +, le sue '
                  'giornate compaiono qui.',
                  textAlign: TextAlign.center,
                  style: Testi.corpo.copyWith(
                    color: Colori.ardesia,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ).entra(context),
        ],
      ),
    ),
  );
}
