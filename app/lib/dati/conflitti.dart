/// I conflitti come li vede l'app (02-sincronizzazione-e-offline.md §3): che
/// cosa, le due versioni, chi ha scritto quella già salvata e quando.
///
/// Le regole del confronto stanno in dominio/conflitti.dart. Qui ci sono i
/// **ritratti** delle quattro cose che possono trovarsi in due versioni — i
/// campi che la persona cambia, con i valori resi confrontabili — scritti nei
/// nomi del server, così da un ritratto si torna alla riga da mandare.
library;

import '../dominio/calendario.dart';
import '../dominio/conflitti.dart';
import '../dominio/valute.dart';
import 'database.dart';
import 'errori.dart';

/// Le cose che possono trovarsi in due versioni. Il nome è quello dell'evento
/// (07-misurazione.md): `conflitto_mostrato.tipo`.
enum CosaInConflitto {
  viaggio,
  tappa,
  spesa,
  voce;

  /// Le due versioni possono restare come due cose distinte: due voci sì,
  /// due tappe o due spese no (tela, 36).
  bool get divisibile => this == voce;
}

/// Il server ha rifiutato una scrittura fatta su una versione superata, e
/// l'altra versione cambia proprio quello che si voleva cambiare: si mostrano
/// le due e sceglie la persona. Finché non sceglie, quello che ha scritto
/// resta dov'era.
class Conflitto extends ErroreTrolley {
  Conflitto({
    required this.cosa,
    required this.id,
    required this.viaggioId,
    required this.mia,
    required this.loro,
    required this.versioneLoro,
    this.autoreId,
    this.salvataIl,
  }) : super(
         'Qualcuno l\'ha cambiata mentre la cambiavi tu: scegli quale '
         'versione tenere.',
         codice: CodiciServer.versioneSuperata,
       );

  final CosaInConflitto cosa;
  final String id;
  final String viaggioId;

  /// Quello che la persona voleva scrivere: non ancora salvato.
  final Map<String, Object?> mia;

  /// Com'è adesso sul server.
  final Map<String, Object?> loro;

  /// La versione del server: «Tieni la tua» scrive sopra questa.
  final int versioneLoro;

  /// Chi ha scritto la versione del server; `null` se il server non lo sa.
  final String? autoreId;

  /// Quando l'ha scritta.
  final DateTime? salvataIl;

  /// I campi in cui le due versioni non coincidono.
  Set<String> get diversi => campiDiversi(mia, loro);

  bool get tolta => eliminato(loro);
  bool get laTogli => eliminato(mia);

  /// Si possono tenere tutte e due, come due cose distinte.
  bool get possonoConvivere =>
      convivono(divisibile: cosa.divisibile, mia: mia, loro: loro);
}

/// Il ritratto di una tappa, da una riga nei nomi del server.
Map<String, Object?> ritrattoTappa(Map<String, Object?> r) => {
  'titolo': (r['titolo'] as String).trim(),
  'tipo': r['tipo'],
  'durata_stimata_min': r['durata_stimata_min'],
  'ora_inizio': _ora(r['ora_inizio']),
  'luogo_nome': _testo(r['luogo_nome']),
  // Il posto va col suo nome: si cambiano insieme, e si sceglie insieme.
  'lat': (r['lat'] as num?)?.toDouble(),
  'lon': (r['lon'] as num?)?.toDouble(),
  'giorno_id': r['giorno_id'],
  campoEliminato: r['eliminato_il'] != null,
};

/// Il ritratto di una spesa: l'importo in centesimi, perché `12.4` del server
/// e `12.40` del telefono sono la stessa cifra; chi ha pagato e per chi è.
Map<String, Object?> ritrattoSpesa(Map<String, Object?> r) => {
  'importo': centesimiDa('${r['importo']}'),
  'valuta': r['valuta'],
  'data': _data(r['data']),
  'descrizione': _testo(r['descrizione']),
  'pagante_id': r['pagante_id'],
  'quote': scriviQuote(leggiRigheQuote(r['quote'])),
  campoEliminato: r['eliminato_il'] != null,
};

/// Le quote di una riga, come le scrive il server: `[{utente_id, quota}]`.
Map<String, int> leggiRigheQuote(Object? righe) => {
  for (final q in (righe as List?) ?? const [])
    (q as Map)['utente_id'] as String: centesimiDa('${q['quota']}'),
};

/// Le quote nel ritratto: un testo, così due ritratti si confrontano.
/// `null` se non ce ne sono — una spesa di prima della divisione, o da soli.
String? scriviQuote(Map<String, int> quote) {
  if (quote.isEmpty) return null;
  final persone = quote.keys.toList()..sort();
  return [for (final p in persone) '$p:${quote[p]}'].join(',');
}

/// Dal testo del ritratto alle quote.
Map<String, int> leggiQuote(Object? testo) => {
  for (final parte in ((testo as String?) ?? '').split(','))
    if (parte.contains(':'))
      parte.substring(0, parte.lastIndexOf(':')): int.parse(
        parte.substring(parte.lastIndexOf(':') + 1),
      ),
};

/// Le quote come le vuole il server.
List<Map<String, Object?>> righeQuote(Map<String, int> quote) => [
  for (final MapEntry(key: utente, value: c) in quote.entries)
    {'utente_id': utente, 'quota': importoPerIlServer(c)},
];

/// Il ritratto di una voce: che cosa, quante, chi la porta. La spunta no:
/// spuntato è spuntato, chiunque l'abbia fatto (02 §2).
Map<String, Object?> ritrattoVoce(Map<String, Object?> r) => {
  'testo': (r['testo'] as String).trim(),
  'quantita': r['quantita'] ?? 1,
  'assegnato_a': r['assegnato_a'],
  campoEliminato: r['eliminato_il'] != null,
};

/// Il ritratto di un viaggio: quando si parte. Lo stato conta perché fissare
/// le date fa di un'idea un viaggio in programma, e tornare idea il contrario.
Map<String, Object?> ritrattoViaggio(Map<String, Object?> r) => {
  'stato': r['stato'],
  'periodo_approssimativo': r['periodo_approssimativo'],
  'data_inizio': _data(r['data_inizio']),
  'data_fine': _data(r['data_fine']),
  'ora_arrivo': _ora(r['ora_arrivo']),
  'ora_partenza': _ora(r['ora_partenza']),
};

/// Le righe del telefono nei nomi del server, per farne un ritratto.
Map<String, Object?> rigaDellaTappa(Tappa t) => {
  'titolo': t.titolo,
  'tipo': t.tipo,
  'durata_stimata_min': t.durataStimataMin,
  'ora_inizio': t.oraInizio,
  'luogo_nome': t.luogoNome,
  'lat': t.lat,
  'lon': t.lon,
  'giorno_id': t.giornoId,
  'eliminato_il': t.eliminatoIl,
};

Map<String, Object?> rigaDellaSpesa(Spesa s, Iterable<SpesaQuota> quote) => {
  'importo': s.importo,
  'valuta': s.valuta,
  'data': s.data,
  'descrizione': s.descrizione,
  'pagante_id': s.paganteId,
  'quote': [
    for (final q in quote)
      if (q.spesaId == s.id) {'utente_id': q.utenteId, 'quota': q.quota},
  ],
  'eliminato_il': s.eliminatoIl,
};

Map<String, Object?> rigaDellaVoce(VoceLista v) => {
  'testo': v.testo,
  'quantita': v.quantita,
  'assegnato_a': v.assegnatoA,
  'eliminato_il': v.eliminatoIl,
};

Map<String, Object?> rigaDelViaggio(Viaggio v) => {
  'stato': v.stato,
  'periodo_approssimativo': v.periodoApprossimativo,
  'data_inizio': v.dataInizio,
  'data_fine': v.dataFine,
  'ora_arrivo': v.oraArrivo,
  'ora_partenza': v.oraPartenza,
};

/// Dal ritratto alla riga da mandare, per i soli [campi]: togliere è
/// marcare `eliminato_il`, rimettere è vuotarlo; l'importo torna testo. Le
/// quote non sono una colonna: le manda a parte chi scrive la spesa.
Map<String, Object?> perIlServer(
  Map<String, Object?> ritratto,
  Iterable<String> campi, {
  DateTime? adesso,
}) => {
  for (final campo in campi)
    if (campo == campoEliminato)
      'eliminato_il': eliminato(ritratto)
          ? (adesso ?? DateTime.now()).toUtc().toIso8601String()
          : null
    else if (campo == 'importo')
      'importo': importoPerIlServer(ritratto[campo]! as int)
    else if (campo != 'quote')
      campo: ritratto[campo],
};

String? _testo(Object? v) {
  final t = (v as String?)?.trim();
  return t == null || t.isEmpty ? null : t;
}

String? _ora(Object? v) => switch (leggiOra(v as String?)) {
  final ora? => scriviOra(ora),
  null => null,
};

String? _data(Object? v) => switch (leggiData(v as String?)) {
  final data? => scriviData(data),
  null => null,
};
