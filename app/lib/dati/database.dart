/// Il database sul telefono (ADR-002, 02-sincronizzazione-e-offline.md).
///
/// Contiene quattro cose di natura diversa:
/// - la **copia di lettura** dei dati del server: si può buttare e riscaricare;
/// - la **coda di scrittura** dei quattro gesti fatti senza rete: esiste solo qui,
///   ed è preziosa;
/// - l'**indice dei documenti**: i file stanno nella cartella dei documenti, qui
///   c'è che cosa sono. Esiste solo qui, ed è prezioso come la coda (03);
/// - gli **eventi di misurazione** in attesa di partire: esistono solo qui.
///
/// Le colonne hanno gli stessi nomi del server (Drift le scrive in snake_case), così
/// scaricare è tradurre righe, non concetti. Date e orari restano testo nel formato
/// del server (`2026-10-10`, `10:00:00`) per non introdurre fusi orari.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ─── Copia di lettura ─────────────────────────────────────────────────────

/// Colonne comuni alle righe copiate dal server.
mixin RigaCopiata on Table {
  TextColumn get id => text()();
  IntColumn get versione => integer()();
  TextColumn get eliminatoIl => text().nullable()();

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  DateTimeColumn get scaricatoIl => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Utente')
class Utenti extends Table with RigaCopiata {
  @override
  String get tableName => 'utente';

  TextColumn get nome => text()();

  /// Solo per il proprio profilo: degli altri il server manda solo il nome.
  TextColumn get dataNascita => text().nullable()();
  TextColumn get valutaPredefinita => text().nullable()();
}

@DataClassName('Viaggio')
class Viaggi extends Table with RigaCopiata {
  @override
  String get tableName => 'viaggio';

  TextColumn get stato => text()();
  TextColumn get destinazioneCitta => text().nullable()();
  TextColumn get destinazionePaese => text().nullable()();
  TextColumn get periodoApprossimativo => text().nullable()();
  TextColumn get dataInizio => text().nullable()();
  TextColumn get dataFine => text().nullable()();
  TextColumn get oraArrivo => text().nullable()();
  TextColumn get oraPartenza => text().nullable()();
  TextColumn get creatoreId => text()();
  BoolColumn get importato => boolean()();
  BoolColumn get verificato => boolean()();

  /// Quanti giorni è durato un viaggio importato, se la persona se lo
  /// ricorda: date e orari non li sa (fase 4.3).
  IntColumn get giorniRicordati => integer().nullable()();

  /// La deroga amministrativa sulla verifica: vale come sul posto, e toglie
  /// il viaggio da ogni metrica (02, regola 8). La scrive solo chi gestisce
  /// il progetto.
  BoolColumn get verificaPerDeroga =>
      boolean().withDefault(const Constant(false))();
  TextColumn get creatoIl => text()();
}

@DataClassName('Partecipazione')
class Partecipazioni extends Table with RigaCopiata {
  @override
  String get tableName => 'partecipazione';

  TextColumn get viaggioId => text()();
  TextColumn get utenteId => text()();
  TextColumn get ruolo => text()();
  TextColumn get stato => text()();

  /// Quando è entrato nel viaggio: una spesa registrata prima della 2.3,
  /// senza quote, si divide fra chi c'era (decisioni/prodotto.md).
  TextColumn get creatoIl => text().nullable()();

  /// L'ultima volta che la partecipazione è cambiata: per chi è uscito, più o
  /// meno quando è uscito.
  TextColumn get modificatoIl => text().nullable()();

  /// Quando il suo telefono l'ha trovato sul posto, mentre il viaggio era in
  /// corso: una delle tre condizioni della verifica. Mai dove (fase 3.4).
  TextColumn get sulPostoIl => text().nullable()();

  /// Se il viaggio, chiuso, è verificato per questa persona; `null` finché
  /// non si è chiuso per lei (fase 4.1).
  BoolColumn get verificato => boolean().nullable()();
}

@DataClassName('Giorno')
class Giorni extends Table with RigaCopiata {
  @override
  String get tableName => 'giorno';

  TextColumn get viaggioId => text()();
  TextColumn get data => text()();
  TextColumn get finestraInizio => text()();
  TextColumn get finestraFine => text()();
}

@DataClassName('Tappa')
class Tappe extends Table with RigaCopiata {
  @override
  String get tableName => 'tappa';

  TextColumn get viaggioId => text()();
  TextColumn get giornoId => text()();
  IntColumn get ordine => integer()();
  TextColumn get titolo => text()();
  TextColumn get luogoNome => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  IntColumn get durataStimataMin => integer()();
  TextColumn get oraInizio => text().nullable()();
  TextColumn get stato => text()();
  TextColumn get marcataIl => text().nullable()();
  BoolColumn get marcataDuranteIlViaggio => boolean()();
  BoolColumn get eccedente => boolean()();

  /// Facoltativo: le tappe incollate da un itinerario (1.6) possono non averlo.
  TextColumn get tipo => text().nullable()();

  /// Chi l'ha aggiunta: il primo contributo di un invitato si riconosce così.
  TextColumn get creatoDa => text()();

  /// A pari ordine, due tappe aggiunte insieme da due telefoni si mettono in
  /// fila per quando sono nate.
  TextColumn get creatoIl => text()();
}

@DataClassName('Spesa')
class Spese extends Table with RigaCopiata {
  @override
  String get tableName => 'spesa';

  TextColumn get viaggioId => text()();

  /// Testo e non numero: l'importo nella valuta originale è il dato vero,
  /// e un double lo arrotonderebbe.
  TextColumn get importo => text()();
  TextColumn get valuta => text()();
  TextColumn get tassoUsato => text().nullable()();
  TextColumn get tassoAl => text().nullable()();
  TextColumn get paganteId => text()();
  TextColumn get data => text()();
  TextColumn get descrizione => text().nullable()();

  /// Chi l'ha registrata: il primo contributo di un invitato si riconosce così.
  TextColumn get creatoDa => text()();

  /// A pari data, l'ultima registrata va in cima.
  TextColumn get creatoIl => text()();

  /// Un rimborso: chi dà i soldi l'ha «pagato», chi li riceve ne ha tutta la
  /// quota. Chiude un saldo, e il totale del viaggio lo lascia fuori.
  BoolColumn get rimborso => boolean().withDefault(const Constant(false))();
}

@DataClassName('SpesaQuota')
class SpeseQuote extends Table with RigaCopiata {
  @override
  String get tableName => 'spesa_quota';

  TextColumn get viaggioId => text()();
  TextColumn get spesaId => text()();
  TextColumn get utenteId => text()();
  TextColumn get quota => text()();
}

@DataClassName('VoceLista')
class VociLista extends Table with RigaCopiata {
  @override
  String get tableName => 'voce_lista';

  TextColumn get viaggioId => text()();
  TextColumn get testo => text()();

  /// Quanti pezzi: cinque magliette sono una voce sola (05, schermate).
  IntColumn get quantita => integer()();
  TextColumn get tipo => text()();
  TextColumn get proprietarioId => text()();
  TextColumn get assegnatoA => text().nullable()();

  /// Chi la portava quando ha lasciato il viaggio: l'avviso delle voci
  /// tornate libere (05, casi limite). Lo scrive solo il server.
  TextColumn get lasciataDa => text().nullable()();
  BoolColumn get spuntata => boolean()();

  /// Chi l'ha aggiunta: il primo contributo di un invitato si riconosce così.
  TextColumn get creatoDa => text()();

  /// La lista va nell'ordine in cui le voci sono nate.
  TextColumn get creatoIl => text()();
}

/// Una nota del viaggio: per ora la risposta di un assistente, incollata e
/// salvata sempre, anche quando non si capisce (04, regola 11).
@DataClassName('Nota')
class Note extends Table with RigaCopiata {
  @override
  String get tableName => 'nota';

  TextColumn get viaggioId => text()();
  TextColumn get testo => text()();

  /// `incollata` o `scritta`.
  TextColumn get origine => text()();
  TextColumn get creatoDa => text()();
  TextColumn get creatoIl => text()();
}

/// I propri traguardi (10-chiusura-e-ricordo.md; dominio/traguardi.dart):
/// uno per tipo, con il viaggio che l'ha dato. Una copia come le altre: si
/// guardano anche senza rete.
@DataClassName('TraguardoPreso')
class Traguardi extends Table {
  @override
  String get tableName => 'traguardo';

  TextColumn get id => text()();
  TextColumn get tipo => text()();
  TextColumn get viaggioId => text()();
  TextColumn get presoIl => text()();
  DateTimeColumn get scaricatoIl => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Quello che si cambia dal server senza un rilascio: i modelli da consigliare
/// (decisioni/prodotto.md, "Quali modelli suggerire"). Il valore è il JSON
/// del server, com'è.
@DataClassName('Configurazione')
class Configurazioni extends Table {
  @override
  String get tableName => 'configurazione';

  TextColumn get chiave => text()();
  TextColumn get valore => text()();
  DateTimeColumn get scaricatoIl => dateTime()();

  @override
  Set<Column> get primaryKey => {chiave};
}

/// L'ultimo tasso noto per ogni valuta, rispetto all'euro (ADR-009). Una
/// copia come le altre: senza rete si usa questa, e si dice di quando è
/// (06, regola 6).
@DataClassName('TassoCambio')
class TassiCambio extends Table {
  @override
  String get tableName => 'tasso_cambio';

  TextColumn get valuta => text()();

  /// Quanto vale un euro in questa valuta. Testo, come gli importi.
  TextColumn get perEuro => text()();

  /// Il giorno del tasso secondo il fornitore: `2026-10-03`.
  TextColumn get del => text()();

  /// Quando questo telefono l'ha scaricato.
  DateTimeColumn get scaricatoIl => dateTime()();

  @override
  Set<Column> get primaryKey => {valuta};
}

// ─── Solo qui ─────────────────────────────────────────────────────────────

/// I quattro gesti possibili senza rete. Nessun altro.
enum GestoOffline { registraSpesa, marcaTappa, spuntaVoce, aggiungiTappa }

/// La coda di scrittura (02 §2): persistente, idempotente, ordinata per viaggio,
/// non bloccante. È l'unico dato dell'app che, se si perde, si perde davvero.
@DataClassName('OperazioneInCoda')
class CodaScrittura extends Table {
  @override
  String get tableName => 'coda_scrittura';

  /// Generato dal client: rimandare l'operazione non la applica due volte.
  TextColumn get id => text()();
  TextColumn get viaggioId => text()();
  TextColumn get gesto => textEnum<GestoOffline>()();

  /// La riga da inviare, in JSON, con i nomi di colonna del server.
  TextColumn get carico => text()();
  DateTimeColumn get creataIl => dateTime()();
  IntColumn get tentativi => integer().withDefault(const Constant(0))();
  TextColumn get ultimoErrore => text().nullable()();

  /// Fallita ripetutamente: si segnala senza fermare quelle dietro.
  BoolColumn get messaDaParte => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// I documenti (07-documenti.md, 03-documenti-sul-dispositivo.md): non sono una
/// copia, esistono solo su questo telefono. Il file sta nella cartella dei
/// documenti dell'app; questa riga dice che cos'è. Persa la riga, il file c'è
/// ancora ma nessuno lo ritrova: ogni migrazione la conserva, ed è provato.
///
/// Non entra nella coda di scrittura e non ha niente da mandare al server
/// (test/documenti_restano_qui_test.dart).
@DataClassName('Documento')
class Documenti extends Table {
  @override
  String get tableName => 'documento';

  TextColumn get id => text()();
  TextColumn get viaggioId => text()();

  /// Il giorno in cui serve; nessuno se serve per tutto il viaggio.
  TextColumn get giornoId => text().nullable()();

  /// A che ora serve, `07:05:00`, se si è detto.
  TextColumn get ora => text().nullable()();
  TextColumn get nome => text()();

  /// Relativo alla cartella dell'app, mai assoluto: ripristinato da un backup
  /// su un telefono nuovo, il contenitore dell'app ha un altro percorso (03).
  TextColumn get percorsoLocale => text()();

  /// `pdf` o `immagine` (dominio/documenti.dart).
  TextColumn get formato => text()();

  /// Quante pagine ha, se è un PDF.
  IntColumn get pagine => integer().nullable()();

  /// Da dove è arrivato: `scansione`, `foto`, `file`.
  TextColumn get sorgente => text()();

  /// Chi l'ha aggiunto: su un telefono dove entra un'altra persona, non si vede.
  TextColumn get proprietarioId => text()();
  DateTimeColumn get creatoIl => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eventi di misurazione non ancora partiti (07-misurazione.md).
@DataClassName('EventoInAttesa')
class EventiInAttesa extends Table {
  @override
  String get tableName => 'evento_in_attesa';

  TextColumn get id => text()();
  TextColumn get nome => text()();
  TextColumn get proprieta => text()();

  /// Quando è avvenuto, non quando parte.
  DateTimeColumn get avvenutoIl => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Preferenze locali della persona, chiave e valore.
@DataClassName('Impostazione')
class Impostazioni extends Table {
  @override
  String get tableName => 'impostazione';

  TextColumn get chiave => text()();
  TextColumn get valore => text()();

  @override
  Set<Column> get primaryKey => {chiave};
}

// ─── Database ─────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Utenti,
    Viaggi,
    Partecipazioni,
    Giorni,
    Tappe,
    Spese,
    SpeseQuote,
    VociLista,
    Note,
    TassiCambio,
    Configurazioni,
    Traguardi,
    CodaScrittura,
    Documenti,
    EventiInAttesa,
    Impostazioni,
  ],
)
class DatabaseLocale extends _$DatabaseLocale {
  DatabaseLocale([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'trolley'));

  /// 2 (fase 1.2): la copia delle tappe prende tipo, creato_da e creato_il.
  /// 3 (fase 1.3): l'indice dei documenti.
  /// 4 (fase 1.4): la copia delle spese prende creato_da e creato_il; i tassi
  /// di cambio.
  /// 5 (fase 1.5): la copia delle voci prende quantita, creato_da e creato_il.
  /// 6 (fase 1.6): le note del viaggio e la configurazione.
  /// 7 (fase 2.3): le spese sanno se sono un rimborso, le partecipazioni
  /// quando sono nate e quando sono cambiate.
  /// 8 (fase 2.4): le voci sanno chi le portava prima di lasciare il viaggio.
  /// 9 (fase 3.4): le partecipazioni sanno chi è stato sul posto.
  /// 10 (fase 4.1): la verifica di ciascuno, la deroga, i traguardi.
  /// 11 (fase 4.3): i giorni che si ricordano di un viaggio passato.
  @override
  int get schemaVersion => 11;

  /// Le tabelle che sono una copia del server.
  List<TableInfo> get tabelleCopia => [
    utenti,
    viaggi,
    partecipazioni,
    giorni,
    tappe,
    spese,
    speseQuote,
    vociLista,
    note,
    tassiCambio,
    configurazioni,
    traguardi,
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // La copia si butta e si riscarica, ma solo se cambia: senza rete resterebbe
    // vuota. Coda, documenti, eventi e impostazioni non si buttano mai: ogni
    // nuova versione che li tocca aggiunge qui il suo passo esplicito, e una
    // prova che sopravvivono (test/dati/database_locale_test.dart).
    onUpgrade: (m, da, a) async {
      if (da < 2) await ricreaCopia(m);
      if (da < 3) await m.createTable(documenti);
      // Le spese non si scaricavano ancora: la loro copia era vuota, e si
      // rifà senza toccare il resto, che resta leggibile senza rete. Da prima
      // della 2 ci ha già pensato ricreaCopia.
      if (da >= 2 && da < 4) {
        for (final TableInfo tabella in [spese, tassiCambio]) {
          await m.deleteTable(tabella.actualTableName);
          await m.createTable(tabella);
        }
      }
      // Le voci non si scaricavano ancora: come per le spese nella 4.
      if (da >= 2 && da < 5) {
        await m.deleteTable(vociLista.actualTableName);
        await m.createTable(vociLista);
      }
      // Tabelle nuove: non c'era niente da rifare. Da prima della 2 ci ha
      // già pensato ricreaCopia.
      if (da >= 2 && da < 6) {
        await m.createTable(note);
        await m.createTable(configurazioni);
      }
      // Colonne in più: la copia resta leggibile senza rete com'era, e quelle
      // nuove arrivano con la prossima copia. Le spese in coda restano spese.
      // Una tabella già rifatta da un passo di prima ha già le colonne.
      if (da >= 2 && da < 7) {
        await _aggiungiSeManca(m, spese, spese.rimborso);
        await _aggiungiSeManca(m, partecipazioni, partecipazioni.creatoIl);
        await _aggiungiSeManca(m, partecipazioni, partecipazioni.modificatoIl);
      }
      if (da >= 2 && da < 8) {
        await _aggiungiSeManca(m, vociLista, vociLista.lasciataDa);
      }
      if (da >= 2 && da < 9) {
        await _aggiungiSeManca(m, partecipazioni, partecipazioni.sulPostoIl);
      }
      if (da >= 2 && da < 10) {
        await _aggiungiSeManca(m, partecipazioni, partecipazioni.verificato);
        await _aggiungiSeManca(m, viaggi, viaggi.verificaPerDeroga);
        await m.createTable(traguardi);
      }
      if (da >= 2 && da < 11) {
        await _aggiungiSeManca(m, viaggi, viaggi.giorniRicordati);
      }
    },
  );

  Future<void> _aggiungiSeManca(
    Migrator m,
    TableInfo tabella,
    GeneratedColumn colonna,
  ) async {
    final colonne = await customSelect(
      'PRAGMA table_info("${tabella.actualTableName}")',
    ).get();
    if (colonne.any((c) => c.read<String>('name') == colonna.name)) return;
    await m.addColumn(tabella, colonna);
  }

  /// Butta e ricrea le tabelle della copia, lasciando intatto tutto il resto.
  Future<void> ricreaCopia([Migrator? migrator]) async {
    final m = migrator ?? createMigrator();
    for (final tabella in tabelleCopia) {
      await m.deleteTable(tabella.actualTableName);
      await m.createTable(tabella);
    }
  }
}
