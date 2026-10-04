/// Valute, importi e conversioni (06-spese.md).
///
/// Un importo è un numero intero di centesimi: il server tiene due decimali
/// (`numeric(12, 2)`) per ogni valuta, e un `double` sommerebbe male. Il
/// valore pagato, nella sua valuta, è il dato vero; la conversione è
/// un'indicazione, fatta con l'ultimo tasso noto, e dice di quando è.
///
/// I tassi sono "quanto vale un euro" in ogni valuta (`tasso_cambio.per_euro`,
/// ADR-009): da A a B si passa per l'euro.
library;

import 'testo.dart';

/// Una valuta: il codice ISO 4217, il nome in italiano, quante cifre dopo la
/// virgola si scrivono (lo yen nessuna).
class Valuta {
  const Valuta(this.codice, this.nome, {this.decimali = 2});

  final String codice;
  final String nome;
  final int decimali;
}

/// La valuta di chi non ne ha ancora scelta una (06, regola 4).
const valutaIniziale = 'EUR';

/// Le valute in corso, per nome. Quelle senza tasso si possono usare lo
/// stesso: la spesa resta nella sua valuta, e la conversione non c'è.
const valute = <Valuta>[
  Valuta('AED', 'Dirham degli Emirati'),
  Valuta('AFN', 'Afghani afghano'),
  Valuta('ALL', 'Lek albanese'),
  Valuta('AMD', 'Dram armeno'),
  Valuta('ANG', 'Fiorino delle Antille olandesi'),
  Valuta('AOA', 'Kwanza angolano'),
  Valuta('ARS', 'Peso argentino'),
  Valuta('AUD', 'Dollaro australiano'),
  Valuta('AWG', 'Fiorino di Aruba'),
  Valuta('AZN', 'Manat azero'),
  Valuta('BAM', 'Marco bosniaco'),
  Valuta('BBD', 'Dollaro di Barbados'),
  Valuta('BDT', 'Taka bengalese'),
  Valuta('BGN', 'Lev bulgaro'),
  Valuta('BHD', 'Dinaro del Bahrein'),
  Valuta('BIF', 'Franco del Burundi', decimali: 0),
  Valuta('BMD', 'Dollaro delle Bermuda'),
  Valuta('BND', 'Dollaro del Brunei'),
  Valuta('BOB', 'Boliviano'),
  Valuta('BRL', 'Real brasiliano'),
  Valuta('BSD', 'Dollaro delle Bahamas'),
  Valuta('BTN', 'Ngultrum del Bhutan'),
  Valuta('BWP', 'Pula del Botswana'),
  Valuta('BYN', 'Rublo bielorusso'),
  Valuta('BZD', 'Dollaro del Belize'),
  Valuta('CAD', 'Dollaro canadese'),
  Valuta('CDF', 'Franco congolese'),
  Valuta('CHF', 'Franco svizzero'),
  Valuta('CLP', 'Peso cileno', decimali: 0),
  Valuta('CNY', 'Yuan cinese'),
  Valuta('COP', 'Peso colombiano'),
  Valuta('CRC', 'Colón costaricano'),
  Valuta('CUP', 'Peso cubano'),
  Valuta('CVE', 'Escudo capoverdiano'),
  Valuta('CZK', 'Corona ceca'),
  Valuta('DJF', 'Franco di Gibuti', decimali: 0),
  Valuta('DKK', 'Corona danese'),
  Valuta('DOP', 'Peso dominicano'),
  Valuta('DZD', 'Dinaro algerino'),
  Valuta('EGP', 'Sterlina egiziana'),
  Valuta('ERN', 'Nakfa eritreo'),
  Valuta('ETB', 'Birr etiope'),
  Valuta('EUR', 'Euro'),
  Valuta('FJD', 'Dollaro delle Figi'),
  Valuta('FKP', 'Sterlina delle Falkland'),
  Valuta('GBP', 'Sterlina britannica'),
  Valuta('GEL', 'Lari georgiano'),
  Valuta('GHS', 'Cedi ghanese'),
  Valuta('GIP', 'Sterlina di Gibilterra'),
  Valuta('GMD', 'Dalasi gambiano'),
  Valuta('GNF', 'Franco guineano', decimali: 0),
  Valuta('GTQ', 'Quetzal guatemalteco'),
  Valuta('GYD', 'Dollaro della Guyana'),
  Valuta('HKD', 'Dollaro di Hong Kong'),
  Valuta('HNL', 'Lempira honduregna'),
  Valuta('HTG', 'Gourde haitiano'),
  Valuta('HUF', 'Fiorino ungherese'),
  Valuta('IDR', 'Rupia indonesiana'),
  Valuta('ILS', 'Nuovo siclo israeliano'),
  Valuta('INR', 'Rupia indiana'),
  Valuta('IQD', 'Dinaro iracheno'),
  Valuta('IRR', 'Rial iraniano'),
  Valuta('ISK', 'Corona islandese', decimali: 0),
  Valuta('JMD', 'Dollaro giamaicano'),
  Valuta('JOD', 'Dinaro giordano'),
  Valuta('JPY', 'Yen giapponese', decimali: 0),
  Valuta('KES', 'Scellino keniota'),
  Valuta('KGS', 'Som kirghiso'),
  Valuta('KHR', 'Riel cambogiano'),
  Valuta('KMF', 'Franco delle Comore', decimali: 0),
  Valuta('KRW', 'Won sudcoreano', decimali: 0),
  Valuta('KWD', 'Dinaro kuwaitiano'),
  Valuta('KYD', 'Dollaro delle Cayman'),
  Valuta('KZT', 'Tenge kazako'),
  Valuta('LAK', 'Kip laotiano'),
  Valuta('LBP', 'Lira libanese'),
  Valuta('LKR', 'Rupia singalese'),
  Valuta('LRD', 'Dollaro liberiano'),
  Valuta('LSL', 'Loti del Lesotho'),
  Valuta('LYD', 'Dinaro libico'),
  Valuta('MAD', 'Dirham marocchino'),
  Valuta('MDL', 'Leu moldavo'),
  Valuta('MGA', 'Ariary malgascio'),
  Valuta('MKD', 'Denar macedone'),
  Valuta('MMK', 'Kyat birmano'),
  Valuta('MNT', 'Tugrik mongolo'),
  Valuta('MOP', 'Pataca di Macao'),
  Valuta('MRU', 'Ouguiya mauritana'),
  Valuta('MUR', 'Rupia mauriziana'),
  Valuta('MVR', 'Rufiyaa delle Maldive'),
  Valuta('MWK', 'Kwacha malawiano'),
  Valuta('MXN', 'Peso messicano'),
  Valuta('MYR', 'Ringgit malese'),
  Valuta('MZN', 'Metical mozambicano'),
  Valuta('NAD', 'Dollaro namibiano'),
  Valuta('NGN', 'Naira nigeriana'),
  Valuta('NIO', 'Córdoba nicaraguense'),
  Valuta('NOK', 'Corona norvegese'),
  Valuta('NPR', 'Rupia nepalese'),
  Valuta('NZD', 'Dollaro neozelandese'),
  Valuta('OMR', 'Rial dell\'Oman'),
  Valuta('PAB', 'Balboa panamense'),
  Valuta('PEN', 'Sol peruviano'),
  Valuta('PGK', 'Kina della Papua Nuova Guinea'),
  Valuta('PHP', 'Peso filippino'),
  Valuta('PKR', 'Rupia pakistana'),
  Valuta('PLN', 'Złoty polacco'),
  Valuta('PYG', 'Guaraní paraguaiano', decimali: 0),
  Valuta('QAR', 'Riyal del Qatar'),
  Valuta('RON', 'Leu rumeno'),
  Valuta('RSD', 'Dinaro serbo'),
  Valuta('RUB', 'Rublo russo'),
  Valuta('RWF', 'Franco ruandese', decimali: 0),
  Valuta('SAR', 'Riyal saudita'),
  Valuta('SBD', 'Dollaro delle Salomone'),
  Valuta('SCR', 'Rupia delle Seychelles'),
  Valuta('SDG', 'Sterlina sudanese'),
  Valuta('SEK', 'Corona svedese'),
  Valuta('SGD', 'Dollaro di Singapore'),
  Valuta('SLE', 'Leone della Sierra Leone'),
  Valuta('SOS', 'Scellino somalo'),
  Valuta('SRD', 'Dollaro del Suriname'),
  Valuta('STN', 'Dobra di São Tomé'),
  Valuta('SYP', 'Lira siriana'),
  Valuta('SZL', 'Lilangeni dello Eswatini'),
  Valuta('THB', 'Baht thailandese'),
  Valuta('TJS', 'Somoni tagiko'),
  Valuta('TMT', 'Manat turkmeno'),
  Valuta('TND', 'Dinaro tunisino'),
  Valuta('TOP', 'Paʻanga tongano'),
  Valuta('TRY', 'Lira turca'),
  Valuta('TTD', 'Dollaro di Trinidad e Tobago'),
  Valuta('TWD', 'Dollaro taiwanese'),
  Valuta('TZS', 'Scellino tanzaniano'),
  Valuta('UAH', 'Grivnia ucraina'),
  Valuta('UGX', 'Scellino ugandese', decimali: 0),
  Valuta('USD', 'Dollaro statunitense'),
  Valuta('UYU', 'Peso uruguaiano'),
  Valuta('UZS', 'Som uzbeko'),
  Valuta('VES', 'Bolívar venezuelano'),
  Valuta('VND', 'Dong vietnamita', decimali: 0),
  Valuta('VUV', 'Vatu di Vanuatu', decimali: 0),
  Valuta('WST', 'Tala samoano'),
  Valuta('XAF', 'Franco CFA dell\'Africa centrale', decimali: 0),
  Valuta('XCD', 'Dollaro dei Caraibi orientali'),
  Valuta('XOF', 'Franco CFA dell\'Africa occidentale', decimali: 0),
  Valuta('XPF', 'Franco CFP', decimali: 0),
  Valuta('YER', 'Rial yemenita'),
  Valuta('ZAR', 'Rand sudafricano'),
  Valuta('ZMW', 'Kwacha zambiano'),
];

final _perCodice = {for (final v in valute) v.codice: v};

/// La valuta di un codice. Un codice che l'app non conosce (arrivato dal
/// server, scritto da una versione più nuova) vale con due decimali e il
/// codice come nome: non si perde la spesa per un nome mancante.
Valuta valutaDi(String codice) => _perCodice[codice] ?? Valuta(codice, codice);

/// Un codice è di una valuta che l'app conosce.
bool valutaNota(String codice) => _perCodice.containsKey(codice);

/// Le valute che corrispondono a [cerca], nel codice o nel nome, senza badare
/// ad accenti e maiuscole. Prima quelle il cui codice o nome comincia così.
List<Valuta> cercaValute(String cerca) {
  final q = normalizza(cerca.trim());
  if (q.isEmpty) return valute;
  final inizio = <Valuta>[];
  final dentro = <Valuta>[];
  for (final v in valute) {
    final codice = v.codice.toLowerCase();
    final nome = normalizza(v.nome);
    if (codice.startsWith(q) ||
        nome.startsWith(q) ||
        nome.split(' ').any((p) => p.startsWith(q))) {
      inizio.add(v);
    } else if (nome.contains(q)) {
      dentro.add(v);
    }
  }
  return [...inizio, ...dentro];
}

/// La valuta che si usa in un paese (ISO a due lettere), se si sa.
String? valutaDelPaese(String? paese) => _valutaDelPaese[paese?.toUpperCase()];

const _euro = [
  'AD', 'AT', 'BE', 'BL', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GF', 'GP', //
  'GR', 'HR', 'IE', 'IT', 'LT', 'LU', 'LV', 'MC', 'ME', 'MF', 'MQ', 'MT',
  'NL', 'PM', 'PT', 'RE', 'SI', 'SK', 'SM', 'TF', 'VA', 'XK', 'YT', 'AX',
];
const _dollaro = [
  'US', 'AS', 'BQ', 'EC', 'FM', 'GU', 'IO', 'MH', 'MP', 'PR', 'PW', 'SV', //
  'TC', 'TL', 'UM', 'VG', 'VI',
];
const _xof = ['BF', 'BJ', 'CI', 'GW', 'ML', 'NE', 'SN', 'TG'];
const _xaf = ['CF', 'CG', 'CM', 'GA', 'GQ', 'TD'];
const _xcd = ['AG', 'AI', 'DM', 'GD', 'KN', 'LC', 'MS', 'VC'];
const _aud = ['AU', 'CC', 'CX', 'HM', 'KI', 'NF', 'NR', 'TV'];

final Map<String, String> _valutaDelPaese = {
  for (final p in _euro) p: 'EUR',
  for (final p in _dollaro) p: 'USD',
  for (final p in _xof) p: 'XOF',
  for (final p in _xaf) p: 'XAF',
  for (final p in _xcd) p: 'XCD',
  for (final p in _aud) p: 'AUD',
  'AE': 'AED', 'AF': 'AFN', 'AL': 'ALL', 'AM': 'AMD', 'AO': 'AOA', //
  'AR': 'ARS', 'AW': 'AWG', 'AZ': 'AZN', 'BA': 'BAM', 'BB': 'BBD',
  'BD': 'BDT', 'BG': 'BGN', 'BH': 'BHD', 'BI': 'BIF', 'BM': 'BMD',
  'BN': 'BND', 'BO': 'BOB', 'BR': 'BRL', 'BS': 'BSD', 'BT': 'BTN',
  'BV': 'NOK', 'BW': 'BWP', 'BY': 'BYN', 'BZ': 'BZD', 'CA': 'CAD',
  'CD': 'CDF', 'CH': 'CHF', 'CK': 'NZD', 'CL': 'CLP', 'CN': 'CNY',
  'CO': 'COP', 'CR': 'CRC', 'CU': 'CUP', 'CV': 'CVE', 'CW': 'ANG',
  'CZ': 'CZK', 'DJ': 'DJF', 'DK': 'DKK', 'DO': 'DOP', 'DZ': 'DZD',
  'EG': 'EGP', 'EH': 'MAD', 'ER': 'ERN', 'ET': 'ETB', 'FJ': 'FJD',
  'FK': 'FKP', 'FO': 'DKK', 'GB': 'GBP', 'GE': 'GEL', 'GG': 'GBP',
  'GH': 'GHS', 'GI': 'GIP', 'GL': 'DKK', 'GM': 'GMD', 'GN': 'GNF',
  'GS': 'GBP', 'GT': 'GTQ', 'GY': 'GYD', 'HK': 'HKD', 'HN': 'HNL',
  'HT': 'HTG', 'HU': 'HUF', 'ID': 'IDR', 'IL': 'ILS', 'IM': 'GBP',
  'IN': 'INR', 'IQ': 'IQD', 'IR': 'IRR', 'IS': 'ISK', 'JE': 'GBP',
  'JM': 'JMD', 'JO': 'JOD', 'JP': 'JPY', 'KE': 'KES', 'KG': 'KGS',
  'KH': 'KHR', 'KM': 'KMF', 'KR': 'KRW', 'KW': 'KWD', 'KY': 'KYD',
  'KZ': 'KZT', 'LA': 'LAK', 'LB': 'LBP', 'LI': 'CHF', 'LK': 'LKR',
  'LR': 'LRD', 'LS': 'LSL', 'LY': 'LYD', 'MA': 'MAD', 'MD': 'MDL',
  'MG': 'MGA', 'MK': 'MKD', 'MM': 'MMK', 'MN': 'MNT', 'MO': 'MOP',
  'MR': 'MRU', 'MU': 'MUR', 'MV': 'MVR', 'MW': 'MWK', 'MX': 'MXN',
  'MY': 'MYR', 'MZ': 'MZN', 'NA': 'NAD', 'NC': 'XPF', 'NG': 'NGN',
  'NI': 'NIO', 'NO': 'NOK', 'NP': 'NPR', 'NU': 'NZD', 'NZ': 'NZD',
  'OM': 'OMR', 'PA': 'PAB', 'PE': 'PEN', 'PF': 'XPF', 'PG': 'PGK',
  'PH': 'PHP', 'PK': 'PKR', 'PL': 'PLN', 'PN': 'NZD', 'PS': 'ILS',
  'PY': 'PYG', 'QA': 'QAR', 'RO': 'RON', 'RS': 'RSD', 'RU': 'RUB',
  'RW': 'RWF', 'SA': 'SAR', 'SB': 'SBD', 'SC': 'SCR', 'SD': 'SDG',
  'SE': 'SEK', 'SG': 'SGD', 'SH': 'GBP', 'SJ': 'NOK', 'SL': 'SLE',
  'SO': 'SOS', 'SR': 'SRD', 'SS': 'SDG', 'ST': 'STN', 'SX': 'ANG',
  'SY': 'SYP', 'SZ': 'SZL', 'TH': 'THB', 'TJ': 'TJS', 'TK': 'NZD',
  'TM': 'TMT', 'TN': 'TND', 'TO': 'TOP', 'TR': 'TRY', 'TT': 'TTD',
  'TW': 'TWD', 'TZ': 'TZS', 'UA': 'UAH', 'UG': 'UGX', 'UY': 'UYU',
  'UZ': 'UZS', 'VE': 'VES', 'VN': 'VND', 'VU': 'VUV', 'WF': 'XPF',
  'WS': 'WST', 'YE': 'YER', 'ZA': 'ZAR', 'ZM': 'ZMW', 'ZW': 'USD',
};

// ─── Importi ────────────────────────────────────────────────────────────────

/// Il testo che la persona scrive → centesimi. Accetta la virgola e il punto
/// come separatore dei decimali, e il punto o lo spazio per le migliaia:
/// `12,40`, `12.40`, `1.234,50`, `1 500`. Al massimo due decimali, e al
/// massimo quanti ne ha la valuta. `null` se non è un importo, o non è
/// maggiore di zero.
int? leggiImporto(String testo, {int decimali = 2}) {
  var t = testo.replaceAll(RegExp(r'[\s  ]'), '');
  if (t.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(t)) return null;
  final virgola = t.lastIndexOf(',');
  final punto = t.lastIndexOf('.');
  String? separatore;
  if (virgola >= 0 && punto >= 0) {
    separatore = virgola > punto ? ',' : '.';
  } else if (virgola >= 0) {
    separatore = ',';
  } else if (punto >= 0) {
    // `1.500` sono millecinquecento, `1.50` uno e mezzo.
    final migliaia = RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t);
    if (migliaia) {
      t = t.replaceAll('.', '');
    } else {
      separatore = '.';
    }
  }
  String intera = t;
  String parte = '';
  if (separatore != null) {
    final i = t.lastIndexOf(separatore);
    intera = t.substring(0, i);
    parte = t.substring(i + 1);
    if (parte.contains(RegExp('[.,]'))) return null;
  }
  // Le migliaia: solo l'altro segno, e a gruppi di tre.
  final altro = separatore == ',' ? '.' : ',';
  if (intera.contains(altro)) {
    if (!RegExp('^\\d{1,3}(\\$altro\\d{3})+\$').hasMatch(intera)) return null;
    intera = intera.replaceAll(altro, '');
  }
  if (intera.contains(RegExp('[.,]'))) return null;
  if (intera.isEmpty) intera = '0';
  if (parte.length > 2 || parte.length > decimali) return null;
  final unita = int.tryParse(intera);
  final frazione = int.tryParse(parte.padRight(2, '0'));
  if (unita == null || frazione == null) return null;
  final centesimi = unita * 100 + frazione;
  // Il server tiene dodici cifre, due dopo la virgola.
  if (centesimi <= 0 || centesimi >= 10000000000) return null;
  return centesimi;
}

/// L'importo come lo scrive il server → centesimi: `12.40`, `12.4`, `300`.
int centesimiDa(String importo) {
  final parti = importo.trim().split('.');
  final unita = int.parse(parti.first);
  final frazione = parti.length > 1
      ? int.parse(parti[1].padRight(2, '0').substring(0, 2))
      : 0;
  return unita * 100 + frazione;
}

/// Centesimi → l'importo come lo vuole il server: `12.40`.
String importoPerIlServer(int centesimi) =>
    '${centesimi ~/ 100}.${(centesimi % 100).toString().padLeft(2, '0')}';

/// `12,40 €`, `1.234,50 MAD`, `1.500 JPY`. L'euro col suo simbolo, le altre
/// col codice: `$` vuol dire troppe cose.
String scriviImporto(int centesimi, String codice) {
  final v = valutaDi(codice);
  final negativo = centesimi < 0;
  final assoluto = centesimi.abs();
  var unita = assoluto ~/ 100;
  var frazione = assoluto % 100;
  if (v.decimali == 0 && frazione != 0) {
    unita += frazione >= 50 ? 1 : 0;
    frazione = 0;
  }
  final cifre = unita.toString();
  final gruppi = <String>[];
  for (var fine = cifre.length; fine > 0; fine -= 3) {
    gruppi.insert(0, cifre.substring(fine - 3 < 0 ? 0 : fine - 3, fine));
  }
  final numero = [
    gruppi.join('.'),
    if (v.decimali > 0) frazione.toString().padLeft(2, '0'),
  ].join(',');
  final simbolo = codice == 'EUR' ? '€' : codice;
  return '${negativo ? '−' : ''}$numero $simbolo';
}

/// Per il campo dell'importo quando si cambia una spesa: `12,40`, `300`.
String importoDaModificare(int centesimi) {
  final unita = centesimi ~/ 100;
  final frazione = centesimi % 100;
  return frazione == 0
      ? '$unita'
      : '$unita,${frazione.toString().padLeft(2, '0')}';
}

/// Il tasto della virgola e quello che cancella, sul tastierino della spesa
/// veloce (09, regola 9).
const tastoVirgola = ',';
const tastoCancella = '⌫';

/// Quante cifre si scrivono prima della virgola: il server ne tiene dieci.
const cifreMassime = 9;

/// L'importo scritto con il tastierino dopo aver premuto [tasto]: una cifra, la
/// virgola o la cancellazione. Quello che non avrebbe senso non entra — una
/// seconda virgola, la virgola in una valuta senza decimali, un decimale di
/// troppo, uno zero davanti — e il testo resta com'era.
String conIlTasto(String testo, String tasto, {int decimali = 2}) {
  if (tasto == tastoCancella) {
    return testo.isEmpty ? testo : testo.substring(0, testo.length - 1);
  }
  final virgola = testo.indexOf(tastoVirgola);
  if (tasto == tastoVirgola) {
    if (decimali == 0 || virgola >= 0) return testo;
    return testo.isEmpty ? '0,' : '$testo,';
  }
  if (!RegExp(r'^\d$').hasMatch(tasto)) return testo;
  if (virgola >= 0) {
    final dopo = testo.length - virgola - 1;
    return dopo >= decimali ? testo : '$testo$tasto';
  }
  if (testo == '0') return tasto;
  return testo.length >= cifreMassime ? testo : '$testo$tasto';
}

// ─── Conversioni ────────────────────────────────────────────────────────────

/// Converte [centesimi] da una valuta all'altra con i tassi per euro.
/// `null` se manca il tasso di una delle due: non si inventa (06, casi limite).
int? converti(
  int centesimi, {
  required String da,
  required String a,
  required Map<String, double> perEuro,
}) {
  if (da == a) return centesimi;
  final tassoDa = da == 'EUR' ? 1.0 : perEuro[da];
  final tassoA = a == 'EUR' ? 1.0 : perEuro[a];
  if (tassoDa == null || tassoA == null || tassoDa <= 0 || tassoA <= 0) {
    return null;
  }
  return (centesimi / tassoDa * tassoA).round();
}

/// Il tasso fra due valute in parole: `1 € = 11,18 MAD`. Con la valuta della
/// persona a sinistra, così il numero cresce e si legge come al cambio.
/// `null` senza tasso.
String? tassoInParole({
  required String mia,
  required String altra,
  required Map<String, double> perEuro,
}) {
  final daMia = converti(10000, da: mia, a: altra, perEuro: perEuro);
  if (daMia == null) return null;
  final valore = daMia / 10000;
  final cifre = valore >= 100
      ? 0
      : valore >= 1
      ? 2
      : 4;
  final testo = valore.toStringAsFixed(cifre).replaceAll('.', ',');
  final sinistra = mia == 'EUR' ? '1 €' : '1 $mia';
  final destra = altra == 'EUR' ? '€' : altra;
  return '$sinistra = $testo $destra';
}
