/// Rigenera i confini dei paesi per il mappamondo (ADR-005).
///
///     cd app && dart run tool/genera_confini.dart
///
/// Legge i paesi di Natural Earth (pubblico dominio), gli stessi da cui
/// `tool/genera_destinazioni.dart` prende i nomi e i codici, e scrive
/// `assets/confini.bin`: per ogni paese i suoi contorni, semplificati per un
/// globo grande quanto lo schermo di un telefono. Natural Earth tiene i
/// territori d'oltremare dentro il loro stato (la Guyana dentro la Francia):
/// quelli che l'elenco ha come paesi si prendono dalle sue «map units», e si
/// tolgono dallo stato, così chi va a Parigi non gratta il Sudamerica.
/// Scarica le fonti in `build/destinazioni/` se non ci sono già.
///
/// Il file, tutto little-endian:
///
/// - `u16` quanti paesi;
/// - per ogni paese: il codice ISO in due byte ASCII (`--` per le terre senza
///   un codice, come Cipro del Nord: si disegnano, non si grattano), `u16`
///   quanti contorni; per ogni contorno `u16` quanti punti, poi i punti come
///   coppie `i16` di longitudine e latitudine in centesimi di grado.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:trolley/dati/paesi.dart';

const _naturalEarth =
    'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson';

/// Quanto si può spostare un contorno semplificandolo, in gradi: un globo di
/// 300 punti sullo schermo ha un punto ogni 40 km, questo è poco più di 10.
const _tolleranza = 0.1;

/// Le isole più piccole di così (in gradi quadrati, circa 100 km²) si
/// lasciano: sul globo sarebbero meno di un punto. Il contorno più grande di
/// un paese resta sempre, anche se piccolo.
const _areaMinima = 0.01;

/// Il lato più lungo di un contorno, in gradi: sul globo un lato è una linea
/// dritta, e un confine lungo un parallelo deve restare curvo.
const _latoMassimo = 2.0;

/// Un contorno, con lo stato a cui appartiene.
typedef _Anello = ({String codice, String stato, List<List<double>> punti});

Future<void> main() async {
  final paesi = await _anelli(
    'paesi.geojson',
    '$_naturalEarth/ne_10m_admin_0_countries.geojson',
  );
  final unita = await _anelli(
    'unita.geojson',
    '$_naturalEarth/ne_10m_admin_0_map_units.geojson',
  );

  final codici = {for (final a in paesi) a.codice};
  final territori = [
    for (final a in unita)
      if (!codici.contains(a.codice) && nomiDeiPaesi.containsKey(a.codice)) a,
  ];
  // Un contorno dello stato che sta dentro un territorio è del territorio.
  bool delTerritorio(_Anello a) {
    final centro = _centro(a.punti);
    return territori.any((t) => t.stato == a.stato && _dentro(centro, t.punti));
  }

  // Più righe per lo stesso codice (l'Australia e i suoi isolotti) diventano
  // un paese solo.
  final perCodice = <String, List<List<List<double>>>>{};
  for (final a in [
    for (final a in paesi)
      if (!delTerritorio(a)) a,
    ...territori,
  ]) {
    perCodice.putIfAbsent(a.codice, () => []).add(a.punti);
  }

  final dati = BytesBuilder();
  void u16(int n) {
    if (n > 0xFFFF) throw StateError('$n non sta in 16 bit');
    dati.add(
      (ByteData(2)..setUint16(0, n, Endian.little)).buffer.asUint8List(),
    );
  }

  void i16(double gradi) => dati.add(
    (ByteData(
      2,
    )..setInt16(0, (gradi * 100).round(), Endian.little)).buffer.asUint8List(),
  );

  var punti = 0;
  final ordinati = perCodice.keys.toList()..sort();
  u16(ordinati.length);
  for (final codice in ordinati) {
    final originali = perCodice[codice]!;
    final piuGrande = originali.reduce(
      (a, b) => _area(a).abs() >= _area(b).abs() ? a : b,
    );
    final tenuti = [
      for (final anello in originali)
        if (identical(anello, piuGrande) || _area(anello).abs() >= _areaMinima)
          _infittisci(_semplifica(anello)),
    ].where((a) => a.length >= 4).toList();
    dati.add(ascii.encode(codice));
    u16(tenuti.length);
    for (final anello in tenuti) {
      u16(anello.length);
      for (final [lon, lat] in anello) {
        i16(lon);
        i16(lat);
      }
      punti += anello.length;
    }
  }

  final uscita = File('assets/confini.bin')..writeAsBytesSync(dati.takeBytes());
  stdout.writeln(
    '${ordinati.length} paesi (${territori.map((t) => t.codice).toSet().length} '
    'territori), $punti punti, '
    '${(uscita.lengthSync() / 1024).round()} KB',
  );
}

/// I contorni di un file di Natural Earth, scaricato se non c'è.
Future<List<_Anello>> _anelli(String nome, String url) async {
  final file = File('build/destinazioni/$nome');
  if (!file.existsSync()) {
    file.parent.createSync(recursive: true);
    stdout.writeln('Scarico $url');
    await file.writeAsBytes(await _scarica(Uri.parse(url)));
  }
  final geojson = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  return [
    for (final f in geojson['features'] as List)
      if ((f as Map)['properties'] case final Map<String, dynamic> p)
        for (final poligono in switch ((f['geometry'] as Map)['type']) {
          'Polygon' => [f['geometry']['coordinates'] as List],
          'MultiPolygon' => f['geometry']['coordinates'] as List,
          _ => const <List>[],
        })
          for (final anello in poligono as List)
            (
              codice: p['ISO_A2_EH'] == '-99' ? '--' : p['ISO_A2_EH'] as String,
              stato: p['ADMIN'] as String,
              punti: [
                for (final punto in anello as List)
                  [
                    ((punto as List)[0] as num).toDouble(),
                    (punto[1] as num).toDouble(),
                  ],
              ],
            ),
  ];
}

List<double> _centro(List<List<double>> punti) => [
  punti.map((p) => p[0]).reduce((a, b) => a + b) / punti.length,
  punti.map((p) => p[1]).reduce((a, b) => a + b) / punti.length,
];

/// Se [punto] sta nel rettangolo che contiene [punti], con un margine.
bool _dentro(List<double> punto, List<List<double>> punti) {
  const margine = 0.05;
  final lon = punti.map((p) => p[0]);
  final lat = punti.map((p) => p[1]);
  return punto[0] >= lon.reduce(min) - margine &&
      punto[0] <= lon.reduce(max) + margine &&
      punto[1] >= lat.reduce(min) - margine &&
      punto[1] <= lat.reduce(max) + margine;
}

/// L'area con il segno, in gradi quadrati: basta per scegliere le isole.
double _area(List<List<double>> anello) {
  var a = 0.0;
  for (var i = 0; i < anello.length - 1; i++) {
    a += anello[i][0] * anello[i + 1][1] - anello[i + 1][0] * anello[i][1];
  }
  return a / 2;
}

/// Douglas-Peucker su un contorno chiuso: si divide nel punto più lontano
/// dal primo, e si semplificano le due metà.
List<List<double>> _semplifica(List<List<double>> anello) {
  if (anello.length <= 4) return anello;
  final primo = anello.first;
  var lontano = 1;
  var massima = -1.0;
  for (var i = 1; i < anello.length - 1; i++) {
    final d = _distanza(anello[i], primo);
    if (d > massima) {
      massima = d;
      lontano = i;
    }
  }
  final tenuti = List.filled(anello.length, false)
    ..[0] = true
    ..[lontano] = true
    ..[anello.length - 1] = true;
  _tratto(anello, 0, lontano, tenuti);
  _tratto(anello, lontano, anello.length - 1, tenuti);
  return [
    for (var i = 0; i < anello.length; i++)
      if (tenuti[i]) anello[i],
  ];
}

void _tratto(List<List<double>> punti, int da, int a, List<bool> tenuti) {
  if (a - da < 2) return;
  var lontano = -1;
  var massima = _tolleranza;
  for (var i = da + 1; i < a; i++) {
    final d = _dalSegmento(punti[i], punti[da], punti[a]);
    if (d > massima) {
      massima = d;
      lontano = i;
    }
  }
  if (lontano < 0) return;
  tenuti[lontano] = true;
  _tratto(punti, da, lontano, tenuti);
  _tratto(punti, lontano, a, tenuti);
}

double _distanza(List<double> a, List<double> b) =>
    sqrt(pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2));

double _dalSegmento(List<double> p, List<double> a, List<double> b) {
  final dx = b[0] - a[0];
  final dy = b[1] - a[1];
  final lunghezza = dx * dx + dy * dy;
  if (lunghezza == 0) return _distanza(p, a);
  final t = (((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / lunghezza).clamp(
    0.0,
    1.0,
  );
  return _distanza(p, [a[0] + t * dx, a[1] + t * dy]);
}

/// Aggiunge punti ai lati più lunghi di [_latoMassimo].
List<List<double>> _infittisci(List<List<double>> anello) => [
  for (var i = 0; i < anello.length; i++) ...[
    if (i > 0)
      for (
        var k = 1,
            n = (_distanza(anello[i - 1], anello[i]) / _latoMassimo).ceil();
        k < n;
        k++
      )
        [
          anello[i - 1][0] + (anello[i][0] - anello[i - 1][0]) * k / n,
          anello[i - 1][1] + (anello[i][1] - anello[i - 1][1]) * k / n,
        ],
    anello[i],
  ],
];

Future<List<int>> _scarica(Uri url) async {
  final client = HttpClient()..userAgent = 'TrolleyConfini/1.0';
  try {
    final risposta = await (await client.getUrl(url)).close();
    if (risposta.statusCode != 200) {
      throw HttpException('${risposta.statusCode} da $url');
    }
    return [for (final pezzo in await risposta.toList()) ...pezzo];
  } finally {
    client.close();
  }
}
