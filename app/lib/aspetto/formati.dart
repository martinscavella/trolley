/// Come si scrivono date, nomi e stati nell'interfaccia.
library;

import 'package:flutter/widgets.dart' show StringCharacters;

import '../dati/database.dart';

const _mesi = [
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

/// `12 ottobre 2026`.
String dataEstesa(DateTime d) => '${d.day} ${_mesi[d.month - 1]} ${d.year}';

/// L'intervallo più corto che non lascia dubbi:
/// `10–12 ottobre 2026`, `28 ottobre – 3 novembre 2026`,
/// `30 dicembre 2026 – 2 gennaio 2027`.
String intervalloDate(DateTime inizio, DateTime fine) {
  if (inizio.year != fine.year) {
    return '${dataEstesa(inizio)} – ${dataEstesa(fine)}';
  }
  if (inizio.month != fine.month) {
    return '${inizio.day} ${_mesi[inizio.month - 1]} – ${dataEstesa(fine)}';
  }
  if (inizio.day != fine.day) {
    return '${inizio.day}–${dataEstesa(fine)}';
  }
  return dataEstesa(inizio);
}

/// Quanti giorni di calendario tocca il viaggio, estremi compresi.
int giorniDiViaggio(DateTime inizio, DateTime fine) =>
    DateTime.utc(
      fine.year,
      fine.month,
      fine.day,
    ).difference(DateTime.utc(inizio.year, inizio.month, inizio.day)).inDays +
    1;

/// Le iniziali per un avatar: `Giulia Rossi` → `GR`, `marco` → `M`.
String iniziali(String nome) {
  final parole = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parole.isEmpty) return '?';
  return parole.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// La bandiera di un paese dal suo codice ISO a due lettere, se è valido.
String? bandiera(String? paese) {
  final codice = paese?.trim().toUpperCase();
  if (codice == null || !RegExp(r'^[A-Z]{2}$').hasMatch(codice)) return null;
  return String.fromCharCodes(codice.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

/// `1 viaggio`, `3 viaggi`.
String quanti(int n, String singolare, String plurale) =>
    '$n ${n == 1 ? singolare : plurale}';

String titoloViaggio(Viaggio v) => v.destinazioneCitta ?? 'Viaggio senza meta';

String descrizioneStato(String stato) => switch (stato) {
  'idea' => 'Idea',
  'definito' => 'Definito',
  'in_corso' => 'In corso',
  'chiuso' => 'Chiuso',
  'archiviato' => 'Archiviato',
  _ => stato,
};

/// Quando: le date se ci sono, altrimenti il periodo detto a parole.
String quandoViaggio(Viaggio v) {
  final inizio = DateTime.tryParse(v.dataInizio ?? '');
  final fine = DateTime.tryParse(v.dataFine ?? '');
  if (inizio != null && fine != null) return intervalloDate(inizio, fine);
  return v.periodoApprossimativo ?? 'Date da decidere';
}
