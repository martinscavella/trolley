/// La mappa di Google sul telefono (CR-06, passi 2 e 4; ADR-014): Maps SDK
/// per iOS e Android, attraverso `google_navigation_flutter`, il plugin del
/// Navigation SDK. Uno solo per la mappa e per la guida, perché porta il suo
/// Maps SDK e due nella stessa app non convivono. Si usa solo da
/// `mappe.dart` e da `guida_google.dart`: le schermate passano segni e
/// linee, e la comandano con un [ControlloMappa].
///
/// Sopra ci va solo il nostro (ADR-014, condizioni europee): i segni delle
/// tappe, la loro linea, il puntino della persona. Niente nomi, indirizzi o
/// orari di Google sulla mappa. I segni sono i nostri widget, che qui
/// diventano immagini.
///
/// La mappa dell'SDK sul telefono non si paga a visualizzazione: niente da
/// contare per `consumo_mappe`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart' as g;

import '../aspetto/movimento.dart';
import '../dominio/mappa.dart';
import 'mappe.dart';

/// La mappa di Google, con i [segni] e le [linee] di chi la usa.
class MappaGoogle extends StatefulWidget {
  const MappaGoogle({
    super.key,
    required this.segni,
    required this.linee,
    required this.centro,
    required this.zoom,
    required this.margini,
    required this.onPronta,
    this.zonaDelLogo,
    this.interattiva = true,
    this.onTocca,
  });

  final List<SegnoMappa> segni;
  final List<LineaMappa> linee;
  final Coordinate centro;
  final double zoom;
  final EdgeInsets margini;

  /// Dove va il logo di Google, se non dove lo metterebbero i [margini]:
  /// la mappa lo mette nell'angolo in basso di questa zona.
  final EdgeInsets? zonaDelLogo;
  final bool interattiva;
  final void Function(ControlloMappa controllo) onPronta;
  final VoidCallback? onTocca;

  @override
  State<MappaGoogle> createState() => _MappaGoogleState();
}

class _MappaGoogleState extends State<MappaGoogle> {
  late final _sopra = SegniSullaMappa(this);
  g.GoogleMapViewController? _c;
  final _geometria = GeometriaMappa();

  EdgeInsets get _imbottitura => widget.zonaDelLogo ?? widget.margini;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sopra.aggiorna(widget.segni, widget.linee);
  }

  @override
  void didUpdateWidget(MappaGoogle prima) {
    super.didUpdateWidget(prima);
    _sopra.aggiorna(widget.segni, widget.linee);
    if ((prima.zonaDelLogo ?? prima.margini) != _imbottitura) {
      unawaited(_c?.setPadding(_imbottitura));
    }
  }

  @override
  void dispose() {
    _sopra.chiudi();
    super.dispose();
  }

  Future<void> _pronta(g.GoogleMapViewController c) async {
    _c = c;
    // Il puntino della persona è il nostro: quello di Google resta spento.
    await c.setBuildingsEnabled(false);
    await c.settings.setMyLocationButtonEnabled(false);
    if (!mounted) return;
    // Lo spazio può essere cambiato mentre la mappa si preparava (le schede
    // si misurano prima): si rimette quello di adesso.
    await c.setPadding(_imbottitura);
    if (!mounted) return;
    _sopra.collega(c);
    widget.onPronta(
      ControlloGoogle(
        c,
        movimentoRidotto(context),
        geometria: widget.zonaDelLogo == null ? null : _geometria,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Su iPhone la mappa aggiunge da sola la zona sicura dello schermo allo
    // spazio che le si lascia: il centro della camera tiene conto di tutti e
    // due.
    final sicura = Platform.isIOS
        ? MediaQuery.paddingOf(context)
        : EdgeInsets.zero;
    final imbottitura = _imbottitura;
    _geometria
      ..libero = (
        sopra: widget.margini.top,
        sotto: widget.margini.bottom,
        sinistra: widget.margini.left,
        destra: widget.margini.right,
      )
      ..camera = (
        sopra: imbottitura.top + sicura.top,
        sotto: imbottitura.bottom + sicura.bottom,
        sinistra: imbottitura.left + sicura.left,
        destra: imbottitura.right + sicura.right,
      );
    return LayoutBuilder(
      builder: (context, vincoli) {
        _geometria
          ..larghezza = vincoli.maxWidth
          ..altezza = vincoli.maxHeight;
        return _vista();
      },
    );
  }

  Widget _vista() => g.GoogleMapsMapView(
    initialCameraPosition: g.CameraPosition(
      target: latLng(widget.centro),
      zoom: widget.zoom,
    ),
    initialPadding: _imbottitura,
    initialMinZoomPreference: 3,
    initialMaxZoomPreference: 19,
    initialRotateGesturesEnabled: false,
    initialScrollGesturesEnabled: widget.interattiva,
    initialZoomGesturesEnabled: widget.interattiva,
    initialTiltGesturesEnabled: false,
    initialCompassEnabled: false,
    initialMapToolbarEnabled: false,
    initialZoomControlsEnabled: false,
    initialMapColorScheme: g.MapColorScheme.light,
    onViewCreated: (c) => unawaited(_pronta(c)),
    onMarkerClicked: _sopra.toccato,
    onMapClicked: widget.onTocca == null ? null : (_) => widget.onTocca!(),
  );
}

g.LatLng latLng(Coordinate c) => g.LatLng(latitude: c.lat, longitude: c.lon);

/// Tiene i segni e le linee di una mappa di Google uguali a quelli che le
/// schermate chiedono. Sulla mappa del plugin si aggiungono, si cambiano e
/// si tolgono a comando: qui si fa la differenza, una volta alla volta.
/// Serve alla mappa e alla guida.
class SegniSullaMappa {
  SegniSullaMappa(this._stato);

  final State _stato;
  g.GoogleMapViewController? _c;
  var _chiuso = false;

  var _segni = const <SegnoMappa>[];
  var _linee = const <LineaMappa>[];

  /// Le immagini dei segni, per aspetto e lato: si fanno una volta sola.
  final _immagini = <String, g.ImageDescriptor>{};
  final _inCorso = <String>{};

  /// I segni sulla mappa, per il nostro nome; e il nostro nome per quello
  /// che la mappa ha dato loro.
  final _messi = <String, g.Marker>{};
  final _nostri = <String, String>{};
  final _opzioni = <String, g.MarkerOptions>{};

  var _lineeMesse = const <LineaMappa>[];

  /// Una sincronizzazione per volta; se ne serve un'altra si rifà dopo.
  bool _occupato = false;
  bool _ancora = false;

  void collega(g.GoogleMapViewController c) {
    _c = c;
    _sincronizza();
  }

  void aggiorna(List<SegnoMappa> segni, List<LineaMappa> linee) {
    _segni = segni;
    _linee = linee;
    _disegnaMancanti();
    _sincronizza();
  }

  void chiudi() {
    _chiuso = true;
    // Le immagini restano registrate finché l'app è aperta: le usano anche
    // le altre mappe, e sono poche.
  }

  /// Toccato il segno che la mappa chiama [id].
  void toccato(String id) {
    final nostro = _nostri[id];
    for (final s in _segni) {
      if (s.id == nostro) return s.onTap?.call();
    }
  }

  static String _chiave(SegnoMappa s) => '${s.aspetto}|${s.lato}';

  void _disegnaMancanti() {
    final rapporto = MediaQuery.devicePixelRatioOf(_stato.context);
    for (final s in _segni) {
      final chiave = _chiave(s);
      // Un'immagine già registrata da un'altra mappa si riusa: _registra
      // la ridà senza rifarla.
      if (_immagini.containsKey(chiave) || !_inCorso.add(chiave)) {
        continue;
      }
      unawaited(
        _registra(s, rapporto).then((immagine) {
          _inCorso.remove(chiave);
          if (immagine == null || _chiuso) return;
          _immagini[chiave] = immagine;
          _sincronizza();
        }),
      );
    }
  }

  /// Le immagini già registrate da qualunque mappa: si registrano una volta
  /// per tutta l'app.
  static final _registrate = <String, Future<g.ImageDescriptor?>>{};

  Future<g.ImageDescriptor?> _registra(SegnoMappa s, double rapporto) =>
      _registrate
          .putIfAbsent(_chiave(s), () async {
            final png = await immagineDelWidget(s.disegno, s.lato, rapporto);
            if (png == null) return null;
            try {
              // Solo la densità: con anche la misura, il plugin su iOS
              // scala due volte e il segno esce di un terzo.
              return await g.registerBitmapImage(
                bitmap: ByteData.sublistView(png),
                imagePixelRatio: rapporto,
              );
            } on Object {
              return null;
            }
          })
          .then((immagine) {
            if (immagine == null) _registrate.remove(_chiave(s));
            return immagine;
          });

  void _sincronizza() {
    if (_c == null || _chiuso) return;
    if (_occupato) {
      _ancora = true;
      return;
    }
    _occupato = true;
    unawaited(
      _applica()
          .catchError((Object e) {
            // La mappa si è chiusa mentre si scriveva: niente da fare.
            debugPrint('Segni sulla mappa: $e');
          })
          .whenComplete(() {
            _occupato = false;
            if (_ancora && !_chiuso) {
              _ancora = false;
              _sincronizza();
            }
          }),
    );
  }

  Future<void> _applica() async {
    final c = _c!;
    // Per prima cosa quello che non serve più, poi quello che è cambiato,
    // poi il nuovo: l'immagine di un segno che non c'è ancora aspetta.
    final voluti = <String, g.MarkerOptions>{};
    for (final s in _segni) {
      if (_immagini[_chiave(s)] case final immagine?) {
        voluti[s.id] = g.MarkerOptions(
          position: latLng(s.posto),
          icon: immagine,
          anchor: const g.MarkerAnchor(u: 0.5, v: 0.5),
          consumeTapEvents: true,
          zIndex: s.sopra ? 1 : 0,
          rotation: s.rotazione ?? 0,
          flat: s.rotazione != null,
        );
      }
    }
    final via = [
      for (final MapEntry(:key, :value) in _messi.entries)
        if (!voluti.containsKey(key)) value,
    ];
    if (via.isNotEmpty) {
      await c.removeMarkers(via);
      for (final m in via) {
        _nostri.remove(m.markerId);
      }
      _messi.removeWhere((id, _) => !voluti.containsKey(id));
      _opzioni.removeWhere((id, _) => !voluti.containsKey(id));
    }
    final cambiati = [
      for (final MapEntry(:key, :value) in voluti.entries)
        if (_messi[key] case final m? when _opzioni[key] != value)
          m.copyWith(options: value),
    ];
    if (cambiati.isNotEmpty) {
      for (final m in await c.updateMarkers(cambiati)) {
        if (m == null) continue;
        final nostro = _nostri[m.markerId];
        if (nostro == null) continue;
        _messi[nostro] = m;
        _opzioni[nostro] = m.options;
      }
    }
    final nuovi = [
      for (final id in voluti.keys)
        if (!_messi.containsKey(id)) id,
    ];
    if (nuovi.isNotEmpty) {
      final messi = await c.addMarkers([for (final id in nuovi) voluti[id]!]);
      for (final (i, m) in messi.indexed) {
        if (m == null || i >= nuovi.length) continue;
        _messi[nuovi[i]] = m;
        _nostri[m.markerId] = nuovi[i];
        _opzioni[nuovi[i]] = voluti[nuovi[i]]!;
      }
    }

    if (!listEquals(_lineeMesse, _linee)) {
      final linee = _linee;
      await c.clearPolylines();
      if (linee.isNotEmpty) {
        await c.addPolylines([
          for (final l in linee)
            g.PolylineOptions(
              points: [for (final p in l.punti) latLng(p)],
              strokeColor: l.colore,
              strokeWidth: l.spessore,
              strokeJointType: g.StrokeJointType.round,
            ),
        ]);
      }
      _lineeMesse = linee;
    }
  }
}

/// Com'è fatta la mappa sullo schermo, per inquadrare da sé.
class GeometriaMappa {
  double larghezza = 0;
  double altezza = 0;
  Bordi libero = (sopra: 0, sotto: 0, sinistra: 0, destra: 0);
  Bordi camera = (sopra: 0, sotto: 0, sinistra: 0, destra: 0);
}

/// Comanda una mappa di Google: inquadrare dei punti, andare in un posto.
/// Con la [geometria] inquadra da sé, nello spazio libero dalle schede:
/// quello che la mappa lascia al logo non c'entra.
class ControlloGoogle implements ControlloMappa {
  ControlloGoogle(this._c, this._ridotto, {this.geometria});

  final g.GoogleMapViewController _c;
  final bool _ridotto;
  final GeometriaMappa? geometria;

  Future<void> _vaiDaSe(
    List<Coordinate> punti,
    double zoomMassimo, {
    double? zoom,
  }) {
    final geo = geometria!;
    final dove = inquadratura(
      punti,
      larghezza: geo.larghezza,
      altezza: geo.altezza,
      libero: geo.libero,
      camera: geo.camera,
      zoomMassimo: zoomMassimo,
      zoom: zoom,
    );
    return _muovi(g.CameraUpdate.newLatLngZoom(latLng(dove.centro), dove.zoom));
  }

  Future<void> _muovi(g.CameraUpdate cambio) async {
    if (_ridotto) return _c.moveCamera(cambio);
    final finita = Completer<void>();
    await _c.animateCamera(
      cambio,
      duration: Ritmo.medio,
      onFinished: (_) {
        if (!finita.isCompleted) finita.complete();
      },
    );
    // Su qualche telefono la fine non arriva: non si aspetta per sempre.
    await finita.future.timeout(Ritmo.medio * 3, onTimeout: () {});
  }

  @override
  Future<void> inquadra(
    List<Coordinate> punti, {
    double zoomMassimo = 16,
  }) async {
    if (punti.isEmpty) return;
    if (geometria case final geo? when geo.altezza > 0) {
      return _vaiDaSe(punti, zoomMassimo);
    }
    final sud = punti.map((p) => p.lat).reduce(math.min);
    final nord = punti.map((p) => p.lat).reduce(math.max);
    final ovest = punti.map((p) => p.lon).reduce(math.min);
    final est = punti.map((p) => p.lon).reduce(math.max);
    // Un punto solo, o tutti nello stesso posto: ci si va.
    if (nord - sud < 1e-5 && est - ovest < 1e-5) {
      return vai((lat: sud, lon: ovest), zoomMassimo);
    }
    await _muovi(
      g.CameraUpdate.newLatLngBounds(
        g.LatLngBounds(
          southwest: g.LatLng(latitude: sud, longitude: ovest),
          northeast: g.LatLng(latitude: nord, longitude: est),
        ),
        padding: 40,
      ),
    );
    if ((await _c.getCameraPosition()).zoom > zoomMassimo) {
      await _muovi(g.CameraUpdate.zoomTo(zoomMassimo));
    }
  }

  @override
  Future<void> vai(Coordinate posto, double zoom) {
    if (geometria case final geo? when geo.altezza > 0) {
      return _vaiDaSe([posto], zoom, zoom: zoom);
    }
    return _muovi(g.CameraUpdate.newLatLngZoom(latLng(posto), zoom));
  }
}

/// Un widget come immagine PNG di [lato] punti, alla densità [rapporto]:
/// il segno di una tappa per la mappa di Google. Si disegna fuori dallo
/// schermo, senza animazioni.
Future<Uint8List?> immagineDelWidget(
  Widget disegno,
  double lato,
  double rapporto,
) async {
  final confine = RenderRepaintBoundary();
  final vista =
      WidgetsBinding.instance.platformDispatcher.implicitView ??
      WidgetsBinding.instance.platformDispatcher.views.first;
  final radice = RenderView(
    view: vista,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(Size.square(lato)),
      physicalConstraints: BoxConstraints.tight(Size.square(lato * rapporto)),
      devicePixelRatio: rapporto,
    ),
    child: RenderPositionedBox(child: confine),
  );
  final tubo = PipelineOwner()..rootNode = radice;
  radice.prepareInitialFrame();
  final costruttore = BuildOwner(focusManager: FocusManager());
  final elemento = RenderObjectToWidgetAdapter<RenderBox>(
    container: confine,
    child: MediaQuery(
      data: MediaQueryData(
        size: Size.square(lato),
        devicePixelRatio: rapporto,
        disableAnimations: true,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: disegno),
      ),
    ),
  ).attachToRenderTree(costruttore);
  costruttore
    ..buildScope(elemento)
    ..finalizeTree();
  tubo
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final immagine = await confine.toImage(pixelRatio: rapporto);
  final dati = await immagine.toByteData(format: ui.ImageByteFormat.png);
  immagine.dispose();
  return dati?.buffer.asUint8List();
}
