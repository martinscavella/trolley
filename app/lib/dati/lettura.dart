/// Le righe della copia locale lette come le intende il dominio: date, orari,
/// periodo, stato. La copia tiene i valori nel formato del server; qui si
/// traducono, in un posto solo.
library;

import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/periodo.dart';
import '../dominio/stato_viaggio.dart';
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
