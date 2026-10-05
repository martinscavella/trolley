/// L'itinerario con un assistente (04-itinerario.md, regole 7–14): la
/// richiesta che la persona porta sul suo assistente, e la lettura della
/// risposta che incolla indietro.
///
/// Le due metà stanno insieme perché sono le due facce dello stesso formato:
/// la richiesta lo descrive, la lettura lo capisce. Chi cambia l'una cambia
/// l'altra, e le prove le tengono d'accordo (test/dominio/itinerario_test.dart).
///
/// La lettura è tollerante (regola 10): chiacchiere prima e dopo, blocchi di
/// codice o testo semplice, tabelle, campi mancanti o in un altro ordine,
/// durate scritte in tanti modi. Si prende quello che si capisce, e si dice
/// quante righe non si sono capite invece di rifiutare tutto.
library;

import 'calendario.dart';
import 'giornate.dart';
import 'mappa.dart';
import 'tappe.dart';
import 'testo.dart';

// ─── La richiesta ─────────────────────────────────────────────────────────

/// La prima riga del blocco: dice che quello che segue è nel formato giusto.
const intestazioneItinerario = 'TROLLEY ITINERARIO';

/// Che ritmo deve avere il viaggio.
enum RitmoDelViaggio {
  tranquillo('Tranquillo', 'tranquillo: poche tappe al giorno, con calma'),
  equilibrato(
    'Equilibrato',
    'equilibrato: senza correre, ma senza tempi morti',
  ),
  intenso('Intenso', 'intenso: vedere il più possibile, giornate piene');

  const RitmoDelViaggio(this.nome, this.spiegazione);

  final String nome;

  /// Come lo legge l'assistente.
  final String spiegazione;
}

/// Che cosa piace a chi parte: facoltativo, e quanti se ne vuole.
enum Interesse {
  arte('Arte e musei'),
  cibo('Cibo'),
  storia('Storia'),
  natura('Natura'),
  panorami('Panorami'),
  shopping('Shopping'),
  vitaNotturna('Vita notturna');

  const Interesse(this.nome);

  final String nome;
}

/// Una tappa che c'è già, perché l'assistente non la ripeta.
typedef TappaPresente = ({String titolo, Duration durata});

/// Un giorno del viaggio come lo si chiede: il tempo che ha, e quello che c'è
/// già.
class GiornoDaChiedere {
  const GiornoDaChiedere(this.finestra, {this.presenti = const []});

  final FinestraGiorno finestra;
  final List<TappaPresente> presenti;
}

/// Tutto quello che entra nella richiesta (regola 7): destinazione, giorni,
/// orari e preferenze. Niente che dica chi è la persona.
class Richiesta {
  const Richiesta({
    required this.destinazione,
    required this.giorni,
    this.ritmo = RitmoDelViaggio.equilibrato,
    this.interessi = const {},
    this.altro,
  });

  /// Come si chiama il posto: `Porto, Portogallo`.
  final String destinazione;
  final List<GiornoDaChiedere> giorni;
  final RitmoDelViaggio ritmo;
  final Set<Interesse> interessi;

  /// Quello che la persona vuole aggiungere con parole sue.
  final String? altro;
}

/// La richiesta da portare sull'assistente: in italiano, con il formato della
/// risposta dentro un blocco di codice, così che il ritorno sia un tocco su
/// «Copia» e non una selezione fatta a dito (regola 8).
String scriviRichiesta(Richiesta r) {
  final giorni = r.giorni;
  final primo = giorni.first.finestra.data;
  final ultimo = giorni.last.finestra.data;
  final quando = primo == ultimo
      ? 'il ${_dataEstesa(primo)}'
      : 'dal ${_dataEstesa(primo)} al ${_dataEstesa(ultimo)}';
  final interessi = [
    for (final i in Interesse.values)
      if (r.interessi.contains(i)) i.nome.toLowerCase(),
  ];
  final altro = r.altro?.trim();
  final presenti = [
    for (final (i, g) in giorni.indexed)
      if (g.presenti.isNotEmpty)
        '- Giorno ${i + 1}: ${[for (final t in g.presenti) '${t.titolo} (${t.durata.inMinutes} min)'].join(', ')}',
  ];
  final esempio = giorni.first.finestra.data;
  return [
    'Prepara un itinerario per un viaggio a ${r.destinazione}, $quando.',
    '',
    'I giorni, con il tempo che c\'è:',
    for (final (i, g) in giorni.indexed)
      '- Giorno ${i + 1}, ${_dataEstesa(g.finestra.data, conGiorno: true)}: '
          '${_finestra(g.finestra)}',
    '',
    'RitmoDelViaggio: ${r.ritmo.spiegazione}.',
    if (interessi.isNotEmpty) 'Ci piacciono: ${interessi.join(', ')}.',
    if (altro != null && altro.isNotEmpty) 'Da tenere presente: $altro',
    if (presenti.isNotEmpty) ...[
      '',
      'Già in programma, da non ripetere e a cui lasciare il tempo:',
      ...presenti,
    ],
    '',
    'Proponi tappe realistiche, con durate credibili e i pasti alle ore giuste. '
        'Non riempire ogni minuto: lascia il tempo per spostarsi.',
    '',
    'Rispondi con l\'itinerario dentro un unico blocco di codice, esattamente '
        'in questo formato:',
    '',
    '```',
    intestazioneItinerario,
    'DESTINAZIONE: ${r.destinazione}',
    'GIORNO 1 · ${scriviData(esempio)}',
    '10:30 | Nome della tappa | visita | 90 | Via e numero | 41.14686, -8.61479',
    '13:00 | Nome del ristorante | pasto | 75 | Via e numero | 41.14522, -8.61131',
    '```',
    '',
    'Regole del formato:',
    '- una riga GIORNO per ogni giorno, con il numero e la data come sopra;',
    '- una riga per tappa: ora di inizio, nome, tipo, durata in minuti, '
        'indirizzo (o la zona), coordinate, separati da «|»;',
    '- le coordinate sono quelle del posto, latitudine e longitudine in '
        'gradi decimali con cinque decimali, separate da una virgola; se non '
        'sei sicuro del punto esatto lascia il campo vuoto: meglio vuoto che '
        'sbagliato;',
    '- il tipo è una di queste parole: '
        '${TipoTappa.values.map((t) => t.name).join(', ')};',
    '- nel blocco nient\'altro: consigli e spiegazioni, se vuoi, fuori dal '
        'blocco.',
  ].join('\n');
}

String _dataEstesa(DateTime d, {bool conGiorno = false}) => [
  if (conGiorno) nomiDeiGiorni[d.weekday - 1],
  '${d.day} ${nomiDeiMesi[d.month - 1]} ${d.year}',
].join(' ');

String _ora(Duration o) =>
    '${o.inHours.toString().padLeft(2, '0')}:'
    '${(o.inMinutes % 60).toString().padLeft(2, '0')}';

String _finestra(FinestraGiorno g) {
  final daMezzanotte = g.inizio == inizioGiornata;
  final finoAMezzanotte = g.fine >= fineGiornata;
  if (daMezzanotte && finoAMezzanotte) return 'giornata intera';
  if (finoAMezzanotte) return 'dalle ${_ora(g.inizio)}, all\'arrivo';
  if (daMezzanotte) return 'fino alle ${_ora(g.fine)}, alla partenza';
  return 'dalle ${_ora(g.inizio)} alle ${_ora(g.fine)}';
}

// ─── La risposta ──────────────────────────────────────────────────────────

/// Una tappa proposta dall'assistente, prima di entrare nel viaggio.
class TappaProposta {
  const TappaProposta({
    required this.titolo,
    required this.durata,
    this.tipo,
    this.ora,
    this.luogo,
    this.posto,
  });

  final String titolo;

  /// Senza durata scritta, quella proposta dal tipo: mai chiesta a vuoto
  /// (04, regola 2).
  final Duration durata;
  final TipoTappa? tipo;
  final Duration? ora;
  final String? luogo;

  /// Dove sta, se l'assistente l'ha detto. È una stima: prima di entrare
  /// nel viaggio si controlla che sia vicino alla meta ([postoPlausibile]).
  final Coordinate? posto;

  @override
  String toString() =>
      'TappaProposta($ora $titolo $tipo $durata $luogo $posto)';
}

/// Un giorno della risposta, riconosciuto dal numero, dalla data o da tutti e
/// due.
class GiornoProposto {
  GiornoProposto({this.numero, this.data});

  final int? numero;
  final DateTime? data;
  final tappe = <TappaProposta>[];
}

/// Quello che si è capito di una risposta.
class ItinerarioLetto {
  const ItinerarioLetto({
    required this.destinazione,
    required this.giorni,
    required this.righeNonCapite,
  });

  /// La destinazione che dice la risposta, se la dice.
  final String? destinazione;
  final List<GiornoProposto> giorni;

  /// Righe che sembravano tappe ma non si sono lette: si dicono, e restano
  /// nella nota.
  final int righeNonCapite;

  int get tappe => giorni.fold(0, (n, g) => n + g.tappe.length);

  /// Nessuna tappa: l'interpretazione non è riuscita (04, casi limite).
  bool get vuoto => tappe == 0;
}

/// Legge la risposta incollata. Se ci sono blocchi di codice con dentro un
/// itinerario legge quelli, se no tutto il testo.
ItinerarioLetto leggiItinerario(String testo) {
  final righe = _daLeggere(testo).split(RegExp(r'\r?\n'));
  String? destinazione;
  final giorni = <GiornoProposto>[];
  var nonCapite = 0;
  GiornoProposto? corrente;

  for (final grezza in righe) {
    final riga = _pulisci(grezza);
    if (riga.isEmpty) continue;
    if (normalizza(riga) == normalizza(intestazioneItinerario)) continue;

    final dest = _destinazione.firstMatch(riga);
    if (dest != null) {
      destinazione = dest.group(1)!.trim();
      continue;
    }

    final giorno = _leggiGiorno(riga);
    if (giorno != null) {
      giorni.add(corrente = giorno);
      continue;
    }

    final lettura = riga.contains('|')
        ? _tappaConBarre(riga)
        : _tappaConOra(riga);
    switch (lettura) {
      case _Tappa(:final tappa):
        if (corrente == null) giorni.add(corrente = GiornoProposto());
        corrente.tappe.add(tappa);
      case _NonCapita():
        nonCapite++;
      case _DaSaltare() || null:
        break;
    }
  }
  return ItinerarioLetto(
    destinazione: destinazione,
    giorni: [
      for (final g in giorni)
        if (g.tappe.isNotEmpty) g,
    ],
    righeNonCapite: nonCapite,
  );
}

/// Un blocco di codice, anche lasciato aperto da una risposta interrotta.
final _blocco = RegExp(r'```[^\n]*\n([\s\S]*?)(?:```|$)');

String _daLeggere(String testo) {
  final utili = [
    for (final m in _blocco.allMatches(testo))
      if (_sembraItinerario(m.group(1)!)) m.group(1)!,
  ];
  return utili.isEmpty ? testo : utili.join('\n');
}

bool _sembraItinerario(String blocco) => blocco
    .split('\n')
    .map(_pulisci)
    .any((r) => r.contains('|') || _leggiGiorno(r) != null);

/// Senza i segni di un elenco o di un titolo, senza grassetti.
String _pulisci(String riga) => riga
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll('`', '')
    .trim()
    .replaceFirst(RegExp(r'^(?:[-*•·>]+|\d{1,2}[.)])\s+'), '')
    .trim();

final _destinazione = RegExp(
  r'^(?:destinazione|destination|meta)\s*[:：]\s*(.+)$',
  caseSensitive: false,
);
final _numeroGiorno = RegExp(
  r'^#*\s*(?:giorno|giornata|day)\s*(\d{1,2})\b',
  caseSensitive: false,
);
final _dataIso = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');

/// Una riga che apre un giorno: «GIORNO 2 · 2026-10-11», «## Day 2», una data
/// da sola. Non una riga di tabella.
GiornoProposto? _leggiGiorno(String riga) {
  if (riga.contains('|')) return null;
  final numero = int.tryParse(_numeroGiorno.firstMatch(riga)?.group(1) ?? '');
  final iso = _dataIso.firstMatch(riga);
  final data = iso == null
      ? null
      : _dataValida(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
        );
  final soloData =
      data != null && riga.replaceAll(_dataIso, '').trim().length < 24;
  if (numero == null && !soloData) return null;
  return GiornoProposto(numero: numero, data: data);
}

DateTime? _dataValida(int anno, int mese, int giorno) {
  final d = DateTime.utc(anno, mese, giorno);
  return d.month == mese && d.day == giorno ? d : null;
}

sealed class _Lettura {}

class _Tappa extends _Lettura {
  _Tappa(this.tappa);
  final TappaProposta tappa;
}

/// Sembrava una tappa, ma non si è capita.
class _NonCapita extends _Lettura {}

/// Il separatore o l'intestazione di una tabella.
class _DaSaltare extends _Lettura {}

/// «10:30 | Livraria Lello | visita | 60 | Rua das Carmelitas», anche come
/// riga di una tabella, con i campi mancanti o in un altro ordine.
_Lettura _tappaConBarre(String riga) {
  final campi = [for (final c in riga.split('|')) c.trim()];
  if (campi.isNotEmpty && campi.first.isEmpty) campi.removeAt(0);
  if (campi.isNotEmpty && campi.last.isEmpty) campi.removeLast();
  if (campi.every((c) => c.isEmpty || RegExp(r'^:?-{2,}:?$').hasMatch(c))) {
    return _DaSaltare();
  }
  if (campi.every((c) => _intestazioni.contains(normalizza(c)))) {
    return _DaSaltare();
  }
  Duration? ora;
  if (campi.isNotEmpty && _leggiOra(campi.first) != null) {
    ora = _leggiOra(campi.removeAt(0));
  }
  return _componi(ora, campi);
}

/// «10:30 Livraria Lello (visita, 60 min)», «10:30 – Pranzo al mercato»: la
/// formattazione approssimativa di chi non ha rispettato il blocco.
_Lettura? _tappaConOra(String riga) {
  final m = RegExp(r'^(\d{1,2}[:.]\d{2})\s*(?:[-–—:]\s*)?(.*)$')
      .firstMatch(riga);
  if (m == null) return null;
  final ora = _leggiOra(m.group(1)!);
  if (ora == null) return null;
  var resto = m.group(2)!.trim();
  final campi = <String>[];
  // Quello fra parentesi alla fine: «(visita, 60 min)».
  final parentesi = RegExp(r'\(([^)]*)\)\s*$').firstMatch(resto);
  if (parentesi != null) {
    resto = resto.substring(0, parentesi.start).trim();
    campi.addAll(
      parentesi.group(1)!.split(RegExp(r'[,;]')).map((c) => c.trim()),
    );
  }
  final parti = resto.split(RegExp(r'\s+[–—-]\s+'));
  return _componi(ora, [...parti, ...campi]);
}

_Lettura _componi(Duration? ora, List<String> campi) {
  final restanti = [...campi];
  final titolo = restanti.isEmpty ? '' : restanti.removeAt(0);
  if (titolo.isEmpty || _leggiDurata(titolo) != null) return _NonCapita();
  // L'esempio della richiesta, incollato per sbaglio insieme alla risposta.
  if (_esempi.contains(normalizza(titolo))) return _DaSaltare();
  TipoTappa? tipo;
  Duration? durata;
  String? luogo;
  Coordinate? posto;
  for (var i = 0; i < restanti.length; i++) {
    final c = restanti[i];
    if (c.isEmpty) continue;
    if (posto == null) {
      // «41.14686, -8.61479» in un campo, o latitudine e longitudine in due.
      final coppia = _leggiCoordinate(c);
      if (coppia != null) {
        posto = coppia;
        continue;
      }
      final lat = _gradi(c);
      final lon = i + 1 < restanti.length ? _gradi(restanti[i + 1]) : null;
      if (lat != null && lon != null) {
        posto = coordinate(lat, lon);
        if (posto != null) {
          i++;
          continue;
        }
      }
    }
    if (tipo == null) {
      final t = _leggiTipo(c);
      if (t != null) {
        tipo = t;
        continue;
      }
    }
    if (durata == null) {
      final d = _leggiDurata(c);
      if (d != null) {
        durata = d;
        continue;
      }
    }
    if (ora == null) {
      final o = _leggiOra(c);
      if (o != null) {
        ora = o;
        continue;
      }
    }
    luogo ??= c;
  }
  tipo ??= _tipoDalNome(titolo);
  return _Tappa(
    TappaProposta(
      titolo: titolo.length > 120 ? titolo.substring(0, 120).trim() : titolo,
      tipo: tipo,
      durata: durata ?? (tipo ?? TipoTappa.altro).durataProposta,
      ora: ora,
      luogo: luogo,
      posto: posto,
    ),
  );
}

/// Un numero con almeno tre decimali, col punto: un grado, non una durata né
/// un'ora.
final _numeroGradi = RegExp(r'^-?\d{1,3}\.\d{3,}$');

double? _gradi(String campo) {
  final c = campo.trim().replaceAll('°', '');
  return _numeroGradi.hasMatch(c) ? double.parse(c) : null;
}

/// «41.14686, -8.61479», anche fra parentesi o con «;».
Coordinate? _leggiCoordinate(String campo) {
  final m = RegExp(
    r'^\(?\s*(-?\d{1,2}\.\d{3,})°?\s*[,;]\s*(-?\d{1,3}\.\d{3,})°?\s*\)?$',
  ).firstMatch(campo.trim());
  if (m == null) return null;
  return coordinate(double.parse(m.group(1)!), double.parse(m.group(2)!));
}

/// I nomi finti dell'esempio nella richiesta.
final _esempi = {
  normalizza('Nome della tappa'),
  normalizza('Nome del ristorante'),
};

const _intestazioni = {
  'ora',
  'orario',
  'time',
  'tappa',
  'nome',
  'attivita',
  'activity',
  'tipo',
  'type',
  'durata',
  'duration',
  'minuti',
  'luogo',
  'zona',
  'indirizzo',
  'dove',
  'place',
  'location',
};

/// `10:30`, `9.00`, `ore 21:15`.
Duration? _leggiOra(String campo) {
  final m = RegExp(
    r'^(?:ore\s+|h\s*)?(\d{1,2})[:.](\d{2})$',
    caseSensitive: false,
  ).firstMatch(campo.trim());
  if (m == null) return null;
  final ore = int.parse(m.group(1)!);
  final minuti = int.parse(m.group(2)!);
  if (ore > 23 || minuti > 59) return null;
  return Duration(hours: ore, minutes: minuti);
}

/// `90`, `90 min`, `1h30`, `1 h 30`, `2 ore`, `1,5 h`, `1:30`, «mezz'ora».
/// Fra un quarto d'ora e dodici ore: fuori di lì non è una durata credibile.
Duration? _leggiDurata(String campo) {
  final c = campo.trim().toLowerCase().replaceAll('’', '\'');
  int? minuti;
  if (RegExp(r"^mezz'?\s?ora$").hasMatch(c)) {
    minuti = 30;
  } else if (RegExp(r"^(\d{1,3})\s*(?:min|minuti|minutes|mins|m|')?\.?$")
          .firstMatch(c)
      case final m?) {
    minuti = int.parse(m.group(1)!);
  } else if (RegExp(
        r"^(\d{1,2})\s*(?:h|ora|ore|hr|hrs|hour|hours)\.?\s*(?:e\s*)?(\d{1,2})?\s*(?:min|minuti|m|')?\.?$",
      ).firstMatch(c)
      case final m?) {
    minuti = int.parse(m.group(1)!) * 60 + int.parse(m.group(2) ?? '0');
  } else if (RegExp(r'^(\d{1,2})[.,](\d)\s*(?:h|ore|ora|hours?)$').firstMatch(c)
      case final m?) {
    minuti = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!) * 6;
  } else if (RegExp(r'^(\d):(\d{2})$').firstMatch(c) case final m?) {
    // «1:30» dopo il nome è una durata; un orario ha due cifre per l'ora.
    minuti = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }
  if (minuti == null || minuti < 1 || minuti > 12 * 60) return null;
  return Duration(
    minutes: minuti < durataMinima.inMinutes ? durataMinima.inMinutes : minuti,
  );
}

const _sinonimi = {
  TipoTappa.visita: [
    'visita',
    'visit',
    'sightseeing',
    'monumento',
    'attrazione',
  ],
  TipoTappa.museo: ['museo', 'museum', 'galleria', 'gallery', 'mostra'],
  TipoTappa.pasto: [
    'pasto',
    'pranzo',
    'cena',
    'colazione',
    'brunch',
    'aperitivo',
    'meal',
    'lunch',
    'dinner',
    'breakfast',
    'ristorante',
  ],
  TipoTappa.passeggiata: ['passeggiata', 'walk', 'stroll', 'camminata'],
  TipoTappa.spettacolo: ['spettacolo', 'show', 'concerto', 'concert', 'teatro'],
  TipoTappa.escursione: ['escursione', 'excursion', 'gita', 'hike', 'trekking'],
  TipoTappa.pausa: ['pausa', 'break', 'riposo', 'relax', 'caffe', 'coffee'],
  TipoTappa.altro: ['altro', 'other', 'shopping'],
};

/// Un campo che è proprio un tipo: «visita», «Lunch».
TipoTappa? _leggiTipo(String campo) {
  final c = normalizza(campo);
  for (final MapEntry(key: tipo, value: parole) in _sinonimi.entries) {
    if (parole.contains(c)) return tipo;
  }
  return null;
}

/// Il tipo che si capisce dal nome, quando la risposta non lo dice: «Pranzo
/// al mercato» è un pasto. Solo le parole che non lasciano dubbi.
TipoTappa? _tipoDalNome(String titolo) {
  final parole = normalizza(titolo).split(' ').toSet();
  for (final (tipo, chiavi) in const [
    (TipoTappa.pasto, ['pranzo', 'cena', 'colazione', 'brunch', 'aperitivo']),
    (TipoTappa.museo, ['museo', 'galleria']),
    (TipoTappa.passeggiata, ['passeggiata']),
    (TipoTappa.escursione, ['escursione', 'gita']),
    (TipoTappa.spettacolo, ['spettacolo', 'concerto', 'teatro']),
    (TipoTappa.pausa, ['pausa']),
  ]) {
    if (chiavi.any(parole.contains)) return tipo;
  }
  return null;
}

// ─── Dalla risposta al viaggio ────────────────────────────────────────────

/// Le tappe proposte, giorno per giorno del viaggio.
class ItinerarioAbbinato {
  const ItinerarioAbbinato(this.perGiorno, {required this.fuoriDalViaggio});

  /// Una lista per giorno del viaggio, nello stesso ordine.
  final List<List<TappaProposta>> perGiorno;

  /// Tappe di giorni che il viaggio non ha.
  final int fuoriDalViaggio;
}

/// Mette ogni giorno della risposta sul giorno del viaggio: per data se c'è e
/// corrisponde, altrimenti per numero. Una risposta senza giorni va sul primo.
ItinerarioAbbinato abbinaAiGiorni(
  ItinerarioLetto letto,
  List<DateTime> giorniDelViaggio,
) {
  final date = [for (final d in giorniDelViaggio) soloData(d)];
  final perGiorno = [for (final _ in date) <TappaProposta>[]];
  var fuori = 0;
  for (final g in letto.giorni) {
    var i = g.data == null ? -1 : date.indexOf(soloData(g.data!));
    if (i < 0 && g.numero != null) i = g.numero! - 1;
    if (i < 0 && g.numero == null && g.data == null) i = 0;
    if (i < 0 || i >= date.length) {
      fuori += g.tappe.length;
    } else {
      perGiorno[i].addAll(g.tappe);
    }
  }
  return ItinerarioAbbinato(perGiorno, fuoriDalViaggio: fuori);
}

/// Quali proposte scegliere all'inizio: nell'ordine, finché entrano nel tempo
/// [libero] della giornata. Le altre restano fuori, e si vede (regola 14).
Set<int> sceltePerCapienza({
  required Duration libero,
  required List<Duration> durate,
  Set<int> escluse = const {},
}) {
  var resta = libero;
  final scelte = <int>{};
  for (final (i, d) in durate.indexed) {
    if (escluse.contains(i)) continue;
    if (d <= resta) {
      scelte.add(i);
      resta -= d;
    }
  }
  return scelte;
}

/// Se la risposta parla di un altro posto: capita riusando una richiesta
/// vecchia (04, casi limite). Senza una destinazione scritta, o in un viaggio
/// senza meta, non c'è niente da segnalare.
bool altraDestinazione(String? letta, Iterable<String?> nomiDelViaggio) {
  final l = normalizza(letta ?? '');
  final nomi = [
    for (final n in nomiDelViaggio)
      if (normalizza(n ?? '') case final x when x.isNotEmpty) x,
  ];
  if (l.isEmpty || nomi.isEmpty) return false;
  return !nomi.any((n) => l.contains(n) || n.contains(l));
}

/// Le proposte di un giorno che ci sono già: lo stesso nome di una tappa del
/// giorno, o di una proposta che viene prima. Incollare due volte la stessa
/// risposta non raddoppia la giornata. In giorni diversi lo stesso posto può
/// tornare (08, casi limite).
Set<int> giaNelGiorno(
  List<TappaProposta> proposte,
  Iterable<String> titoliDelGiorno,
) {
  final visti = {for (final t in titoliDelGiorno) normalizza(t)};
  return {
    for (final (i, p) in proposte.indexed)
      if (!visti.add(normalizza(p.titolo))) i,
  };
}

/// Quanto lontano dalla meta può stare un posto detto dall'assistente: una
/// gita in giornata ci sta, un'altra città no.
const raggioPlausibile = 150000.0;

/// Se le coordinate dette dall'assistente sono credibili: vicine alla meta o
/// alle tappe del viaggio. Senza un riferimento si prendono come sono.
/// Quelle lontane si scartano, e la tappa entra senza posto.
bool postoPlausibile(Coordinate posto, {Coordinate? vicinoA}) =>
    vicinoA == null || distanzaInMetri(posto, vicinoA) <= raggioPlausibile;
