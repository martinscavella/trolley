/// I confini dei paesi per il mappamondo (ADR-005): incorporati nell'app come
/// l'elenco delle destinazioni, così il mappamondo funziona senza rete e non
/// dipende da nessun fornitore. Li scrive `tool/genera_confini.dart`, che
/// descrive il file.
library;

import 'dart:math';

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

  /// I confini dell'app, letti una volta sola.
  static Future<Confini> carica() =>
      _caricati ??= rootBundle.load('assets/confini.bin').then(Confini.daByte);
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
}
