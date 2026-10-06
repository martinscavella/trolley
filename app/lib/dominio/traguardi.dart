/// I traguardi (10-chiusura-e-ricordo.md, regole 4 e 7; tela, 60 e 62): una
/// cartolina, non un motore. Si prendono solo con i viaggi verificati, uno
/// per tipo, e non scadono né dipendono dal piano.
///
/// Quali sono, e quando si prendono, sta qui: il server li conserva e li
/// accetta solo da un viaggio verificato per chi li prende.
library;

import 'calendario.dart';

/// I traguardi, con il nome con cui il server li conserva. Gli ultimi tre si
/// contano su tutti i viaggi verificati; gli altri li dà un viaggio solo.
enum Traguardo {
  primoViaggioVerificato(
    'primo_viaggio_verificato',
    'Primo viaggio verificato',
  ),
  inCompagnia('in_compagnia', 'In compagnia'),
  weekendLungo('weekend_lungo', 'Weekend lungo'),
  unaSettimana('una_settimana', 'Una settimana'),
  ogniGiornoUnaTappa('ogni_giorno_una_tappa', 'Ogni giorno una tappa'),
  organizzare('organizzare', 'Organizzare'),
  trePaesi('tre_paesi', 'Tre paesi', soglia: 3),
  dieciCitta('dieci_citta', 'Dieci città', soglia: 10),
  quattroStagioni('quattro_stagioni', 'Quattro stagioni', soglia: 4);

  const Traguardo(this.codice, this.nome, {this.soglia});

  /// Come lo scrive il server.
  final String codice;
  final String nome;

  /// Per quelli che si contano: quanti ne servono.
  final int? soglia;

  static Traguardo? leggi(String codice) {
    for (final t in values) {
      if (t.codice == codice) return t;
    }
    return null;
  }
}

/// Un viaggio verificato, quanto serve per i traguardi.
typedef ViaggioVerificato = ({
  String id,
  DateTime inizio,
  DateTime fine,
  String? paese,
  String? citta,

  /// Quante persone c'erano.
  int persone,

  /// Chi guarda ne era responsabile.
  bool responsabile,

  /// Per giorno, quante tappe sono state fatte (non saltate).
  List<int> fattePerGiorno,
});

/// Le stagioni, dal mese d'inizio: inverno dicembre–febbraio, primavera
/// marzo–maggio, estate giugno–agosto, autunno settembre–novembre.
int stagione(DateTime d) => (d.month % 12) ~/ 3;

/// Quanti giorni dura un viaggio, il primo e l'ultimo compresi.
int giorniDi(ViaggioVerificato v) => giorniDiCalendario(v.inizio, v.fine);

/// Se [v], da solo, dà il traguardo [t]. Per quelli che si contano, no.
bool loDa(Traguardo t, ViaggioVerificato v) => switch (t) {
  Traguardo.primoViaggioVerificato => true,
  Traguardo.inCompagnia => v.persone >= 2,
  Traguardo.weekendLungo => _weekendLungo(v),
  Traguardo.unaSettimana => giorniDi(v) >= 7,
  Traguardo.ogniGiornoUnaTappa =>
    v.fattePerGiorno.isNotEmpty && v.fattePerGiorno.every((n) => n > 0),
  Traguardo.organizzare => v.responsabile && v.persone >= 2,
  Traguardo.trePaesi ||
  Traguardo.dieciCitta ||
  Traguardo.quattroStagioni => false,
};

/// Tre o quattro giorni, con dentro un sabato e una domenica.
bool _weekendLungo(ViaggioVerificato v) {
  final giorni = giorniDi(v);
  if (giorni < 3 || giorni > 4) return false;
  final settimana = {
    for (var i = 0; i < giorni; i++)
      soloData(v.inizio).add(Duration(days: i)).weekday,
  };
  return settimana.contains(DateTime.saturday) &&
      settimana.contains(DateTime.sunday);
}

/// Per quelli che si contano: a che punto si è, su tutti i viaggi
/// verificati.
int contati(Traguardo t, Iterable<ViaggioVerificato> verificati) => switch (t) {
  Traguardo.trePaesi => {for (final v in verificati) ?v.paese}.length,
  Traguardo.dieciCitta => {
    for (final v in verificati)
      if (v.citta != null) '${v.citta!.toLowerCase()}|${v.paese}',
  }.length,
  Traguardo.quattroStagioni => {
    for (final v in verificati) stagione(v.inizio),
  }.length,
  _ => 0,
};

/// I traguardi che la chiusura di [questo] fa prendere, dati quelli già
/// presi: quelli che dà lui, e quelli che si contano e arrivano alla soglia
/// con lui. [verificati] sono tutti i viaggi verificati, questo compreso.
Set<Traguardo> traguardiNuovi({
  required ViaggioVerificato questo,
  required Iterable<ViaggioVerificato> verificati,
  required Set<Traguardo> presi,
}) => {
  for (final t in Traguardo.values)
    if (!presi.contains(t) &&
        (t.soglia == null
            ? loDa(t, questo)
            : contati(t, verificati) >= t.soglia!))
      t,
};
