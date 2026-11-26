/// La guida con il Navigation SDK di Google (CR-06, passo 4; ADR-014), dal
/// plugin `google_navigation_flutter`. Si usa solo dietro [Guida].
///
/// Di Google si vede la mappa, la strada e il logo: l'intestazione con la
/// svolta e i pulsanti sono nostri (tela, 163), fatti con le indicazioni
/// che la guida dà passo passo. Spenti anche la scheda in basso di Google,
/// il tachimetro, i limiti, il traffico: si va a piedi.
///
/// I segnali di quando l'app si chiude male non vanno a Google
/// (`abnormalTerminationReportingEnabled`): non servono a guidare.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart' as g;

import '../aspetto/movimento.dart';
import '../aspetto/segni_mappa.dart';
import '../aspetto/tavolozza.dart';
import '../dominio/mappa.dart';
import 'guida.dart';
import 'mappa_google.dart';
import 'mappe.dart';

class GuidaGoogle implements Guida {
  GuidaGoogle();

  /// La voce come la vuole la persona. Google la riaccende da sé quando
  /// una guida nuova parte o la strada cambia: si rimette ogni volta.
  bool _voce = true;

  /// Quante guide sono partite: una chiusura vecchia non chiude la nuova.
  int _giro = 0;

  final _rimasto = StreamController<Rimasto>.broadcast();
  final _arrivo = StreamController<void>.broadcast();
  final _indicazioni = StreamController<Indicazione>.broadcast();
  final _ascolti = <StreamSubscription<Object?>>[];

  @override
  bool get disponibile => Platform.isIOS || Platform.isAndroid;

  @override
  Stream<Rimasto> get rimasto => _rimasto.stream;

  @override
  Stream<void> get arrivo => _arrivo.stream;

  @override
  Stream<Indicazione> get indicazioni => _indicazioni.stream;

  @override
  Future<EsitoGuida> prepara() async {
    _giro++;
    try {
      if (!await g.GoogleMapsNavigator.areTermsAccepted()) {
        // Le condizioni della guida di Google: si accettano una volta.
        final accettate =
            await g.GoogleMapsNavigator.showTermsAndConditionsDialog(
              'La guida di Google',
              'Trolley',
              // Il testo è di Google; i colori sono i nostri.
              uiParams: const g.TermsAndConditionsUIParams(
                backgroundColor: Colori.bianco,
                titleColor: Colori.inchiostro,
                mainTextColor: Colori.ardesia,
                acceptButtonTextColor: Colori.cobalto,
                cancelButtonTextColor: Colori.grafite,
              ),
            );
        if (!accettate) return EsitoGuida.condizioniRifiutate;
      }
      if (!await g.GoogleMapsNavigator.isInitialized()) {
        await g.GoogleMapsNavigator.initializeNavigationSession(
          abnormalTerminationReportingEnabled: false,
          taskRemovedBehavior: g.TaskRemovedBehavior.quitService,
        );
      }
    } on g.SessionInitializationException catch (e) {
      return switch (e.code) {
        g.SessionInitializationError.termsNotAccepted =>
          EsitoGuida.condizioniRifiutate,
        g.SessionInitializationError.locationPermissionMissing =>
          EsitoGuida.senzaPosizione,
        g.SessionInitializationError.notAuthorized => EsitoGuida.nonDisponibile,
      };
    } on PlatformException {
      return EsitoGuida.nonDisponibile;
    }
    _ascolta();
    await _applicaVoce();
    return EsitoGuida.ok;
  }

  void _ascolta() {
    if (_ascolti.isNotEmpty) return;
    _ascolti
      ..add(
        g.GoogleMapsNavigator.setOnRemainingTimeOrDistanceChangedListener(
          (e) => _rimasto.add(
            Rimasto(
              metri: e.remainingDistance,
              tempo: Duration(seconds: e.remainingTime.round()),
            ),
          ),
          remainingTimeThresholdSeconds: 10,
          remainingDistanceThresholdMeters: 10,
        ),
      )
      ..add(
        g.GoogleMapsNavigator.setOnArrivalListener((_) => _arrivo.add(null)),
      )
      ..add(
        g.GoogleMapsNavigator.setOnRouteChangedListener(
          () => unawaited(_applicaVoce()),
        ),
      )
      ..add(
        g.GoogleMapsNavigator.setNavInfoListener((e) {
          final indicazione = indicazioneDaGoogle(e.navInfo);
          if (indicazione != null) _indicazioni.add(indicazione);
        }, numNextStepsToPreview: 0),
      );
  }

  @override
  Future<EsitoGuida> parti({
    required String titolo,
    required Coordinate posto,
    String? placeId,
  }) async {
    final destinazioni = g.Destinations(
      waypoints: [
        if (placeId != null && placeId.isNotEmpty)
          g.NavigationWaypoint.withPlaceID(title: titolo, placeID: placeId)
        else
          g.NavigationWaypoint.withLatLngTarget(
            title: titolo,
            target: latLng(posto),
          ),
      ],
      // Il segno della tappa è il nostro.
      displayOptions: g.NavigationDisplayOptions(showDestinationMarkers: false),
      routingOptions: g.RoutingOptions(
        travelMode: g.NavigationTravelMode.walking,
      ),
    );
    try {
      var stato = await g.GoogleMapsNavigator.setDestinations(destinazioni);
      if (stato == g.NavigationRouteStatus.locationUnavailable ||
          stato == g.NavigationRouteStatus.locationUnknown) {
        // La strada si calcola da dove si è: si aspetta che il telefono lo
        // sappia, una volta.
        if (await _primaPosizione()) {
          stato = await g.GoogleMapsNavigator.setDestinations(destinazioni);
        }
      }
      final esito = esitoDaGoogle(stato);
      if (esito == EsitoGuida.ok) {
        await _applicaVoce();
        await g.GoogleMapsNavigator.startGuidance();
        await _applicaVoce();
        // Su iPhone la guida finisce di partire un attimo dopo, e può
        // rimettere la voce: la si toglie di nuovo.
        unawaited(
          Future<void>.delayed(const Duration(seconds: 1))
              .then((_) => _applicaVoce()),
        );
      }
      return esito;
    } on g.SessionNotInitializedException {
      return EsitoGuida.nonDisponibile;
    } on PlatformException {
      return EsitoGuida.nonDisponibile;
    }
  }

  /// Aspetta la prima posizione della guida, al massimo venti secondi.
  Future<bool> _primaPosizione() async {
    final arrivata = Completer<bool>();
    final ascolto =
        await g.GoogleMapsNavigator.setRoadSnappedLocationUpdatedListener((_) {
          if (!arrivata.isCompleted) arrivata.complete(true);
        });
    try {
      return await arrivata.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => false,
      );
    } finally {
      await ascolto.cancel();
    }
  }

  @override
  Future<void> voce({required bool accesa}) async {
    _voce = accesa;
    await _applicaVoce();
  }

  Future<void> _applicaVoce() async {
    try {
      await g.GoogleMapsNavigator.setAudioGuidance(
        g.NavigationAudioGuidanceSettings(
          guidanceType: _voce
              ? g.NavigationAudioGuidanceType.alertsAndGuidance
              : g.NavigationAudioGuidanceType.silent,
        ),
      );
    } on Object {
      // La guida non c'è ancora, o si è già chiusa.
    }
  }

  @override
  Future<void> ferma() async {
    final giro = _giro;
    // Si svuota subito: una guida che riparte intanto mette i suoi.
    final vecchi = [..._ascolti];
    _ascolti.clear();
    for (final a in vecchi) {
      await a.cancel();
    }
    try {
      if (!await g.GoogleMapsNavigator.isInitialized()) return;
      // Intanto ne è partita un'altra: la sessione è sua.
      if (giro != _giro) return;
      await g.GoogleMapsNavigator.stopGuidance();
      await g.GoogleMapsNavigator.clearDestinations();
      await g.GoogleMapsNavigator.cleanup();
    } on Object {
      // Già chiusa.
    }
  }

  @override
  Widget vista({
    required List<SegnoMappa> segni,
    required Coordinate centro,
    EdgeInsets margini = EdgeInsets.zero,
    bool inclinata = true,
    Coordinate? qui,
    double? verso,
    required void Function(ControlloGuida controllo) onPronta,
    void Function(bool segue)? onSegue,
  }) => _VistaGuida(
    segni: segni,
    centro: centro,
    margini: margini,
    inclinata: inclinata,
    qui: qui,
    verso: verso,
    onPronta: onPronta,
    onSegue: onSegue,
  );
}

/// Che cosa vuol dire la risposta di Google a una destinazione.
EsitoGuida esitoDaGoogle(g.NavigationRouteStatus stato) => switch (stato) {
  g.NavigationRouteStatus.statusOk => EsitoGuida.ok,
  g.NavigationRouteStatus.routeNotFound ||
  g.NavigationRouteStatus.waypointError ||
  g.NavigationRouteStatus.noWaypointsError ||
  g.NavigationRouteStatus.duplicateWaypointsError => EsitoGuida.nonTrovata,
  g.NavigationRouteStatus.networkError ||
  g.NavigationRouteStatus.routingTimeout => EsitoGuida.senzaRete,
  g.NavigationRouteStatus.quotaExceeded ||
  g.NavigationRouteStatus.quotaCheckFailed => EsitoGuida.tetto,
  g.NavigationRouteStatus.locationUnavailable ||
  g.NavigationRouteStatus.locationUnknown => EsitoGuida.senzaPosizione,
  g.NavigationRouteStatus.internalError ||
  g.NavigationRouteStatus.apiKeyNotAuthorized ||
  g.NavigationRouteStatus.statusCanceled ||
  g.NavigationRouteStatus.travelModeUnsupported ||
  g.NavigationRouteStatus.unknown => EsitoGuida.nonDisponibile,
};

/// L'indicazione di adesso, dai dati della guida; `null` se non c'è un
/// passo.
Indicazione? indicazioneDaGoogle(g.NavInfo info) {
  if (info.navState == g.NavState.rerouting) {
    return const Indicazione(
      svolta: Svolta.dritto,
      testo: 'Cerco una strada nuova…',
      ricalcolo: true,
    );
  }
  final passo = info.currentStep;
  if (passo == null) return null;
  final testo =
      [passo.fullInstructions, passo.simpleRoadName, passo.fullRoadName]
          .whereType<String>()
          .map((t) => t.trim())
          .firstWhere((t) => t.isNotEmpty, orElse: () => '');
  return Indicazione(
    svolta: svoltaDaGoogle(passo.maneuver),
    testo: testo,
    metri: info.distanceToCurrentStepMeters?.toDouble(),
  );
}

/// La svolta di una manovra di Google. Le manovre sono più di ottanta: si
/// leggono dal nome, dalla più precisa alla più generica.
Svolta svoltaDaGoogle(g.Maneuver manovra) {
  final n = manovra.name;
  if (n.startsWith('destination')) return Svolta.arrivo;
  if (n.startsWith('roundabout')) return Svolta.rotonda;
  if (n.startsWith('ferry')) return Svolta.traghetto;
  if (n.contains('UTurn')) return Svolta.inversione;
  if (n.contains('KeepLeft') || n == 'forkLeft' || n == 'mergeLeft') {
    return Svolta.tieniLaSinistra;
  }
  if (n.contains('KeepRight') || n == 'forkRight' || n == 'mergeRight') {
    return Svolta.tieniLaDestra;
  }
  if (n.endsWith('SharpLeft')) return Svolta.strettaASinistra;
  if (n.endsWith('SharpRight')) return Svolta.strettaADestra;
  if (n.endsWith('SlightLeft')) return Svolta.leggermenteASinistra;
  if (n.endsWith('SlightRight')) return Svolta.leggermenteADestra;
  if (n.endsWith('Left')) return Svolta.aSinistra;
  if (n.endsWith('Right')) return Svolta.aDestra;
  return Svolta.dritto;
}

/// I metri fra due punti vicini.
double metriFra(g.LatLng a, g.LatLng b) {
  const raggio = 6371000.0;
  final f1 = a.latitude * math.pi / 180;
  final f2 = b.latitude * math.pi / 180;
  final df = f2 - f1;
  final dl = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.sin(df / 2) * math.sin(df / 2) +
      math.cos(f1) * math.cos(f2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * raggio * math.asin(math.min(1, math.sqrt(h)));
}

/// Da che parte si va da [a] a [b], in gradi da nord, in senso orario.
double direzioneFra(g.LatLng a, g.LatLng b) {
  final f1 = a.latitude * math.pi / 180;
  final f2 = b.latitude * math.pi / 180;
  final dl = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dl) * math.cos(f2);
  final x =
      math.cos(f1) * math.sin(f2) - math.sin(f1) * math.cos(f2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

class _VistaGuida extends StatefulWidget {
  const _VistaGuida({
    required this.segni,
    required this.centro,
    required this.margini,
    required this.inclinata,
    required this.qui,
    required this.verso,
    required this.onPronta,
    required this.onSegue,
  });

  final List<SegnoMappa> segni;
  final Coordinate centro;
  final EdgeInsets margini;
  final bool inclinata;
  final Coordinate? qui;
  final double? verso;
  final void Function(ControlloGuida controllo) onPronta;
  final void Function(bool segue)? onSegue;

  @override
  State<_VistaGuida> createState() => _VistaGuidaState();
}

/// La mappa della guida è tutta nostra: la grafica di navigazione di
/// Google è spenta (intestazione, pulsanti, la sua strada, la sua freccia),
/// e così il logo sta dove sta nelle altre mappe. La guida, la voce e le
/// indicazioni vanno avanti lo stesso: sono della sessione, non della vista.
/// La strada è la nostra linea cobalto, la persona il nostro puntino, e la
/// mappa la seguiamo noi, con la persona al centro (tela, 163).
class _VistaGuidaState extends State<_VistaGuida> {
  late final _sopra = SegniSullaMappa(this);
  g.GoogleNavigationViewController? _c;

  bool _seguo = false;
  late bool _inclinata = widget.inclinata;
  g.LatLng? _ultima;

  /// Dove si va: si cambia quando ci si è spostati abbastanza da saperlo,
  /// non a ogni tremolio della posizione.
  double _direzione = 0;
  g.LatLng? _daDove;

  /// La strada di Google, punto per punto; si disegna da dove si è in poi.
  var _strada = const <g.LatLng>[];
  DateTime? _stradaChiesta;

  final _ascolti = <StreamSubscription<Object?>>[];

  static const _zoom = 17.5;
  static const _gradi = 45.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ridisegna();
  }

  /// Quando la guida ha dato l'ultima posizione sulla strada: finché ne dà,
  /// valgono quelle; altrimenti quella del telefono ([_VistaGuida.qui]).
  DateTime? _dallaGuida;

  @override
  void didUpdateWidget(_VistaGuida prima) {
    super.didUpdateWidget(prima);
    final qui = widget.qui;
    final dallaGuida = _dallaGuida;
    if (qui != null &&
        qui != prima.qui &&
        (dallaGuida == null ||
            DateTime.now().difference(dallaGuida) >
                const Duration(seconds: 5))) {
      _nuovaPosizione(latLng(qui));
    }
    _ridisegna();
    if (prima.margini != widget.margini) {
      unawaited(_c?.setPadding(widget.margini));
    }
  }

  @override
  void dispose() {
    for (final a in _ascolti) {
      unawaited(a.cancel());
    }
    _sopra.chiudi();
    super.dispose();
  }

  /// I segni di chi usa la vista, il nostro puntino, la strada che resta.
  void _ridisegna() {
    final qui = _ultima;
    _sopra.aggiorna(
      [
        ...widget.segni,
        if (qui != null)
          if (widget.verso case final verso?)
            SegnoMappa(
              id: 'qui',
              posto: (lat: qui.latitude, lon: qui.longitude),
              lato: PuntinoPosizione.latoConVerso,
              aspetto: 'qui-verso',
              sopra: true,
              rotazione: verso,
              disegno: const PuntinoPosizione(conVerso: true),
            )
          else
            SegnoMappa(
              id: 'qui',
              posto: (lat: qui.latitude, lon: qui.longitude),
              lato: PuntinoPosizione.lato,
              aspetto: 'qui',
              sopra: true,
              disegno: const PuntinoPosizione(),
            ),
      ],
      [
        if (_strada.length >= 2)
          LineaMappa(
            id: 'strada',
            punti: [
              for (final p in _strada) (lat: p.latitude, lon: p.longitude),
            ],
            colore: Colori.cobalto,
            spessore: 6,
          ),
      ],
    );
  }

  Future<void> _pronta(g.GoogleNavigationViewController c) async {
    _c = c;
    try {
      await c.setNavigationUIEnabled(false);
      await c.setMyLocationEnabled(false);
      await c.setBuildingsEnabled(false);
      await c.settings.setMyLocationButtonEnabled(false);
    } on PlatformException {
      // Una regolazione che non c'è su questo telefono: la guida va lo
      // stesso.
    }
    try {
      _ascolti
        ..add(
          await g.GoogleMapsNavigator.setRoadSnappedLocationUpdatedListener((
            e,
          ) {
            _dallaGuida = DateTime.now();
            _nuovaPosizione(e.location);
          }),
        )
        ..add(
          g.GoogleMapsNavigator.setOnRouteChangedListener(
            () => unawaited(_chiediStrada()),
          ),
        );
    } on Object {
      // Senza le posizioni della guida, quella del telefono basta a
      // tornare dove si è.
    }
    if (!mounted) return;
    _sopra.collega(c);
    widget.onPronta(_ControlloGuidaGoogle(this));
  }

  Future<void> _chiediStrada() async {
    _stradaChiesta = DateTime.now();
    try {
      final pezzi = await g.GoogleMapsNavigator.getRouteSegments();
      if (!mounted) return;
      _strada = [
        for (final pezzo in pezzi) ...?pezzo.latLngs?.whereType<g.LatLng>(),
      ];
      _tagliaStrada();
      _ridisegna();
    } on Object {
      // Nessuna strada ancora: arriverà con la prossima.
    }
  }

  /// Toglie la strada già fatta: resta da dove si è in poi.
  void _tagliaStrada() {
    final qui = _ultima;
    if (qui == null || _strada.length < 2) return;
    var vicino = 0;
    var meglio = double.infinity;
    // Si cerca solo nel primo tratto: si va avanti, non si salta.
    final fino = math.min(_strada.length, 200);
    for (var i = 0; i < fino; i++) {
      final m = metriFra(qui, _strada[i]);
      if (m < meglio) {
        meglio = m;
        vicino = i;
      }
    }
    _strada = [qui, ..._strada.skip(vicino + 1)];
  }

  void _nuovaPosizione(g.LatLng dove) {
    if (!mounted) return;
    _ultima = dove;
    final da = _daDove;
    if (da == null) {
      _daDove = dove;
    } else if (metriFra(da, dove) >= 5) {
      _direzione = direzioneFra(da, dove);
      _daDove = dove;
    }
    // La strada arriva quando la guida parte; se non è arrivata, la si
    // richiede ogni tanto.
    final chiesta = _stradaChiesta;
    if (_strada.isEmpty &&
        (chiesta == null ||
            DateTime.now().difference(chiesta) > const Duration(seconds: 5))) {
      unawaited(_chiediStrada());
    }
    _tagliaStrada();
    _ridisegna();
    if (_seguo) unawaited(_centra(dove));
  }

  Future<void> _centra(g.LatLng dove, {Duration? durata}) async {
    final c = _c;
    if (c == null || !mounted) return;
    final cambio = g.CameraUpdate.newCameraPosition(
      g.CameraPosition(
        target: dove,
        zoom: _zoom,
        // In 3D inclinata e girata dove si cammina; in 2D dall'alto, col
        // nord in alto.
        tilt: _inclinata ? _gradi : 0,
        bearing: _inclinata ? _direzione : 0,
      ),
    );
    try {
      if (movimentoRidotto(context)) {
        await c.moveCamera(cambio);
      } else {
        await c.animateCamera(cambio, duration: durata ?? Ritmo.lungo);
      }
    } on PlatformException {
      // La mappa si sta chiudendo.
    }
  }

  Future<void> _seguimi() async {
    _seguo = true;
    widget.onSegue?.call(true);
    final dove =
        _ultima ??
        (widget.qui == null ? null : latLng(widget.qui!)) ??
        await _c?.getMyLocation();
    if (dove != null) await _centra(dove);
  }

  Future<void> _inclina(bool inclinata) async {
    _inclinata = inclinata;
    final dove = _seguo
        ? (_ultima ?? await _c?.getMyLocation())
        : (await _c?.getCameraPosition())?.target;
    // Più lenta del solito: si vede la mappa che si alza o si abbassa.
    if (dove != null) {
      await _centra(dove, durata: const Duration(milliseconds: 900));
    }
  }

  void _smetti() {
    if (!_seguo) return;
    _seguo = false;
    widget.onSegue?.call(false);
  }

  @override
  Widget build(BuildContext context) => g.GoogleMapsNavigationView(
    initialCameraPosition: g.CameraPosition(
      target: latLng(widget.centro),
      zoom: 16.5,
    ),
    initialPadding: widget.margini,
    initialCompassEnabled: false,
    initialMapToolbarEnabled: false,
    initialZoomControlsEnabled: false,
    initialTiltGesturesEnabled: false,
    initialRotateGesturesEnabled: false,
    initialMapColorScheme: g.MapColorScheme.light,
    initialNavigationUIEnabledPreference:
        g.NavigationUIEnabledPreference.disabled,
    onViewCreated: (c) => unawaited(_pronta(c)),
    onMarkerClicked: _sopra.toccato,
    onCameraMoveStarted: (_, gesto) {
      if (gesto) _smetti();
    },
  );
}

class _ControlloGuidaGoogle implements ControlloGuida {
  _ControlloGuidaGoogle(this._vista);

  final _VistaGuidaState _vista;

  @override
  Future<void> seguimi() => _vista._seguimi();

  @override
  Future<void> inclina({required bool inclinata}) => _vista._inclina(inclinata);
}
