/// I confini dei paesi per il mappamondo (ADR-005): incorporati nell'app come
/// l'elenco delle destinazioni, così il mappamondo funziona senza rete e non
/// dipende da nessun fornitore. Li scrive `tool/genera_confini.dart`, che
/// descrive il file.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class Confini {
  Confini._(this._paesi);

  /// Dal file: per ogni paese i suoi contorni, ciascuno come punti sulla
  /// sfera di raggio uno (x, y, z di seguito), pronti da girare.
  factory Confini.daByte(ByteData dati) {
    var i = 0;
    int u16() => dati.getUint16((i += 2) - 2, Endian.little);
    double gradi() => dati.getInt16((i += 2) - 2, Endian.little) / 100;
    final paesi = <String, List<Float32List>>{};
    for (var p = u16(); p > 0; p--) {
      final codice = String.fromCharCodes([
        dati.getUint8(i++),
        dati.getUint8(i++),
      ]);
      final contorni = <Float32List>[];
      for (var c = u16(); c > 0; c--) {
        final n = u16();
        final punti = Float32List(n * 3);
        for (var k = 0; k < n; k++) {
          final lon = gradi() * pi / 180;
          final lat = gradi() * pi / 180;
          punti
            ..[k * 3] = cos(lat) * cos(lon)
            ..[k * 3 + 1] = cos(lat) * sin(lon)
            ..[k * 3 + 2] = sin(lat);
        }
        contorni.add(punti);
      }
      paesi[codice] = contorni;
    }
    return Confini._(paesi);
  }

  /// I confini dell'app, letti una volta sola, con i puntini della terra già
  /// calcolati: fuori dal filo dell'interfaccia, perché non si fermi.
  static Future<Confini> carica() => _caricati ??= rootBundle
      .load('assets/confini.bin')
      .then((dati) => compute(_conIPuntini, dati));
  static Confini _conIPuntini(ByteData dati) =>
      Confini.daByte(dati)..puntini.length;
  static Future<Confini>? _caricati;

  /// Per i test: confini già letti, pronti senza aspettare gli asset.
  @visibleForTesting
  static void usa(Confini confini) => _caricati = SynchronousFuture(confini);

  final Map<String, List<Float32List>> _paesi;

  /// I codici dei paesi; `--` sono le terre senza un codice, che si
  /// disegnano e non si grattano.
  Iterable<String> get codici => _paesi.keys;

  /// I contorni di un paese. Vuoto per i paesi troppo piccoli per il globo
  /// (il Vaticano, Monaco) e per quelli che stanno dentro un altro (la
  /// Martinica, in Francia): lì il mappamondo mette un punto.
  List<Float32List> contorni(String codice) => _paesi[codice] ?? const [];

  /// La terra a puntini, per il mappamondo (tela, 144): punti sparsi in modo
  /// uguale su tutta la sfera, tenuti quelli che cadono dentro un paese.
  late final Puntini puntini = Puntini._di(this, quanti: 12000);

  /// Tutti i contorni in gradi, con il paese di ciascuno.
  late final List<(String, _Contorno)> _inGradi = [
    for (final codice in codici)
      for (final c in contorni(codice)) (codice, _Contorno(c)),
  ];

  /// Il paese che sta in [lat], [lon]: quello di cui il punto sta dentro un
  /// numero dispari di contorni (un lago, o un paese dentro un altro, sono
  /// buchi). `null` sul mare.
  String? paeseIn(double lat, double lon) {
    final dentro = <String, int>{};
    for (final (codice, c) in _inGradi) {
      if (c.contiene(lon, lat)) dentro[codice] = (dentro[codice] ?? 0) + 1;
    }
    return dentro.entries.where((e) => e.value.isOdd).firstOrNull?.key;
  }
}

/// I puntini della terra: dove stanno sulla sfera (x, y, z di seguito) e di
/// che paese sono.
class Puntini {
  Puntini._(this.punti, this._paese, this._codici);

  /// Su [quanti] punti della spirale di Fibonacci, quelli di terra.
  factory Puntini._di(Confini confini, {required int quanti}) {
    final codici = confini.codici.toList();
    final indici = {for (final (i, c) in codici.indexed) c: i};
    final punti = <double>[];
    final paese = <int>[];
    final oro = pi * (3 - sqrt(5));
    for (var k = 0; k < quanti; k++) {
      final z = 1 - (k + 0.5) * 2 / quanti;
      var lon = (k * oro) % (2 * pi) * 180 / pi;
      if (lon > 180) lon -= 360;
      final di = confini.paeseIn(asin(z) * 180 / pi, lon);
      if (di == null) continue;
      final r = sqrt(1 - z * z);
      punti.addAll([r * cos(lon * pi / 180), r * sin(lon * pi / 180), z]);
      paese.add(indici[di]!);
    }
    return Puntini._(
      Float32List.fromList(punti),
      Uint16List.fromList(paese),
      codici,
    );
  }

  final Float32List punti;
  final Uint16List _paese;
  final List<String> _codici;

  int get length => _paese.length;

  /// Il paese del puntino [i].
  String paese(int i) => _codici[_paese[i]];
}

/// Un contorno in gradi, con il suo riquadro, per dire se un punto ci sta
/// dentro. Quelli a cavallo dei 180° si spostano tutti a est.
class _Contorno {
  _Contorno(Float32List punti)
    : _lon = Float32List(punti.length ~/ 3),
      _lat = Float32List(punti.length ~/ 3) {
    for (var i = 0; i < _lon.length; i++) {
      final (x, y, z) = (punti[i * 3], punti[i * 3 + 1], punti[i * 3 + 2]);
      _lon[i] = atan2(y, x) * 180 / pi;
      _lat[i] = asin(z.clamp(-1.0, 1.0)) * 180 / pi;
    }
    var (lo0, lo1) = (double.infinity, -double.infinity);
    for (final l in _lon) {
      lo0 = min(lo0, l);
      lo1 = max(lo1, l);
    }
    if (lo1 - lo0 > 180) {
      for (var i = 0; i < _lon.length; i++) {
        if (_lon[i] < 0) _lon[i] += 360;
      }
    }
    var (ovest, est, sud, nord) = (
      double.infinity,
      -double.infinity,
      double.infinity,
      -double.infinity,
    );
    for (var i = 0; i < _lon.length; i++) {
      ovest = min(ovest, _lon[i]);
      est = max(est, _lon[i]);
      sud = min(sud, _lat[i]);
      nord = max(nord, _lat[i]);
    }
    _ovest = ovest;
    _est = est;
    _sud = sud;
    _nord = nord;
  }

  final Float32List _lon;
  final Float32List _lat;
  late double _ovest, _est, _sud, _nord;

  bool contiene(double lon, double lat) {
    if (lat < _sud || lat > _nord) return false;
    for (final x in [lon, lon + 360]) {
      if (x < _ovest || x > _est) continue;
      var dentro = false;
      for (var i = 0, j = _lon.length - 1; i < _lon.length; j = i++) {
        final (xi, yi, xj, yj) = (_lon[i], _lat[i], _lon[j], _lat[j]);
        if ((yi > lat) != (yj > lat) &&
            x < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
          dentro = !dentro;
        }
      }
      if (dentro) return true;
    }
    return false;
  }
}
