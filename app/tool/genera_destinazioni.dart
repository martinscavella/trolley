/// Rigenera l'elenco incorporato delle destinazioni (ADR-005).
///
///     cd app && dart run tool/genera_destinazioni.dart
///
/// Scarica le fonti in `build/destinazioni/` se non ci sono già (per
/// riscaricarle basta cancellare la cartella) e scrive:
///
/// - `assets/destinazioni.tsv`: paesi e città per la ricerca, anche senza rete;
/// - `lib/dati/paesi.dart`: i nomi dei paesi, per scriverli senza caricare
///   l'elenco.
///
/// Le fonti non chiedono attribuzione:
///
/// - Natural Earth, pubblico dominio: i paesi e settemila città del mondo, con
///   i nomi in italiano. Versione fissata, così rigenerare dà lo stesso elenco;
/// - Wikidata, CC0: i comuni italiani, che Natural Earth copre solo in parte
///   (ha Firenze, non Matera né Positano).
library;

import 'dart:convert';
import 'dart:io';

import 'package:trolley/dominio/testo.dart';

const _naturalEarth =
    'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson';

/// Nomi più usati di quelli di Natural Earth.
const _nomiPreferiti = {
  'US': 'Stati Uniti',
  'JE': 'Jersey',
  'SZ': 'Eswatini',
  'MM': 'Myanmar',
};

/// I codici che Natural Earth tiene dentro un altro paese (i dipartimenti
/// francesi d'oltremare, per esempio) ma che hanno città proprie.
const _paesiMancanti = {
  'BQ': 'Caraibi olandesi',
  'BV': 'Isola Bouvet',
  'CC': 'Isole Cocos',
  'CX': 'Isola di Natale',
  'GF': 'Guyana francese',
  'GP': 'Guadalupa',
  'MQ': 'Martinica',
  'RE': 'Riunione',
  'SJ': 'Svalbard e Jan Mayen',
  'TK': 'Tokelau',
  'YT': 'Mayotte',
};

/// Come si chiamano i paesi quando non si usa il nome ufficiale.
const _altriNomi = {
  'GB': [
    'Inghilterra',
    'Scozia',
    'Galles',
    'Irlanda del Nord',
    'Gran Bretagna',
    'UK',
  ],
  'US': ['USA', 'America', "Stati Uniti d'America"],
  'NL': ['Olanda'],
  'AE': ['Emirati'],
  'CZ': ['Cechia'],
  'MM': ['Birmania'],
  'KR': ['Corea'],
  'VA': ['Vaticano'],
  'MC': ['Monaco'],
  'BA': ['Bosnia'],
  'ZA': ['Sud Africa'],
  'SZ': ['Swaziland'],
  'MK': ['Macedonia'],
  'TR': ['Türkiye'],
};

const _comuni = '''
SELECT ?comune ?nome ?coord ?pop WHERE {
  ?comune wdt:P31 wd:Q747074 ;
          wdt:P625 ?coord ;
          rdfs:label ?nome .
  FILTER(LANG(?nome) = "it")
  FILTER NOT EXISTS { ?comune wdt:P576 ?fine . }
  OPTIONAL { ?comune wdt:P1082 ?pop . }
}''';

/// La sigla della provincia: serve solo a distinguere i comuni omonimi.
const _sigle = '''
SELECT ?comune ?sigla WHERE {
  ?comune wdt:P31 wd:Q747074 ;
          wdt:P131 ?prov .
  FILTER NOT EXISTS { ?comune wdt:P576 ?fine . }
  ?prov wdt:P395 ?sigla .
}''';

Future<void> main() async {
  final cartella = Directory('build/destinazioni')..createSync(recursive: true);
  final citta = await _geojson(
    cartella,
    'citta.geojson',
    '$_naturalEarth/ne_10m_populated_places.geojson',
  );
  final confini = await _geojson(
    cartella,
    'paesi.geojson',
    '$_naturalEarth/ne_10m_admin_0_countries.geojson',
  );
  final comuni = await _wikidata(cartella, 'comuni.json', _comuni);
  final sigle = await _wikidata(cartella, 'sigle.json', _sigle);

  final paesi = _paesi(confini);
  final voci = [
    ...paesi.values,
    ..._cittaDelMondo(citta, paesi),
    ..._comuniItaliani(comuni, sigle, _nomiInglesiItaliani(citta)),
  ];

  // I paesi prima, poi le città dalla più popolosa: la ricerca, a parità di
  // corrispondenza, tiene quest'ordine.
  voci.sort((a, b) {
    if (a.tipo != b.tipo) return a.tipo == 'P' ? -1 : 1;
    return b.popolazione.compareTo(a.popolazione);
  });

  final oggi = DateTime.now().toIso8601String().substring(0, 10);
  final tsv = StringBuffer()
    ..writeln(
      '# Generato il $oggi da tool/genera_destinazioni.dart: non modificare a mano.',
    )
    ..writeln('# Fonti: Natural Earth (pubblico dominio), Wikidata (CC0).')
    ..writeln(
      '# tipo\tnome\tpaese\tlat\tlon\tpopolazione\tdettaglio\taltri nomi'
      '\tcontinente',
    );
  for (final v in voci) {
    tsv.writeln(v.riga);
  }
  File('assets/destinazioni.tsv')
    ..createSync(recursive: true)
    ..writeAsStringSync(tsv.toString());

  final dart = StringBuffer()
    ..writeln(
      '// Generato da tool/genera_destinazioni.dart: non modificare a mano.',
    )
    ..writeln()
    ..writeln('/// I nomi dei paesi in italiano, dal codice ISO a due lettere.')
    ..writeln('const nomiDeiPaesi = <String, String>{');
  for (final codice in paesi.keys.toList()..sort()) {
    dart.writeln("  '$codice': ${_letterale(paesi[codice]!.nome)},");
  }
  dart.writeln('};');
  File('lib/dati/paesi.dart').writeAsStringSync(dart.toString());

  final quanteCitta = voci.where((v) => v.tipo == 'C').length;
  stdout.writeln(
    '${paesi.length} paesi e $quanteCitta città, '
    '${(tsv.length / 1024).round()} KB',
  );
}

class _Voce {
  _Voce({
    required this.tipo,
    required this.nome,
    required this.paese,
    required this.lat,
    required this.lon,
    required this.popolazione,
    this.dettaglio = '',
    this.continente = '',
    Iterable<String> altriNomi = const [],
  }) {
    final visti = {normalizza(nome)};
    for (final altro in altriNomi) {
      final pulito = altro.trim();
      if (pulito.isNotEmpty && visti.add(normalizza(pulito))) {
        this.altriNomi.add(pulito);
      }
    }
  }

  /// `P` un paese, `C` una città.
  final String tipo;
  final String nome;
  final String paese;
  final double? lat;
  final double? lon;
  final int popolazione;
  String dettaglio;

  /// Solo per i paesi: `EU` per l'Europa. Serve alla ricerca, che mette prima
  /// le mete più vicine.
  final String continente;
  final altriNomi = <String>[];

  /// Una riga del file. Gli altri nomi sono separati da `|`, l'unico posto
  /// dove il carattere resta.
  String get riga => [
    for (final campo in [
      tipo,
      nome,
      paese,
      lat?.toStringAsFixed(3) ?? '',
      lon?.toStringAsFixed(3) ?? '',
      '$popolazione',
      dettaglio,
    ])
      _pulito(campo),
    altriNomi.map(_pulito).join('|'),
    continente,
  ].join('\t');

  static String _pulito(String campo) =>
      campo.replaceAll(RegExp(r'[\t\n\r|]'), ' ').trim();
}

Map<String, _Voce> _paesi(Map<String, dynamic> confini) {
  // Natural Earth dà più righe per alcuni codici (l'Australia e i suoi
  // territori): vale quella del paese.
  const rango = {'Sovereign country': 0, 'Country': 1, 'Sovereignty': 2};
  final migliori = <String, Map<String, dynamic>>{};
  for (final f in confini['features'] as List) {
    final p = (f as Map)['properties'] as Map<String, dynamic>;
    final codice = p['ISO_A2_EH'] as String;
    if (codice == '-99') continue;
    final attuale = migliori[codice];
    if (attuale == null ||
        (rango[p['TYPE']] ?? 9) < (rango[attuale['TYPE']] ?? 9)) {
      migliori[codice] = p;
    }
  }
  final paesi = <String, _Voce>{
    for (final MapEntry(key: codice, value: p) in migliori.entries)
      codice: _Voce(
        tipo: 'P',
        nome: _nomiPreferiti[codice] ?? p['NAME_IT'] as String,
        paese: codice,
        lat: (p['LABEL_Y'] as num?)?.toDouble(),
        lon: (p['LABEL_X'] as num?)?.toDouble(),
        popolazione: (p['POP_EST'] as num?)?.round() ?? 0,
        continente: p['CONTINENT'] == 'Europe' ? 'EU' : '',
        altriNomi: [
          if (_nomiPreferiti.containsKey(codice)) p['NAME_IT'] as String,
          ..._altriNomi[codice] ?? const [],
          p['NAME'] as String,
          p['NAME_LONG'] as String,
          p['NAME_EN'] as String,
        ],
      ),
  };
  for (final MapEntry(key: codice, value: nome) in _paesiMancanti.entries) {
    paesi.putIfAbsent(
      codice,
      () => _Voce(
        tipo: 'P',
        nome: nome,
        paese: codice,
        lat: null,
        lon: null,
        popolazione: 0,
      ),
    );
  }
  return paesi;
}

List<_Voce> _cittaDelMondo(
  Map<String, dynamic> citta,
  Map<String, _Voce> paesi,
) => [
  for (final f in citta['features'] as List)
    if ((f as Map)['properties'] case final Map<String, dynamic> p
        // L'Italia la danno i comuni, più completi.
        when p['ISO_A2'] != 'IT' &&
            paesi.containsKey(p['ISO_A2']) &&
            !_cittaStato(p, paesi[p['ISO_A2']]!))
      _Voce(
        tipo: 'C',
        nome: (p['NAME_IT'] as String?) ?? p['NAME'] as String,
        paese: p['ISO_A2'] as String,
        lat: (p['LATITUDE'] as num).toDouble(),
        lon: (p['LONGITUDE'] as num).toDouble(),
        popolazione: (p['POP_MAX'] as num?)?.round() ?? 0,
        dettaglio: (p['ADM1NAME'] as String?) ?? '',
        altriNomi: [
          p['NAME'] as String,
          ?p['NAMEASCII'] as String?,
          ?p['NAME_EN'] as String?,
          ...((p['NAMEALT'] as String?) ?? '').split('|'),
        ],
      ),
];

/// Monaco, il Vaticano, Singapore: la città è il paese, e comparirebbe due
/// volte con lo stesso nome.
bool _cittaStato(Map<String, dynamic> citta, _Voce paese) =>
    normalizza((citta['NAME_IT'] as String?) ?? citta['NAME'] as String) ==
        normalizza(paese.nome) &&
    ((citta['POP_MAX'] as num?) ?? 0) * 2 >= paese.popolazione;

/// Le città italiane di Natural Earth portano il nome inglese (Florence,
/// Venice, Turin): si aggiunge ai comuni, che da Wikidata hanno solo quello
/// italiano.
Map<String, List<String>> _nomiInglesiItaliani(Map<String, dynamic> citta) => {
  for (final f in citta['features'] as List)
    if ((f as Map)['properties'] case final Map<String, dynamic> p
        when p['ISO_A2'] == 'IT')
      normalizza((p['NAME_IT'] as String?) ?? p['NAME'] as String): [
        p['NAME'] as String,
        ?p['NAME_EN'] as String?,
        ...((p['NAMEALT'] as String?) ?? '').split('|'),
      ],
};

List<_Voce> _comuniItaliani(
  Map<String, dynamic> comuni,
  Map<String, dynamic> sigle,
  Map<String, List<String>> nomiInglesi,
) {
  // Una riga per ogni combinazione di valori: si raccolgono per comune.
  final perComune = <String, _Voce>{};
  for (final r in _righe(comuni)) {
    final id = r['comune']!;
    final punto = RegExp(r'Point\(([-\d.]+) ([-\d.]+)\)')
        .firstMatch(r['coord']!);
    if (punto == null) continue;
    final popolazione = double.tryParse(r['pop'] ?? '')?.round() ?? 0;
    final attuale = perComune[id];
    if (attuale != null && attuale.popolazione >= popolazione) continue;
    perComune[id] = _Voce(
      tipo: 'C',
      nome: r['nome']!,
      paese: 'IT',
      lat: attuale?.lat ?? double.parse(punto[2]!),
      lon: attuale?.lon ?? double.parse(punto[1]!),
      popolazione: popolazione,
      altriNomi: nomiInglesi[normalizza(r['nome']!)] ?? const [],
    );
  }

  // I comuni che si chiamano allo stesso modo (Samone in Piemonte e in
  // Trentino) si distinguono con la sigla della provincia.
  final siglaDi = <String, String>{};
  for (final r in _righe(sigle)) {
    final sigla = r['sigla']!.replaceFirst('IT-', '');
    if (RegExp(r'^[A-Z]{2}$').hasMatch(sigla)) siglaDi[r['comune']!] = sigla;
  }
  final perNome = <String, List<String>>{};
  perComune.forEach((id, v) => (perNome[normalizza(v.nome)] ??= []).add(id));
  for (final omonimi in perNome.values.where((ids) => ids.length > 1)) {
    for (final id in omonimi) {
      perComune[id]!.dettaglio = siglaDi[id] ?? '';
    }
  }
  return perComune.values.toList();
}

Iterable<Map<String, String>> _righe(Map<String, dynamic> risposta) sync* {
  for (final b in (risposta['results'] as Map)['bindings'] as List) {
    yield {
      for (final MapEntry(:key, :value) in (b as Map<String, dynamic>).entries)
        key: (value as Map)['value'] as String,
    };
  }
}

Future<Map<String, dynamic>> _geojson(
  Directory cartella,
  String nome,
  String url,
) async {
  final file = File('${cartella.path}/$nome');
  if (!file.existsSync()) {
    stdout.writeln('Scarico $url');
    await file.writeAsBytes(await _scarica(Uri.parse(url)));
  }
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _wikidata(
  Directory cartella,
  String nome,
  String query,
) async {
  final file = File('${cartella.path}/$nome');
  if (!file.existsSync()) {
    stdout.writeln('Interrogo Wikidata ($nome)');
    await file.writeAsBytes(
      await _scarica(
        Uri.https('query.wikidata.org', '/sparql', {'query': query}),
        intestazioni: {'Accept': 'application/sparql-results+json'},
      ),
    );
  }
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

Future<List<int>> _scarica(
  Uri url, {
  Map<String, String> intestazioni = const {},
}) async {
  final client = HttpClient()..userAgent = 'TrolleyDestinazioni/1.0';
  try {
    final richiesta = await client.getUrl(url);
    intestazioni.forEach(richiesta.headers.set);
    final risposta = await richiesta.close();
    if (risposta.statusCode != 200) {
      throw HttpException('${risposta.statusCode} da $url');
    }
    return [for (final pezzo in await risposta.toList()) ...pezzo];
  } finally {
    client.close();
  }
}

String _letterale(String testo) =>
    "'${testo.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
