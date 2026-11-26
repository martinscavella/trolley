/// Gli orari di apertura di un posto (CR-06, passo 3; poi CR-03 per gli
/// avvisi sulle tappe): in che ore di un certo giorno è aperto, nell'ora del
/// posto. Gli orari arrivano dal fornitore e non si tengono (ADR-014): queste
/// regole lavorano su quello che arriva, finché la schermata è aperta.
library;

/// Un'apertura: da quando a quando, in un giorno della settimana. Il giorno
/// è quello di Google: 0 è domenica, 6 sabato. Se chiude il giorno dopo
/// (un bar fino alle 2), [chiude] va oltre le 24 ore.
class Apertura {
  const Apertura({required this.giorno, required this.apre, this.chiude});

  final int giorno;
  final Duration apre;

  /// `null`: non chiude (aperto sempre).
  final Duration? chiude;
}

/// Quando un posto è aperto, giorno per giorno.
class OrariDiApertura {
  const OrariDiApertura(this.aperture);

  final List<Apertura> aperture;

  /// Aperto sempre: una sola apertura senza chiusura.
  bool get sempre => aperture.length == 1 && aperture.single.chiude == null;

  /// Le aperture del giorno di [data], in ordine. Vuoto: chiuso tutto il
  /// giorno.
  List<({Duration apre, Duration chiude})> del(DateTime data) {
    if (sempre) {
      return const [(apre: Duration.zero, chiude: Duration(hours: 24))];
    }
    final giorno = data.weekday % 7;
    return [
      for (final a in aperture)
        if (a.giorno == giorno)
          (apre: a.apre, chiude: a.chiude ?? const Duration(hours: 24)),
    ]..sort((x, y) => x.apre.compareTo(y.apre));
  }

  /// Gli orari di una risposta di Google (`regularOpeningHours.periods`);
  /// `null` se non ce ne sono.
  static OrariDiApertura? daGoogle(Object? json) {
    if (json is! Map) return null;
    final periodi = json['periods'];
    if (periodi is! List || periodi.isEmpty) return null;
    final aperture = <Apertura>[];
    for (final p in periodi.whereType<Map>()) {
      final apre = _punto(p['open']);
      if (apre == null) continue;
      final chiude = _punto(p['close']);
      Duration? fine;
      if (chiude != null) {
        // Chiude un altro giorno della settimana: sono ore in più.
        final giorni = (chiude.giorno - apre.giorno) % 7;
        fine = Duration(days: giorni) + chiude.ora;
        if (fine <= apre.ora) fine += const Duration(days: 7);
      }
      aperture.add(Apertura(giorno: apre.giorno, apre: apre.ora, chiude: fine));
    }
    return aperture.isEmpty ? null : OrariDiApertura(aperture);
  }

  static ({int giorno, Duration ora})? _punto(Object? json) {
    if (json is! Map) return null;
    final giorno = json['day'];
    if (giorno is! int || giorno < 0 || giorno > 6) return null;
    final ore = json['hour'] is int ? json['hour'] as int : 0;
    final minuti = json['minute'] is int ? json['minute'] as int : 0;
    return (giorno: giorno, ora: Duration(hours: ore, minutes: minuti));
  }
}
