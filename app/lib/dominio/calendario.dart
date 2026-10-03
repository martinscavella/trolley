/// Date e orari come li scrivono il server e la copia locale: `2026-10-10`,
/// `10:00:00`.
///
/// Nessun fuso orario: un giorno di viaggio è un giorno di calendario, e un
/// orario è una distanza dalla mezzanotte. Le date stanno a mezzanotte UTC così
/// due date si confrontano senza che l'ora legale sposti niente.
library;

const nomiDeiMesi = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

/// Da lunedì, come `DateTime.weekday`.
const nomiDeiGiorni = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

/// Solo la data, a mezzanotte UTC.
DateTime soloData(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// `2026-10-10` → la data. `null` se il testo non è una data.
DateTime? leggiData(String? testo) {
  final d = testo == null ? null : DateTime.tryParse(testo);
  return d == null ? null : soloData(d);
}

/// La data → `2026-10-10`.
String scriviData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_due(d.month)}-${_due(d.day)}';

/// `10:30:00` → dieci ore e mezza dalla mezzanotte. `24:00:00` è la fine del
/// giorno, e il server lo accetta. `null` se il testo non è un orario.
Duration? leggiOra(String? testo) {
  final parti = testo?.split(':');
  if (parti == null || parti.length < 2 || parti.length > 3) return null;
  final ore = int.tryParse(parti[0]);
  final minuti = int.tryParse(parti[1]);
  final secondi = parti.length == 3
      ? int.tryParse(parti[2].split('.').first)
      : 0;
  if (ore == null || minuti == null || secondi == null) return null;
  final ora = Duration(hours: ore, minutes: minuti, seconds: secondi);
  if (ora.isNegative || ora > const Duration(hours: 24)) return null;
  return ora;
}

/// Un orario → `10:30:00`.
String scriviOra(Duration ora) =>
    '${_due(ora.inHours)}:${_due(ora.inMinutes % 60)}:${_due(ora.inSeconds % 60)}';

/// Quanti giorni di calendario tocca un intervallo, estremi compresi.
int giorniDiCalendario(DateTime inizio, DateTime fine) =>
    soloData(fine).difference(soloData(inizio)).inDays + 1;

/// [mesi] mesi di calendario dopo [d]. Se il giorno non esiste nel mese
/// d'arrivo si ferma all'ultimo: 31 gennaio più un mese è il 28 febbraio.
DateTime aggiungiMesi(DateTime d, int mesi) {
  final indice = d.year * 12 + d.month - 1 + mesi;
  final anno = indice ~/ 12;
  final mese = indice % 12 + 1;
  final ultimo = DateTime.utc(anno, mese + 1, 0).day;
  return DateTime.utc(anno, mese, d.day > ultimo ? ultimo : d.day);
}

String _due(int n) => n.toString().padLeft(2, '0');
