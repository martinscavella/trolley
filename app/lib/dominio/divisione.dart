/// Dividere le spese (06-spese.md, regole 8–10): per chi è una spesa, quanto
/// ha messo e quanto deve ognuno, e il giro più corto per pareggiare.
///
/// Le parti stanno nella valuta della spesa: è il dato vero. I saldi si fanno
/// nella valuta della persona con l'ultimo tasso noto, dicendo quale (06,
/// casi limite); quello che non ha un tasso resta fuori, e si dice.
library;

import 'valute.dart';

/// Le parti uguali di [centesimi] fra [persone], nell'ordine dato: i
/// centesimi che avanzano vanno ai primi, uno ciascuno. 10,00 € in tre fanno
/// 3,34, 3,33 e 3,33: la somma torna sempre.
Map<String, int> partiUguali(int centesimi, List<String> persone) {
  if (persone.isEmpty) return const {};
  final base = centesimi ~/ persone.length;
  final avanzo = centesimi - base * persone.length;
  return {for (final (i, p) in persone.indexed) p: base + (i < avanzo ? 1 : 0)};
}

/// Quanto manca perché le parti facciano l'importo: positivo se manca,
/// negativo se le parti sono troppe, zero se tornano.
int mancaAlleParti(int centesimi, Iterable<int> parti) =>
    centesimi - parti.fold(0, (a, b) => a + b);

/// Una spesa divisa in parti uguali fra tutti quelli per cui è.
bool inPartiUguali(int centesimi, Map<String, int> quote) {
  if (quote.isEmpty) return true;
  final valori = quote.values.toList()..sort();
  return valori.last - valori.first <= 1 &&
      mancaAlleParti(centesimi, valori) == 0;
}

/// Quando qualcuno è stato nel viaggio: da quando è entrato a quando, se è
/// uscito o è stato tolto, ne è uscito.
class Presenza {
  const Presenza(this.utente, {this.entrato, this.uscito});

  final String utente;

  /// `null` se non si sa: allora c'era da sempre.
  final DateTime? entrato;

  /// `null` se c'è ancora.
  final DateTime? uscito;
}

/// Per chi è una spesa registrata prima della divisione, senza quote: in
/// parti uguali fra chi era nel viaggio quando è stata registrata
/// (decisioni/prodotto.md). Chi paga c'è sempre.
List<String> chiCera(
  DateTime registrata, {
  required Iterable<Presenza> presenze,
  required String pagante,
}) {
  final cerano = [
    for (final p in presenze)
      if ((p.entrato == null || !p.entrato!.isAfter(registrata)) &&
          (p.uscito == null || p.uscito!.isAfter(registrata)))
        p.utente,
  ];
  return [if (!cerano.contains(pagante)) pagante, ...cerano];
}

/// Una spesa come la vede la divisione.
class SpesaDaDividere {
  const SpesaDaDividere({
    required this.pagante,
    required this.centesimi,
    required this.valuta,
    required this.quote,
    this.rimborso = false,
  });

  final String pagante;
  final int centesimi;
  final String valuta;

  /// Per persona, nella valuta della spesa.
  final Map<String, int> quote;

  /// Chi dà i soldi l'ha «pagato», chi li riceve ne ha tutta la quota.
  final bool rimborso;
}

/// Quanto deve ricevere ognuno (positivo) o dare (negativo), nella valuta
/// della persona.
class Saldi {
  const Saldi(this.netti, {this.senzaTasso = const {}});

  final Map<String, int> netti;

  /// Le valute di spese che non si sono potute mettere nei saldi: il loro
  /// tasso non c'è.
  final Set<String> senzaTasso;

  int di(String persona) => netti[persona] ?? 0;

  /// Tutti pari.
  bool get pari => netti.values.every((n) => n == 0);
}

/// I saldi di un insieme di spese, rimborsi compresi, nella valuta [mia].
/// Si somma valuta per valuta, dove i conti tornano al centesimo, e si
/// converte alla fine: l'arrotondamento che avanza va a chi ha il saldo più
/// grande, così la somma resta zero.
Saldi calcolaSaldi(
  Iterable<SpesaDaDividere> spese, {
  required String mia,
  required Map<String, double> perEuro,
}) {
  final perValuta = <String, Map<String, int>>{};
  for (final s in spese) {
    final conti = perValuta.putIfAbsent(s.valuta, () => {});
    conti.update(
      s.pagante,
      (n) => n + s.centesimi,
      ifAbsent: () => s.centesimi,
    );
    for (final MapEntry(key: persona, value: quota) in s.quote.entries) {
      conti.update(persona, (n) => n - quota, ifAbsent: () => -quota);
    }
  }
  final netti = <String, int>{};
  final senzaTasso = <String>{};
  for (final MapEntry(key: valuta, value: conti) in perValuta.entries) {
    if (conti.values.every((n) => n == 0)) {
      for (final p in conti.keys) {
        netti.putIfAbsent(p, () => 0);
      }
      continue;
    }
    final convertiti = {
      for (final MapEntry(key: p, value: n) in conti.entries)
        p: converti(n, da: valuta, a: mia, perEuro: perEuro),
    };
    if (convertiti.values.any((n) => n == null)) {
      senzaTasso.add(valuta);
      continue;
    }
    for (final MapEntry(key: p, value: n) in convertiti.entries) {
      netti.update(p, (x) => x + n!, ifAbsent: () => n!);
    }
  }
  final avanzo = netti.values.fold(0, (a, b) => a + b);
  if (avanzo != 0 && netti.isNotEmpty) {
    final piuGrande =
        (netti.entries.toList()..sort((a, b) {
              final perValore = b.value.abs().compareTo(a.value.abs());
              return perValore != 0 ? perValore : a.key.compareTo(b.key);
            }))
            .first
            .key;
    netti[piuGrande] = netti[piuGrande]! - avanzo;
  }
  return Saldi(netti, senzaTasso: senzaTasso);
}

/// Un passaggio di soldi per pareggiare.
class Passaggio {
  const Passaggio({required this.da, required this.a, required this.centesimi});

  final String da;
  final String a;
  final int centesimi;

  @override
  bool operator ==(Object other) =>
      other is Passaggio &&
      other.da == da &&
      other.a == a &&
      other.centesimi == centesimi;

  @override
  int get hashCode => Object.hash(da, a, centesimi);

  @override
  String toString() => '$da → $a: $centesimi';
}

/// Il giro più corto per pareggiare (06, regola 9): prima chi deve
/// esattamente quanto un altro deve ricevere, poi sempre il debito più grande
/// verso il credito più grande. Così i passaggi sono al più uno meno delle
/// persone coinvolte, e di solito meno.
List<Passaggio> pareggia(Map<String, int> netti) {
  int ordine(_Conto a, _Conto b) {
    final perValore = b.resta.compareTo(a.resta);
    return perValore != 0 ? perValore : a.chi.compareTo(b.chi);
  }

  final debiti = [
    for (final e in netti.entries)
      if (e.value < 0) _Conto(e.key, -e.value),
  ]..sort(ordine);
  final crediti = [
    for (final e in netti.entries)
      if (e.value > 0) _Conto(e.key, e.value),
  ]..sort(ordine);
  final passaggi = <Passaggio>[];

  // Chi deve esattamente quanto un altro aspetta: un passaggio solo.
  for (final d in [...debiti]) {
    final pari = crediti.where((c) => c.resta == d.resta).firstOrNull;
    if (pari == null) continue;
    passaggi.add(Passaggio(da: d.chi, a: pari.chi, centesimi: d.resta));
    debiti.remove(d);
    crediti.remove(pari);
  }

  var i = 0;
  var j = 0;
  while (i < debiti.length && j < crediti.length) {
    final d = debiti[i];
    final c = crediti[j];
    final quanto = d.resta < c.resta ? d.resta : c.resta;
    passaggi.add(Passaggio(da: d.chi, a: c.chi, centesimi: quanto));
    d.resta -= quanto;
    c.resta -= quanto;
    if (d.resta == 0) i++;
    if (c.resta == 0) j++;
  }
  return passaggi;
}

/// Quanto resta da dare o da avere a qualcuno, mentre si pareggia.
class _Conto {
  _Conto(this.chi, this.resta);

  final String chi;
  int resta;
}

/// Quanti passaggi servirebbero pareggiando spesa per spesa, ognuno con chi
/// ha pagato la sua parte: il numero da cui il giro più corto fa risparmiare.
int passaggiUnoAUno(
  Iterable<SpesaDaDividere> spese, {
  required String mia,
  required Map<String, double> perEuro,
}) {
  final coppie = <(String, String), int>{};
  for (final s in spese) {
    for (final MapEntry(key: persona, value: quota) in s.quote.entries) {
      if (persona == s.pagante || quota == 0) continue;
      final inMia = converti(quota, da: s.valuta, a: mia, perEuro: perEuro);
      if (inMia == null) continue;
      // La coppia sempre nello stesso verso: chi deve a chi, con il segno.
      final (primo, secondo, segno) = persona.compareTo(s.pagante) < 0
          ? (persona, s.pagante, 1)
          : (s.pagante, persona, -1);
      coppie.update(
        (primo, secondo),
        (n) => n + segno * inMia,
        ifAbsent: () => segno * inMia,
      );
    }
  }
  return coppie.values.where((n) => n != 0).length;
}

/// Una spesa come serve per accorgersi che due sono forse la stessa.
class SpesaRegistrata<T> {
  const SpesaRegistrata({
    required this.spesa,
    required this.creatore,
    required this.centesimi,
    required this.valuta,
    required this.registrata,
  });

  final T spesa;
  final String creatore;
  final int centesimi;
  final String valuta;
  final DateTime registrata;
}

/// Quanto vicine devono essere due spese uguali per sembrare la stessa.
const vicineSeEntro = Duration(minutes: 10);

/// Le coppie di spese che sembrano la stessa registrata da due persone (06,
/// casi limite): stesso importo, stessa valuta, a pochi minuti di distanza,
/// da due persone diverse. Prima quella registrata prima. Non si può
/// impedire: si segnala, e decide chi l'ha registrata dopo.
List<(T, T)> forseDoppie<T>(Iterable<SpesaRegistrata<T>> spese) {
  final ordinate = spese.toList()
    ..sort((a, b) => a.registrata.compareTo(b.registrata));
  return [
    for (final (i, a) in ordinate.indexed)
      for (final b in ordinate.skip(i + 1))
        if (b.registrata.difference(a.registrata) <= vicineSeEntro &&
            a.creatore != b.creatore &&
            a.centesimi == b.centesimi &&
            a.valuta == b.valuta)
          (a.spesa, b.spesa),
  ];
}
