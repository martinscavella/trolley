/// Le righe della copia locale lette come le intende il dominio: date, orari,
/// periodo, stato. La copia tiene i valori nel formato del server; qui si
/// traducono, in un posto solo.
library;

import '../dominio/calendario.dart';
import '../dominio/documenti.dart';
import '../dominio/giornate.dart';
import '../dominio/liste.dart';
import '../dominio/mappa.dart';
import '../dominio/periodo.dart';
import '../dominio/spese.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../dominio/valute.dart';
import 'database.dart';
import 'destinazioni.dart';

extension LetturaViaggio on Viaggio {
  DateTime? get inizio => leggiData(dataInizio);
  DateTime? get fine => leggiData(dataFine);
  Duration? get arrivo => leggiOra(oraArrivo);
  Duration? get partenza => leggiOra(oraPartenza);
  Periodo? get periodo => Periodo.leggi(periodoApprossimativo);

  /// Quando è nato sul server.
  DateTime get creato => DateTime.tryParse(creatoIl) ?? DateTime.now();

  StatoViaggio statoA(DateTime oggi) => statoDelViaggio(
    registrato: stato,
    inizio: inizio,
    fine: fine,
    oggi: oggi,
  );

  /// Il programma, se il viaggio ha date e orari.
  Programma? get programma {
    final (i, f, a, p) = (inizio, fine, arrivo, partenza);
    if (i == null || f == null || a == null || p == null) return null;
    return Programma(inizio: i, fine: f, arrivo: a, partenza: p);
  }

  /// L'ultimo giorno in cui l'idea è viva (02-il-viaggio.md, regola 5).
  DateTime get scadenza => scadenzaIdea(periodo: periodo, creataIl: creato);

  Destinazione? get destinazione {
    final citta = destinazioneCitta;
    final paese = destinazionePaese;
    if (citta != null) return Destinazione.aMano(citta, paese: paese);
    if (paese != null) {
      return Destinazione(
        tipo: TipoDestinazione.paese,
        nome: nomeDelPaese(paese) ?? paese,
        paese: paese,
      );
    }
    return null;
  }
}

extension LetturaGiorno on Giorno {
  FinestraGiorno get finestra => FinestraGiorno(
    data: leggiData(data)!,
    inizio: leggiOra(finestraInizio) ?? inizioGiornata,
    fine: leggiOra(finestraFine) ?? fineGiornata,
  );
}

extension LetturaTappa on Tappa {
  TipoTappa? get tipoTappa => TipoTappa.leggi(tipo);
  StatoTappa get statoTappa => StatoTappa.leggi(stato);
  Duration get durata => Duration(minutes: durataStimataMin);

  /// L'ora a cui comincia, se la si è detta.
  Duration? get ora => leggiOra(oraInizio);

  /// Dove sta; `null` se non ha un posto riconoscibile, e allora resta
  /// nell'itinerario ma non sulla mappa (08, casi limite).
  Coordinate? get posto => coordinate(lat, lon);
}

extension LetturaDocumento on Documento {
  FormatoDocumento get formatoDocumento => FormatoDocumento.leggi(formato);
  Sorgente get sorgenteDocumento => Sorgente.leggi(sorgente);

  /// A che ora serve, se si è detto.
  Duration? get momento => leggiOra(ora);
}

extension LetturaSpesa on Spesa {
  int get centesimi => centesimiDa(importo);

  /// Il giorno in cui è stata fatta.
  DateTime get giorno => leggiData(data) ?? soloData(DateTime.now());

  /// Quando è stata registrata.
  DateTime get registrata => DateTime.tryParse(creatoIl) ?? DateTime.now();

  /// Non ancora sul server: è in coda, e parte con la rete.
  bool get inCoda => versione == 0;

  VoceSpesa<Spesa> get voce => VoceSpesa(
    spesa: this,
    centesimi: centesimi,
    valuta: valuta,
    data: giorno,
    creataIl: registrata,
  );
}

extension LetturaVoce on VoceLista {
  /// Quando è nata sul server.
  DateTime get creata => DateTime.tryParse(creatoIl) ?? DateTime.now();

  VoceDaPortare<VoceLista> get daPortare =>
      VoceDaPortare(voce: this, id: id, spuntata: spuntata, creataIl: creata);
}

/// I tassi come li vuole il dominio: per valuta, quanto vale un euro.
Map<String, double> tassiPerEuro(Iterable<TassoCambio> tassi) => {
  for (final t in tassi)
    if (double.tryParse(t.perEuro) case final v? when v > 0) t.valuta: v,
};

/// Il giorno dei tassi: il più recente fra quelli sul telefono.
DateTime? giornoDeiTassi(Iterable<TassoCambio> tassi) {
  DateTime? ultimo;
  for (final t in tassi) {
    final d = leggiData(t.del);
    if (d != null && (ultimo == null || d.isAfter(ultimo))) ultimo = d;
  }
  return ultimo;
}
