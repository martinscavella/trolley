/// Le destinazioni incorporate nell'app (ADR-005): paesi e città principali, con
/// il codice del paese e le coordinate. Funzionano senza rete e non dipendono da
/// nessun fornitore. L'elenco lo scrive `tool/genera_destinazioni.dart`.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../dominio/mappa.dart';
import '../dominio/testo.dart';
import 'paesi.dart';

enum TipoDestinazione {
  paese,
  citta,

  /// Scritta a mano perché l'elenco non la conosce: una zona, un'isola, un
  /// paesino. Esiste lo stesso; sul mappamondo conterà il paese, se c'è.
  aMano,
}

class Destinazione {
  const Destinazione({
    required this.tipo,
    required this.nome,
    required this.paese,
    this.lat,
    this.lon,
    this.dettaglio = '',
  });

  const Destinazione.aMano(this.nome, {this.paese})
    : tipo = TipoDestinazione.aMano,
      lat = null,
      lon = null,
      dettaglio = '';

  final TipoDestinazione tipo;

  /// In italiano, come si mostra.
  final String nome;

  /// Il codice ISO a due lettere. Manca solo per un nome scritto a mano senza
  /// paese.
  final String? paese;
  final double? lat;
  final double? lon;

  /// La regione o la provincia: distingue due città con lo stesso nome.
  final String dettaglio;

  /// Cosa va nella colonna `destinazione_citta`: un paese intero non ha città.
  String? get citta => tipo == TipoDestinazione.paese ? null : nome;

  String? get nomePaese => nomeDelPaese(paese);

  Destinazione conPaese(String? codice) => Destinazione(
    tipo: tipo,
    nome: nome,
    paese: codice,
    lat: lat,
    lon: lon,
    dettaglio: dettaglio,
  );

  @override
  bool operator ==(Object other) =>
      other is Destinazione &&
      other.tipo == tipo &&
      other.nome == nome &&
      other.paese == paese &&
      other.dettaglio == dettaglio;

  @override
  int get hashCode => Object.hash(tipo, nome, paese, dettaglio);

  @override
  String toString() => '$nome ($paese)';
}

/// Il nome italiano di un paese dal suo codice.
String? nomeDelPaese(String? codice) =>
    codice == null ? null : nomiDeiPaesi[codice.toUpperCase()];

class ElencoDestinazioni {
  ElencoDestinazioni._(this._voci, this._nomi, this._rilevanza);

  /// Legge il formato di `assets/destinazioni.tsv`.
  factory ElencoDestinazioni.daTesto(String tsv) {
    final voci = <Destinazione>[];
    final nomi = <List<(String, List<String>)>>[];
    final popolazioni = <int>[];
    final europei = <String>{};
    for (final riga in tsv.split('\n')) {
      if (riga.isEmpty || riga.startsWith('#')) continue;
      final c = riga.split('\t');
      if (c.length < 8) continue;
      popolazioni.add(int.tryParse(c[5]) ?? 0);
      if (c.length > 8 && c[8] == 'EU') europei.add(c[2]);
      voci.add(
        Destinazione(
          tipo: c[0] == 'P' ? TipoDestinazione.paese : TipoDestinazione.citta,
          nome: c[1],
          paese: c[2],
          lat: double.tryParse(c[3]),
          lon: double.tryParse(c[4]),
          dettaglio: c[6],
        ),
      );
      nomi.add([
        for (final nome in [c[1], ...c[7].split('|')])
          if (normalizza(nome) case final n when n.isNotEmpty)
            (n, n.split(' ')),
      ]);
    }
    return ElencoDestinazioni._(voci, nomi, [
      for (final (i, voce) in voci.indexed)
        log(popolazioni[i] + 10) / ln10 +
            (voce.paese == 'IT'
                ? _spintaItalia
                : europei.contains(voce.paese)
                ? _spintaEuropa
                : 0),
    ]);
  }

  /// Chi usa l'app è italiano: a parità di nome, la meta più probabile è in
  /// Italia, poi in Europa. Valencia è in Spagna prima che in Venezuela.
  static const _spintaItalia = 1.5;
  static const _spintaEuropa = 1.0;

  /// Quanto vale ogni tipo di corrispondenza, nella stessa scala della
  /// rilevanza (un ordine di grandezza di abitanti vale 1).
  static const _pesoCorrispondenza = [3.0, 1.0, 0.0];

  /// L'elenco dell'app, letto una volta sola.
  static Future<ElencoDestinazioni> carica() => _caricato ??= rootBundle
      .loadString('assets/destinazioni.tsv')
      .then(ElencoDestinazioni.daTesto);
  static Future<ElencoDestinazioni>? _caricato;

  /// Per i test: un elenco già letto, pronto senza aspettare gli asset.
  @visibleForTesting
  static void usa(ElencoDestinazioni elenco) =>
      _caricato = SynchronousFuture(elenco);

  final List<Destinazione> _voci;

  /// Per ogni voce i suoi nomi normalizzati, interi e divisi in parole: il
  /// primo è quello italiano, gli altri quelli locali e inglesi.
  final List<List<(String, List<String>)>> _nomi;

  /// Quanto è probabile che si cerchi proprio questa: gli abitanti, in ordini
  /// di grandezza, più la vicinanza.
  final List<double> _rilevanza;

  int get lunghezza => _voci.length;

  /// Le destinazioni che corrispondono a [testo], le più probabili prima.
  ///
  /// Conta come corrisponde — il nome intero, l'inizio del nome, l'inizio di
  /// ogni parola — e quanto è grande e vicina: così "roma" dà Roma, poi la
  /// Romania, e solo dopo Roma nel Queensland.
  List<Destinazione> cerca(
    String testo, {
    int quante = 25,
    bool soloPaesi = false,
  }) {
    final cercato = normalizza(testo);
    if (cercato.isEmpty) return const [];
    final parole = cercato.split(' ');
    final trovate = <(double, int)>[];
    for (var i = 0; i < _voci.length; i++) {
      if (soloPaesi && _voci[i].tipo != TipoDestinazione.paese) continue;
      int? migliore;
      for (final nome in _nomi[i]) {
        final c = _corrispondenza(nome, cercato, parole);
        if (c != null && (migliore == null || c < migliore)) migliore = c;
        if (migliore == 0) break;
      }
      if (migliore != null) {
        trovate.add((_pesoCorrispondenza[migliore] + _rilevanza[i], i));
      }
    }
    trovate.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2 - b.$2);
    return [for (final (_, i) in trovate.take(quante)) _voci[i]];
  }

  /// La voce dell'elenco per la meta di un viaggio, che conserva solo il
  /// nome della città e il paese (ADR-005): da qui le sue coordinate, per la
  /// mappa. La città con quel nome — italiano, locale o inglese: una meta
  /// scritta a mano può essere «Copenhagen» — in quel paese, o la più
  /// probabile se il paese non c'è; altrimenti il paese intero. `null` se
  /// l'elenco non la conosce.
  Destinazione? trova({String? citta, String? paese}) {
    final codice = paese?.toUpperCase();
    final nome = citta == null ? '' : normalizza(citta);
    if (nome.isNotEmpty) {
      int? migliore;
      for (var i = 0; i < _voci.length; i++) {
        final d = _voci[i];
        if (d.tipo != TipoDestinazione.citta) continue;
        if (codice != null && d.paese != codice) continue;
        if (!_nomi[i].any((n) => n.$1 == nome)) continue;
        if (migliore == null || _rilevanza[i] > _rilevanza[migliore]) {
          migliore = i;
        }
      }
      if (migliore != null) return _voci[migliore];
    }
    if (codice == null) return null;
    for (final d in _voci) {
      if (d.tipo == TipoDestinazione.paese && d.paese == codice) return d;
    }
    return null;
  }

  /// Il paese in cui sta [qui], secondo l'elenco: quello della città più
  /// vicina. Vicino a un confine può sbagliare, e va bene: serve a dire se il
  /// telefono è nel paese di un viaggio (dominio/verifica.dart), non a
  /// tracciare confini. `null` in mezzo al mare, lontano da ogni città.
  String? paeseDi(Coordinate qui) {
    String? paese;
    var migliore = _lontanoDaTutto;
    for (final d in _voci) {
      if (d.tipo != TipoDestinazione.citta) continue;
      final posto = coordinate(d.lat, d.lon);
      if (posto == null) continue;
      final distanza = distanzaInMetri(qui, posto);
      if (distanza < migliore) {
        migliore = distanza;
        paese = d.paese;
      }
    }
    return paese;
  }

  /// Oltre questa distanza dalla città più vicina non si dice in che paese si
  /// è.
  static const _lontanoDaTutto = 300000.0;

  /// 0 il nome intero, 1 l'inizio del nome, 2 ogni parola cercata è l'inizio
  /// di una parola del nome; `null` se non corrisponde.
  static int? _corrispondenza(
    (String, List<String>) nome,
    String cercato,
    List<String> parole,
  ) {
    final (intero, sueParole) = nome;
    if (intero == cercato) return 0;
    if (intero.startsWith(cercato)) return 1;
    for (final parola in parole) {
      if (!sueParole.any((p) => p.startsWith(parola))) return null;
    }
    return 2;
  }
}
