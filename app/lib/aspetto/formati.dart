/// Come si scrivono date, nomi e stati nell'interfaccia.
library;

import 'package:flutter/widgets.dart' show StringCharacters;

import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/documenti.dart';
import '../dominio/giornate.dart';
import '../dominio/periodo.dart';
import '../dominio/spese.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../dominio/testo.dart';
import '../dominio/valute.dart';

/// `12 ottobre 2026`.
String dataEstesa(DateTime d) =>
    '${d.day} ${nomiDeiMesi[d.month - 1]} ${d.year}';

/// L'intervallo più corto che non lascia dubbi:
/// `10–12 ottobre 2026`, `28 ottobre – 3 novembre 2026`,
/// `30 dicembre 2026 – 2 gennaio 2027`.
String intervalloDate(DateTime inizio, DateTime fine) {
  if (inizio.year != fine.year) {
    return '${dataEstesa(inizio)} – ${dataEstesa(fine)}';
  }
  if (inizio.month != fine.month) {
    return '${inizio.day} ${nomiDeiMesi[inizio.month - 1]} – ${dataEstesa(fine)}';
  }
  if (inizio.day != fine.day) {
    return '${inizio.day}–${dataEstesa(fine)}';
  }
  return dataEstesa(inizio);
}

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

/// Il titolo di un viaggio: la città, oppure il paese se si va in un paese
/// intero.
String titoloViaggio(Viaggio v) =>
    v.destinazioneCitta ??
    nomeDelPaese(v.destinazionePaese) ??
    'Viaggio senza meta';

/// Il codice di tre lettere sul biglietto: le prime della destinazione, senza
/// accenti né spazi. `Lisbona` → `LIS`, `Città del Messico` → `CIT`. Senza
/// meta, `?`.
String codiceDestinazione(String? nome) {
  final lettere = normalizza(nome ?? '').replaceAll(' ', '').characters;
  if (lettere.isEmpty) return '?';
  return lettere.take(3).toString().toUpperCase();
}

/// Il codice del biglietto di un viaggio.
String codiceViaggio(Viaggio v) => codiceDestinazione(
  v.destinazioneCitta ?? nomeDelPaese(v.destinazionePaese),
);

/// `12 mag`.
String dataBreve(DateTime d) => '${d.day} ${meseBreve(d)}';

/// Il nome dello stato, come compare sull'etichetta del viaggio e sulle
/// sezioni dell'elenco (02-il-viaggio.md, "Elenco viaggi").
String descrizioneStato(StatoViaggio stato) => switch (stato) {
  StatoViaggio.idea => 'Idea',
  StatoViaggio.definito => 'In programma',
  StatoViaggio.inCorso => 'In corso',
  StatoViaggio.chiuso => 'Concluso',
  StatoViaggio.archiviato => 'In archivio',
};

/// `agosto 2027` → `Agosto 2027`.
String conMaiuscola(String testo) => testo.isEmpty
    ? testo
    : '${testo.characters.first.toUpperCase()}${testo.characters.skip(1)}';

/// Quando: le date se ci sono, altrimenti il periodo.
String quandoViaggio(Viaggio v) {
  final (inizio, fine) = (v.inizio, v.fine);
  if (inizio != null && fine != null) return intervalloDate(inizio, fine);
  final periodo = v.periodoApprossimativo;
  return periodo == null ? 'Date da decidere' : conMaiuscola(periodo);
}

/// Un periodo detto nel modo più corto che non lascia dubbi rispetto a
/// [oggi]: `Novembre`, `Gennaio 2027`, `Autunno`, `Inverno 2026–27`.
String etichettaPeriodo(Periodo periodo, DateTime oggi) {
  final nome = conMaiuscola(periodo.testo);
  return switch (periodo) {
    MeseDi(:final anno) when anno == oggi.year => nome.substring(
      0,
      nome.lastIndexOf(' '),
    ),
    StagioneDi(:final anno, :final stagione)
        when anno == oggi.year && stagione != Stagione.inverno =>
      nome.substring(0, nome.lastIndexOf(' ')),
    _ => nome,
  };
}

/// `sabato`.
String giornoDellaSettimana(DateTime d) => nomiDeiGiorni[d.weekday - 1];

/// `ott`.
String meseBreve(DateTime d) => nomiDeiMesi[d.month - 1].substring(0, 3);

/// `10:00`. La fine del giorno è mezzanotte.
String ora(Duration o) => o >= const Duration(hours: 24)
    ? 'mezzanotte'
    : '${o.inHours.toString().padLeft(2, '0')}:'
          '${(o.inMinutes % 60).toString().padLeft(2, '0')}';

/// `14 h`, `13 h 30 min`, `45 min`.
String durata(Duration d) {
  final (ore, minuti) = (d.inHours, d.inMinutes % 60);
  if (ore == 0) return '$minuti min';
  if (minuti == 0) return '$ore h';
  return '$ore h $minuti min';
}

/// Corta, per la matrice di un biglietto o una riga stretta: `2 h`, `1 h 30`,
/// `45 min`.
String durataBreve(Duration d) {
  final (ore, minuti) = (d.inHours, d.inMinutes % 60);
  if (ore == 0) return '$minuti min';
  if (minuti == 0) return '$ore h';
  return '$ore h ${minuti.toString().padLeft(2, '0')}';
}

/// Il nome di un tipo di tappa: `Visita`, `Passeggiata`.
String nomeTipo(TipoTappa tipo) => switch (tipo) {
  TipoTappa.visita => 'Visita',
  TipoTappa.museo => 'Museo',
  TipoTappa.pasto => 'Pasto',
  TipoTappa.passeggiata => 'Passeggiata',
  TipoTappa.spettacolo => 'Spettacolo',
  TipoTappa.escursione => 'Escursione',
  TipoTappa.pausa => 'Pausa',
  TipoTappa.altro => 'Altro',
};

/// Con l'articolo, per dire di chi è la proposta: `una visita`, `un'escursione`.
String unTipo(TipoTappa tipo) => switch (tipo) {
  TipoTappa.visita => 'una visita',
  TipoTappa.museo => 'un museo',
  TipoTappa.pasto => 'un pasto',
  TipoTappa.passeggiata => 'una passeggiata',
  TipoTappa.spettacolo => 'uno spettacolo',
  TipoTappa.escursione => 'un\'escursione',
  TipoTappa.pausa => 'una pausa',
  TipoTappa.altro => 'una tappa',
};

/// Un giorno del viaggio per intero: `Sabato 11 ottobre`.
String nomeDelGiorno(DateTime d) =>
    '${conMaiuscola(giornoDellaSettimana(d))} ${d.day} '
    '${nomiDeiMesi[d.month - 1]}';

/// Un giorno del viaggio in breve, per una scelta: `Sabato 11`.
String giornoBreve(DateTime d) =>
    '${conMaiuscola(giornoDellaSettimana(d))} ${d.day}';

/// Un giorno ancora più in breve, per una capsula: `Sab 11`.
String giornoCorto(DateTime d) =>
    '${conMaiuscola(giornoDellaSettimana(d).substring(0, 3))} ${d.day}';

/// Quanto dura una giornata del viaggio, a parole: `dalle 10:00`, `fino alle
/// 18:00`, `dalle 10:00 alle 18:00`, `tutto il giorno`.
String finestraDelGiorno(FinestraGiorno g) {
  final daInizio = g.inizio == inizioGiornata;
  final finoAllaFine = g.fine >= fineGiornata;
  if (daInizio && finoAllaFine) return 'tutto il giorno';
  if (finoAllaFine) return 'dalle ${ora(g.inizio)}';
  if (daInizio) return 'fino alle ${ora(g.fine)}';
  return 'dalle ${ora(g.inizio)} alle ${ora(g.fine)}';
}

/// Il programma in una riga: `3 giorni · arrivi alle 10:00, riparti alle 18:00`.
String riassuntoProgramma(Programma p) => [
  quanti(p.durataGiorni, 'giorno', 'giorni'),
  'arrivi alle ${ora(p.arrivo)}, riparti alle ${ora(p.partenza)}',
].join(' · ');

/// Il titolo della sezione dell'elenco che raccoglie i viaggi in [stato].
String titoloSezione(StatoViaggio stato) => switch (stato) {
  StatoViaggio.idea => 'Idee',
  StatoViaggio.chiuso => 'Conclusi',
  _ => descrizioneStato(stato),
};

/// Quanto tempo fa, detto come lo si dice: `poco fa`, `5 minuti fa`, `3 ore
/// fa`, `ieri`, `4 giorni fa`.
String quantoFa(DateTime quando, DateTime adesso) {
  final passato = adesso.difference(quando);
  if (passato.inMinutes < 2) return 'poco fa';
  if (passato.inHours < 1) return '${passato.inMinutes} minuti fa';
  if (passato.inHours < 24) {
    return passato.inHours == 1 ? 'un\'ora fa' : '${passato.inHours} ore fa';
  }
  final giorni = soloData(adesso.toLocal())
      .difference(soloData(quando.toLocal()))
      .inDays;
  return giorni <= 1 ? 'ieri' : '$giorni giorni fa';
}

/// Quando è stata aggiornata la copia, per chi deve fidarsene: `oggi alle
/// 22:10`, `ieri alle 09:05`, `il 3 ottobre alle 22:10`, `l'8 ottobre alle
/// 07:30`.
String quandoAggiornato(DateTime quando, DateTime adesso) {
  final locale = quando.toLocal();
  final giorni = soloData(adesso.toLocal()).difference(soloData(locale)).inDays;
  final alle =
      'alle ${ora(Duration(hours: locale.hour, minutes: locale.minute))}';
  if (giorni <= 0) return 'oggi $alle';
  if (giorni == 1) return 'ieri $alle';
  final apostrofo = locale.day == 1 || locale.day == 8 || locale.day == 11;
  return '${apostrofo ? 'l\'' : 'il '}${locale.day} '
      '${nomiDeiMesi[locale.month - 1]} $alle';
}

/// Che cos'è un documento, in breve: `PDF · 2 pagine`, `Scansione`, `Foto`.
String dettaglioDocumento({
  required FormatoDocumento formato,
  required Sorgente sorgente,
  int? pagine,
}) {
  final cosa = switch (sorgente) {
    Sorgente.scansione => 'Scansione',
    Sorgente.foto => 'Foto',
    Sorgente.file => formato == FormatoDocumento.pdf ? 'PDF' : 'Immagine',
  };
  return pagine != null && pagine > 1 ? '$cosa · $pagine pagine' : cosa;
}

/// Il titolo di un gruppo dell'elenco dei documenti: `OGGI · VENERDÌ 10`,
/// `PER TUTTO IL VIAGGIO`, `DOMENICA 12 OTTOBRE`.
String titoloGruppo(TipoGruppo tipo, DateTime? data) => switch (tipo) {
  TipoGruppo.oggi => 'Oggi · ${giornoBreve(data!)}',
  TipoGruppo.domani => 'Domani · ${giornoBreve(data!)}',
  TipoGruppo.tuttoIlViaggio => 'Per tutto il viaggio',
  TipoGruppo.giorno || TipoGruppo.passato => nomeDelGiorno(data!),
}.toUpperCase();

/// Quando serve un documento, detto rispetto a [oggi]: `Oggi alle 07:05`,
/// `Domani`, `Sabato 11 ottobre alle 10:00`, `Per tutto il viaggio`.
String quandoServe({DateTime? data, Duration? alle, required DateTime oggi}) {
  if (data == null) return 'Per tutto il viaggio';
  final distanza = soloData(data).difference(soloData(oggi)).inDays;
  final giorno = switch (distanza) {
    0 => 'Oggi',
    1 => 'Domani',
    _ => nomeDelGiorno(data),
  };
  return alle == null ? giorno : '$giorno alle ${ora(alle)}';
}

// ─── Spese ──────────────────────────────────────────────────────────────────

/// `del 2 ottobre`, `dell'8 ottobre`: con l'articolo giusto davanti al numero.
String delGiorno(DateTime d) {
  final apostrofo = d.day == 1 || d.day == 8 || d.day == 11;
  return '${apostrofo ? 'dell\'' : 'del '}${d.day} ${nomiDeiMesi[d.month - 1]}';
}

/// Di quando sono i tassi, per chi legge una conversione: `tassi di oggi`,
/// `tassi di ieri, 2 ottobre`, `tassi del 28 settembre`. Una conversione senza
/// la sua data è una bugia (01-modello-dati.md).
String quandoITassi(DateTime? del, DateTime oggi) {
  if (del == null) return 'nessun tasso ancora';
  final giorni = soloData(oggi).difference(soloData(del)).inDays;
  if (giorni <= 0) return 'tassi di oggi';
  if (giorni == 1) {
    return 'tassi di ieri, ${del.day} ${nomiDeiMesi[del.month - 1]}';
  }
  return 'tassi ${delGiorno(del)}';
}

/// Il titolo di un gruppo dell'elenco delle spese: `OGGI · VENERDÌ 10`,
/// `IERI · GIOVEDÌ 9`, `SABATO 11`, `PRIMA DEL VIAGGIO`.
String titoloGruppoSpese(TipoGruppoSpese tipo, DateTime? data, DateTime oggi) {
  final testo = switch (tipo) {
    TipoGruppoSpese.prima => 'Prima del viaggio',
    TipoGruppoSpese.dopo => 'Dopo il viaggio',
    TipoGruppoSpese.giorno => switch (soloData(oggi)
        .difference(soloData(data!))
        .inDays) {
      0 => 'Oggi · ${giornoBreve(data)}',
      1 => 'Ieri · ${giornoBreve(data)}',
      _ => giornoBreve(data),
    },
  };
  return testo.toUpperCase();
}

/// Il nome corto di una valuta, per una capsula o una frase: `Dirham`,
/// `Euro`, `Franco CFA`.
String nomeCortoValuta(String codice) {
  final nome = valutaDi(codice).nome;
  if (nome.startsWith('Franco CFA')) return 'Franco CFA';
  return nome.split(' ').first;
}

/// Il simbolo con cui una valuta compare accanto a un importo: `€`, `MAD`.
String simboloValuta(String codice) => codice == 'EUR' ? '€' : codice;

/// Una distanza a piedi, arrotondata come la dice chi indica la strada:
/// `35 m`, `120 m`, `1,2 km`, `12 km`.
String distanza(double metri) {
  if (metri < 100) return '${(metri / 5).round() * 5} m';
  if (metri < 995) return '${(metri / 10).round() * 10} m';
  if (metri < 9950) {
    return '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${(metri / 1000).round()} km';
}

/// Quanto ci si mette a piedi: `1 min`, `6 min`, `1 h 05`.
String tempoAPiedi(Duration d) {
  final minuti = (d.inSeconds / 60).round();
  return durataBreve(Duration(minutes: minuti < 1 ? 1 : minuti));
}

/// Un intervallo corto, per una riga stretta: `20–22 nov`, `30 nov – 2 dic`.
String intervalloBreve(DateTime inizio, DateTime fine) {
  if (inizio.year == fine.year && inizio.month == fine.month) {
    return inizio.day == fine.day
        ? dataBreve(inizio)
        : '${inizio.day}–${fine.day} ${meseBreve(fine)}';
  }
  return '${dataBreve(inizio)} – ${dataBreve(fine)}';
}
