/// Due versioni della stessa cosa (02-sincronizzazione-e-offline.md §3;
/// decisioni/prodotto.md, «Conflitti mostrati, non risolti di nascosto»).
///
/// Un conflitto nasce solo fra due persone online che cambiano la stessa cosa:
/// il server rifiuta la scrittura fatta su una versione superata, e qui si
/// decide se c'è davvero qualcosa da scegliere. Le versioni sono **ritratti**:
/// i soli campi che la persona può cambiare, con i valori già confrontabili,
/// più `eliminato`. Quello che si cambia con i gesti — segnare una tappa,
/// spuntare una voce, riordinare — non sta nel ritratto, e non fa mai nascere
/// un conflitto.
library;

/// Nel ritratto: la cosa è stata tolta.
const campoEliminato = 'eliminato';

/// Com'è andato il confronto fra quello che si voleva scrivere e quello che
/// il server ha adesso.
enum EsitoConfronto {
  /// Le due versioni dicono la stessa cosa: non c'è niente da scegliere.
  uguali,

  /// L'altro non ha toccato niente di quello che si cambia qui: si riscrive
  /// sulla versione nuova senza chiedere niente a nessuno.
  nienteInComune,

  /// L'altro ha cambiato la stessa cosa: si mostrano le due versioni, e
  /// sceglie la persona. Mai una fusione: anche quando i due hanno cambiato
  /// campi diversi, unirli darebbe una versione che nessuno ha visto.
  dueVersioni,
}

/// Confronta [mia] (quello che si voleva scrivere) con [loro] (com'è adesso
/// sul server), sapendo da quale versione [base] si era partiti.
EsitoConfronto confronta({
  required Map<String, Object?> base,
  required Map<String, Object?> mia,
  required Map<String, Object?> loro,
}) {
  // Tolta da tutti e due: è tolta, comunque fosse prima.
  if (eliminato(mia) && eliminato(loro)) return EsitoConfronto.uguali;
  if (campiDiversi(mia, loro).isEmpty) return EsitoConfronto.uguali;
  if (campiDiversi(base, loro).isEmpty) return EsitoConfronto.nienteInComune;
  return EsitoConfronto.dueVersioni;
}

/// I campi in cui due ritratti non coincidono, nell'ordine del primo.
Set<String> campiDiversi(Map<String, Object?> a, Map<String, Object?> b) => {
  for (final campo in {...a.keys, ...b.keys})
    if (a[campo] != b[campo]) campo,
};

/// Il ritratto dice che la cosa è stata tolta.
bool eliminato(Map<String, Object?> ritratto) =>
    ritratto[campoEliminato] == true;

/// Le due versioni possono stare insieme come due cose distinte: due voci
/// della lista, due note. Una tappa o una spesa no — la cena da 42 o da 48
/// euro è una cena sola, e tenerle tutte e due la conterebbe due volte — e
/// nemmeno una cosa tolta.
bool convivono({
  required bool divisibile,
  required Map<String, Object?> mia,
  required Map<String, Object?> loro,
}) => divisibile && !eliminato(mia) && !eliminato(loro);
