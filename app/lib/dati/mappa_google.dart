/// La mappa di Google sul telefono (CR-06, passo 2; ADR-014): Maps SDK per
/// iOS e Android, con `google_maps_flutter`. Si usa solo da `mappe.dart`:
/// le schermate le passano segni e linee, e la comandano con un
/// [ControlloMappa].
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
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    this.onTocca,
  });

  final List<SegnoMappa> segni;
  final List<LineaMappa> linee;
  final Coordinate centro;
  final double zoom;
  final EdgeInsets margini;
  final void Function(ControlloMappa controllo) onPronta;
  final VoidCallback? onTocca;

  @override
  State<MappaGoogle> createState() => _MappaGoogleState();
}

class _MappaGoogleState extends State<MappaGoogle> {
  /// Le immagini dei segni, per aspetto e lato: si fanno una volta sola.
  final _immagini = <String, BitmapDescriptor>{};

  /// Quelle che si stanno facendo.
  final _inCorso = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disegnaMancanti();
  }

  @override
  void didUpdateWidget(MappaGoogle prima) {
    super.didUpdateWidget(prima);
    _disegnaMancanti();
  }

  String _chiave(SegnoMappa s) => '${s.aspetto}|${s.lato}';

  void _disegnaMancanti() {
    final rapporto = MediaQuery.devicePixelRatioOf(context);
    for (final s in widget.segni) {
      final chiave = _chiave(s);
      if (_immagini.containsKey(chiave) || !_inCorso.add(chiave)) continue;
      unawaited(
        immagineDelWidget(s.disegno, s.lato, rapporto).then((byte) {
          _inCorso.remove(chiave);
          if (!mounted || byte == null) return;
          setState(
            () => _immagini[chiave] = BitmapDescriptor.bytes(
              byte,
              width: s.lato,
              height: s.lato,
            ),
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ridotto = movimentoRidotto(context);
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _ll(widget.centro),
        zoom: widget.zoom,
      ),
      padding: widget.margini,
      minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      buildingsEnabled: false,
      onMapCreated: (c) => widget.onPronta(_ControlloGoogle(c, ridotto)),
      onTap: widget.onTocca == null ? null : (_) => widget.onTocca!(),
      polylines: {
        for (final l in widget.linee)
          Polyline(
            polylineId: PolylineId(l.id),
            points: [for (final p in l.punti) _ll(p)],
            color: l.colore,
            width: l.spessore.round(),
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      markers: {
        for (final s in widget.segni)
          if (_immagini[_chiave(s)] case final immagine?)
            Marker(
              markerId: MarkerId(s.id),
              position: _ll(s.posto),
              icon: immagine,
              anchor: const Offset(0.5, 0.5),
              consumeTapEvents: true,
              zIndexInt: s.sopra ? 1 : 0,
              onTap: s.onTap,
            ),
      },
    );
  }
}

LatLng _ll(Coordinate c) => LatLng(c.lat, c.lon);

class _ControlloGoogle implements ControlloMappa {
  _ControlloGoogle(this._c, this._ridotto);

  final GoogleMapController _c;
  final bool _ridotto;

  Future<void> _muovi(CameraUpdate cambio) =>
      _ridotto ? _c.moveCamera(cambio) : _c.animateCamera(cambio);

  @override
  Future<void> inquadra(
    List<Coordinate> punti, {
    double zoomMassimo = 16,
  }) async {
    if (punti.isEmpty) return;
    final sud = punti.map((p) => p.lat).reduce(math.min);
    final nord = punti.map((p) => p.lat).reduce(math.max);
    final ovest = punti.map((p) => p.lon).reduce(math.min);
    final est = punti.map((p) => p.lon).reduce(math.max);
    // Un punto solo, o tutti nello stesso posto: ci si va.
    if (nord - sud < 1e-5 && est - ovest < 1e-5) {
      return vai((lat: sud, lon: ovest), zoomMassimo);
    }
    await _muovi(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(sud, ovest),
          northeast: LatLng(nord, est),
        ),
        40,
      ),
    );
    if (await _c.getZoomLevel() > zoomMassimo) {
      await _muovi(CameraUpdate.zoomTo(zoomMassimo));
    }
  }

  @override
  Future<void> vai(Coordinate posto, double zoom) =>
      _muovi(CameraUpdate.newLatLngZoom(_ll(posto), zoom));
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
