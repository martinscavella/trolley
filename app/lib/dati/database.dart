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
  TextColumn get tipo => text()();
  TextColumn get proprietarioId => text()();
  TextColumn get assegnatoA => text().nullable()();
  BoolColumn get spuntata => boolean()();
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
  @override
  int get schemaVersion => 3;

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
    },
  );

  /// Butta e ricrea le tabelle della copia, lasciando intatto tutto il resto.
  Future<void> ricreaCopia([Migrator? migrator]) async {
    final m = migrator ?? createMigrator();
    for (final tabella in tabelleCopia) {
      await m.deleteTable(tabella.actualTableName);
      await m.createTable(tabella);
    }
  }
}
