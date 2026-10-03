/// I documenti (07-documenti.md, 03-documenti-sul-dispositivo.md): che cosa si
/// può aggiungere, che nome proporre, in che ordine si mostrano.
///
/// L'ordine è la regola che conta: per primi i documenti di oggi, poi quelli di
/// domani, poi il resto (07, regola 5). Così la mattina della partenza la carta
/// d'imbarco è già in cima.
library;

import 'calendario.dart';

/// Che cosa è un file. Un PDF resta com'è; un'immagine si comprime (03, casi
/// da gestire).
enum FormatoDocumento {
  pdf,
  immagine;

  /// Come sta scritto nel database locale; un valore sconosciuto è un PDF.
  static FormatoDocumento leggi(String testo) =>
      testo == immagine.name ? immagine : pdf;
}

/// Da dove arriva un documento (07, "Aggiungi documento"): la scansione
/// diventa un PDF, le foto e i file restano quello che sono.
enum Sorgente {
  scansione,
  foto,
  file;

  static Sorgente leggi(String testo) =>
      values.where((s) => s.name == testo).firstOrNull ?? file;
}

/// Le estensioni che si possono aggiungere, per formato.
const estensioniPdf = {'pdf'};
const estensioniImmagine = {'jpg', 'jpeg', 'png', 'heic', 'heif'};

/// Il formato di un file dal suo nome. `null` se non è né un PDF né
/// un'immagine: non si aggiunge.
FormatoDocumento? formatoDi(String nomeFile) {
  final punto = nomeFile.lastIndexOf('.');
  if (punto < 0) return null;
  final estensione = nomeFile.substring(punto + 1).toLowerCase();
  if (estensioniPdf.contains(estensione)) return FormatoDocumento.pdf;
  if (estensioniImmagine.contains(estensione)) return FormatoDocumento.immagine;
  return null;
}

/// Quanto può essere lungo il nome di un documento.
const lunghezzaMassimaNome = 60;

/// Il nome proposto per un documento, da quello del file: senza estensione,
/// con gli spazi al posto di trattini e sottolineature, con la maiuscola.
/// `carta_imbarco-MXP.pdf` → `Carta imbarco MXP`. `null` se il file non ha un
/// nome che dica qualcosa: le foto e le scansioni hanno nomi di macchina.
String? nomeProposto(String? nomeFile) {
  if (nomeFile == null) return null;
  final punto = nomeFile.lastIndexOf('.');
  final base = (punto >= 0 ? nomeFile.substring(0, punto) : nomeFile)
      .replaceAll(RegExp(r'[_\-\s]+'), ' ')
      .trim();
  if (base.isEmpty || _nomeDiMacchina.hasMatch(base)) return null;
  final corto = base.length > lunghezzaMassimaNome
      ? base.substring(0, lunghezzaMassimaNome).trim()
      : base;
  return corto[0].toUpperCase() + corto.substring(1);
}

/// `IMG 1234`, `DOCUMENT SCAN 20261003 101500`, `image`, un identificativo:
/// nomi che il telefono dà ai file, non le persone.
final _nomeDiMacchina = RegExp(
  r'^(img|image|photo|foto|pxl|dsc|scan|document scan|screenshot)?[ \d]*$|'
  r'^[0-9a-f]{8}( [0-9a-f]{4}){3} [0-9a-f]{12}$',
  caseSensitive: false,
);

/// In che posto dell'elenco sta un gruppo di documenti.
enum TipoGruppo {
  /// Il giorno del viaggio che è oggi.
  oggi,

  /// Il giorno del viaggio che è domani.
  domani,

  /// I documenti senza giorno, e quelli il cui giorno non fa più parte del
  /// viaggio perché le date si sono spostate.
  tuttoIlViaggio,

  /// Un giorno che deve ancora venire, dopo domani.
  giorno,

  /// Un giorno già passato: in fondo.
  passato,
}

/// Un gruppo dell'elenco: i documenti di un giorno, o di tutto il viaggio.
class GruppoDocumenti<D> {
  const GruppoDocumenti(this.tipo, this.documenti, {this.data});

  final TipoGruppo tipo;

  /// La data del giorno. `null` per [TipoGruppo.tuttoIlViaggio].
  final DateTime? data;
  final List<D> documenti;
}

/// I documenti di un viaggio nell'ordine dell'elenco (07, regola 5): oggi,
/// domani, tutto il viaggio, i giorni che vengono, i giorni passati. Dentro un
/// giorno, quelli con l'ora nell'ordine dell'ora, poi quelli senza; a pari
/// merito, il più vecchio prima. I gruppi vuoti non ci sono.
///
/// [giorni] sono i giorni attivi del viaggio, per id; un documento agganciato
/// a un giorno che non c'è più vale per tutto il viaggio.
List<GruppoDocumenti<D>> raggruppaDocumenti<D>({
  required Iterable<D> documenti,
  required String? Function(D) giornoDi,
  required Duration? Function(D) oraDi,
  required DateTime Function(D) creatoDi,
  required Map<String, DateTime> giorni,
  required DateTime oggi,
}) {
  final giornoDiOggi = soloData(oggi);
  final domani = giornoDiOggi.add(const Duration(days: 1));
  final perData = <DateTime, List<D>>{};
  final senzaGiorno = <D>[];
  for (final d in documenti) {
    final data = giorni[giornoDi(d)];
    if (data == null) {
      senzaGiorno.add(d);
    } else {
      perData.putIfAbsent(soloData(data), () => []).add(d);
    }
  }

  int confronta(D a, D b) {
    final (oa, ob) = (oraDi(a), oraDi(b));
    if (oa != null && ob != null && oa != ob) return oa.compareTo(ob);
    if ((oa == null) != (ob == null)) return oa == null ? 1 : -1;
    return creatoDi(a).compareTo(creatoDi(b));
  }

  GruppoDocumenti<D> gruppo(TipoGruppo tipo, List<D> elenco, [DateTime? data]) =>
      GruppoDocumenti(tipo, elenco..sort(confronta), data: data);

  final date = perData.keys.toList()..sort();
  return [
    if (perData[giornoDiOggi] case final elenco?)
      gruppo(TipoGruppo.oggi, elenco, giornoDiOggi),
    if (perData[domani] case final elenco?)
      gruppo(TipoGruppo.domani, elenco, domani),
    if (senzaGiorno.isNotEmpty) gruppo(TipoGruppo.tuttoIlViaggio, senzaGiorno),
    for (final data in date)
      if (data.isAfter(domani)) gruppo(TipoGruppo.giorno, perData[data]!, data),
    for (final data in date)
      if (data.isBefore(giornoDiOggi))
        gruppo(TipoGruppo.passato, perData[data]!, data),
  ];
}

/// Quanti documenti mostrare nella schermata del viaggio, se non sono di oggi.
const documentiInVista = 3;

/// I documenti da avere a un tocco dalla schermata del viaggio (07, regola 6):
/// tutti quelli di oggi; se oggi non ne ha, i primi [documentiInVista]
/// dell'elenco, lasciando fuori i giorni passati.
List<D> documentiDaTenereInVista<D>(List<GruppoDocumenti<D>> gruppi) {
  final oggi = gruppi.where((g) => g.tipo == TipoGruppo.oggi).firstOrNull;
  if (oggi != null) return oggi.documenti;
  return [
    for (final g in gruppi)
      if (g.tipo != TipoGruppo.passato) ...g.documenti,
  ].take(documentiInVista).toList();
}
