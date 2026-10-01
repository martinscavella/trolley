/// Il testo come lo confronta la ricerca: minuscolo, senza accenti, senza
/// punteggiatura. "Sant'Agata de' Goti" e "sant agata de goti" sono la stessa
/// cosa, e "Malmö" si trova scrivendo "malmo".
library;

String normalizza(String testo) {
  final risultato = StringBuffer();
  var inParola = false;
  for (final carattere in testo.toLowerCase().runes) {
    // I segni staccati dalla lettera (un accento scritto a parte) si lasciano cadere.
    if (carattere >= 0x300 && carattere <= 0x36F) continue;
    final semplice = _semplici[carattere];
    if (semplice != null || _eLettera(carattere)) {
      if (!inParola && risultato.isNotEmpty) risultato.write(' ');
      risultato.write(semplice ?? String.fromCharCode(carattere));
      inParola = true;
    } else {
      inParola = false;
    }
  }
  return risultato.toString();
}

/// Lettere e cifre. Quello che non è latino (greco, cirillico, ideogrammi) non
/// si semplifica, ma resta: si confronta così com'è.
bool _eLettera(int c) =>
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0xC0 && c <= 0x2FF && c != 0xD7 && c != 0xF7) ||
    (c >= 0x370 &&
        !(c >= 0x2000 && c <= 0x2BFF) &&
        !(c >= 0x3000 && c <= 0x303F) &&
        !(c >= 0xFE30 && c <= 0xFE4F) &&
        !(c >= 0xFF00 && c <= 0xFF0F));

/// Le lettere latine con segni, ridotte alla lettera di base.
final _semplici = <int, String>{
  for (final (da, a) in const [
    ('àáâãäåāăąǎ', 'a'),
    ('æ', 'ae'),
    ('çćĉċč', 'c'),
    ('ďđ', 'd'),
    ('èéêëēĕėęě', 'e'),
    ('ĝğġģ', 'g'),
    ('ĥħ', 'h'),
    ('ìíîïĩīĭįıǐ', 'i'),
    ('ĳ', 'ij'),
    ('ĵ', 'j'),
    ('ķ', 'k'),
    ('ĺļľŀł', 'l'),
    ('ñńņňŉ', 'n'),
    ('òóôõöøōŏőǒ', 'o'),
    ('œ', 'oe'),
    ('ŕŗř', 'r'),
    ('śŝşšș', 's'),
    ('ß', 'ss'),
    ('ţťŧț', 't'),
    ('ùúûüũūŭůűųǔ', 'u'),
    ('ŵ', 'w'),
    ('ýÿŷ', 'y'),
    ('źżž', 'z'),
    ('þ', 'th'),
    ('ð', 'd'),
  ])
    for (final lettera in da.runes) lettera: a,
};
