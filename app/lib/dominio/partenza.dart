/// Prima di partire (09, regola 6; 02 §1; tela, 56, 57, 90–92): quando il
/// viaggio mostra il giro di controllo, e che cosa ci si guarda. Le regole
/// stanno qui; le parole nella schermata.
library;

import 'calendario.dart';
import 'stato_viaggio.dart';

/// Da quanti giorni prima della partenza il viaggio mostra «Prima di
/// partire».
const giorniPrimaDiPartire = 2;

/// Quanti giorni mancano alla partenza — 0 il giorno stesso —, se il viaggio
/// mostra adesso «Prima di partire»; `null` altrimenti. Il giorno della
/// partenza il viaggio è già in corso, ma la valigia spesso si chiude quella
/// mattina: il giro di controllo resta fino a sera.
int? giorniAllaPartenza({
  required StatoViaggio stato,
  required DateTime? inizio,
  required DateTime oggi,
}) {
  if (inizio == null) return null;
  if (stato != StatoViaggio.definito && stato != StatoViaggio.inCorso) {
    return null;
  }
  final giorni = soloData(inizio).difference(soloData(oggi)).inDays;
  if (giorni < 0 || giorni > giorniPrimaDiPartire) return null;
  return giorni;
}

/// Una voce delle cose da portare, come la guarda il giro di controllo.
typedef VocePrimaDiPartire = ({
  String testo,
  bool spuntata,

  /// Della propria lista; altrimenti di quella del viaggio.
  bool personale,

  /// Chi la porta, se è del viaggio e la porta qualcuno che c'è.
  String? portaChi,
  DateTime creataIl,
});

/// La valigia di chi guarda: le voci della propria lista e quelle della lista
/// del viaggio che porta lui. A parte, quelle del viaggio che non porta
/// nessuno: prima di partire è il momento di dividersele (05, regola 2).
class ValigiaPrimaDiPartire {
  const ValigiaPrimaDiPartire({
    required this.tutte,
    required this.fatte,
    required this.mancano,
    required this.diNessuno,
  });

  final int tutte;
  final int fatte;

  /// Quelle ancora da mettere, nell'ordine in cui sono nate.
  final List<String> mancano;

  /// Le voci del viaggio non ancora in valigia che non porta nessuno.
  final int diNessuno;

  bool get vuota => tutte == 0 && diNessuno == 0;

  /// Tutto in valigia, e niente del viaggio che resta senza qualcuno.
  bool get fatta => tutte > 0 && fatte == tutte && diNessuno == 0;
}

ValigiaPrimaDiPartire valigiaPrimaDiPartire(
  Iterable<VocePrimaDiPartire> voci, {
  required String io,
}) {
  final ordinate = [...voci]..sort((a, b) => a.creataIl.compareTo(b.creataIl));
  final mie = [
    for (final v in ordinate)
      if (v.personale || v.portaChi == io) v,
  ];
  return ValigiaPrimaDiPartire(
    tutte: mie.length,
    fatte: mie.where((v) => v.spuntata).length,
    mancano: [
      for (final v in mie)
        if (!v.spuntata) v.testo,
    ],
    diNessuno: ordinate
        .where((v) => !v.personale && v.portaChi == null && !v.spuntata)
        .length,
  );
}
