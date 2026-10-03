// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UtentiTable extends Utenti with TableInfo<$UtentiTable, Utente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UtentiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataNascitaMeta = const VerificationMeta(
    'dataNascita',
  );
  @override
  late final GeneratedColumn<String> dataNascita = GeneratedColumn<String>(
    'data_nascita',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valutaPredefinitaMeta = const VerificationMeta(
    'valutaPredefinita',
  );
  @override
  late final GeneratedColumn<String> valutaPredefinita =
      GeneratedColumn<String>(
        'valuta_predefinita',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    nome,
    dataNascita,
    valutaPredefinita,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'utente';
  @override
  VerificationContext validateIntegrity(
    Insertable<Utente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('data_nascita')) {
      context.handle(
        _dataNascitaMeta,
        dataNascita.isAcceptableOrUnknown(
          data['data_nascita']!,
          _dataNascitaMeta,
        ),
      );
    }
    if (data.containsKey('valuta_predefinita')) {
      context.handle(
        _valutaPredefinitaMeta,
        valutaPredefinita.isAcceptableOrUnknown(
          data['valuta_predefinita']!,
          _valutaPredefinitaMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Utente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Utente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      dataNascita: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_nascita'],
      ),
      valutaPredefinita: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuta_predefinita'],
      ),
    );
  }

  @override
  $UtentiTable createAlias(String alias) {
    return $UtentiTable(attachedDatabase, alias);
  }
}

class Utente extends DataClass implements Insertable<Utente> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String nome;

  /// Solo per il proprio profilo: degli altri il server manda solo il nome.
  final String? dataNascita;
  final String? valutaPredefinita;
  const Utente({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.nome,
    this.dataNascita,
    this.valutaPredefinita,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['nome'] = Variable<String>(nome);
    if (!nullToAbsent || dataNascita != null) {
      map['data_nascita'] = Variable<String>(dataNascita);
    }
    if (!nullToAbsent || valutaPredefinita != null) {
      map['valuta_predefinita'] = Variable<String>(valutaPredefinita);
    }
    return map;
  }

  UtentiCompanion toCompanion(bool nullToAbsent) {
    return UtentiCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      nome: Value(nome),
      dataNascita: dataNascita == null && nullToAbsent
          ? const Value.absent()
          : Value(dataNascita),
      valutaPredefinita: valutaPredefinita == null && nullToAbsent
          ? const Value.absent()
          : Value(valutaPredefinita),
    );
  }

  factory Utente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Utente(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      nome: serializer.fromJson<String>(json['nome']),
      dataNascita: serializer.fromJson<String?>(json['dataNascita']),
      valutaPredefinita: serializer.fromJson<String?>(
        json['valutaPredefinita'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'nome': serializer.toJson<String>(nome),
      'dataNascita': serializer.toJson<String?>(dataNascita),
      'valutaPredefinita': serializer.toJson<String?>(valutaPredefinita),
    };
  }

  Utente copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? nome,
    Value<String?> dataNascita = const Value.absent(),
    Value<String?> valutaPredefinita = const Value.absent(),
  }) => Utente(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    nome: nome ?? this.nome,
    dataNascita: dataNascita.present ? dataNascita.value : this.dataNascita,
    valutaPredefinita: valutaPredefinita.present
        ? valutaPredefinita.value
        : this.valutaPredefinita,
  );
  Utente copyWithCompanion(UtentiCompanion data) {
    return Utente(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      nome: data.nome.present ? data.nome.value : this.nome,
      dataNascita: data.dataNascita.present
          ? data.dataNascita.value
          : this.dataNascita,
      valutaPredefinita: data.valutaPredefinita.present
          ? data.valutaPredefinita.value
          : this.valutaPredefinita,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Utente(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('nome: $nome, ')
          ..write('dataNascita: $dataNascita, ')
          ..write('valutaPredefinita: $valutaPredefinita')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    nome,
    dataNascita,
    valutaPredefinita,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Utente &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.nome == this.nome &&
          other.dataNascita == this.dataNascita &&
          other.valutaPredefinita == this.valutaPredefinita);
}

class UtentiCompanion extends UpdateCompanion<Utente> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> nome;
  final Value<String?> dataNascita;
  final Value<String?> valutaPredefinita;
  final Value<int> rowid;
  const UtentiCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.nome = const Value.absent(),
    this.dataNascita = const Value.absent(),
    this.valutaPredefinita = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UtentiCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String nome,
    this.dataNascita = const Value.absent(),
    this.valutaPredefinita = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       nome = Value(nome);
  static Insertable<Utente> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? nome,
    Expression<String>? dataNascita,
    Expression<String>? valutaPredefinita,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (nome != null) 'nome': nome,
      if (dataNascita != null) 'data_nascita': dataNascita,
      if (valutaPredefinita != null) 'valuta_predefinita': valutaPredefinita,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UtentiCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? nome,
    Value<String?>? dataNascita,
    Value<String?>? valutaPredefinita,
    Value<int>? rowid,
  }) {
    return UtentiCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      nome: nome ?? this.nome,
      dataNascita: dataNascita ?? this.dataNascita,
      valutaPredefinita: valutaPredefinita ?? this.valutaPredefinita,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (dataNascita.present) {
      map['data_nascita'] = Variable<String>(dataNascita.value);
    }
    if (valutaPredefinita.present) {
      map['valuta_predefinita'] = Variable<String>(valutaPredefinita.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UtentiCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('nome: $nome, ')
          ..write('dataNascita: $dataNascita, ')
          ..write('valutaPredefinita: $valutaPredefinita, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ViaggiTable extends Viaggi with TableInfo<$ViaggiTable, Viaggio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ViaggiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statoMeta = const VerificationMeta('stato');
  @override
  late final GeneratedColumn<String> stato = GeneratedColumn<String>(
    'stato',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinazioneCittaMeta = const VerificationMeta(
    'destinazioneCitta',
  );
  @override
  late final GeneratedColumn<String> destinazioneCitta =
      GeneratedColumn<String>(
        'destinazione_citta',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _destinazionePaeseMeta = const VerificationMeta(
    'destinazionePaese',
  );
  @override
  late final GeneratedColumn<String> destinazionePaese =
      GeneratedColumn<String>(
        'destinazione_paese',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _periodoApprossimativoMeta =
      const VerificationMeta('periodoApprossimativo');
  @override
  late final GeneratedColumn<String> periodoApprossimativo =
      GeneratedColumn<String>(
        'periodo_approssimativo',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dataInizioMeta = const VerificationMeta(
    'dataInizio',
  );
  @override
  late final GeneratedColumn<String> dataInizio = GeneratedColumn<String>(
    'data_inizio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataFineMeta = const VerificationMeta(
    'dataFine',
  );
  @override
  late final GeneratedColumn<String> dataFine = GeneratedColumn<String>(
    'data_fine',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oraArrivoMeta = const VerificationMeta(
    'oraArrivo',
  );
  @override
  late final GeneratedColumn<String> oraArrivo = GeneratedColumn<String>(
    'ora_arrivo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oraPartenzaMeta = const VerificationMeta(
    'oraPartenza',
  );
  @override
  late final GeneratedColumn<String> oraPartenza = GeneratedColumn<String>(
    'ora_partenza',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatoreIdMeta = const VerificationMeta(
    'creatoreId',
  );
  @override
  late final GeneratedColumn<String> creatoreId = GeneratedColumn<String>(
    'creatore_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importatoMeta = const VerificationMeta(
    'importato',
  );
  @override
  late final GeneratedColumn<bool> importato = GeneratedColumn<bool>(
    'importato',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("importato" IN (0, 1))',
    ),
  );
  static const VerificationMeta _verificatoMeta = const VerificationMeta(
    'verificato',
  );
  @override
  late final GeneratedColumn<bool> verificato = GeneratedColumn<bool>(
    'verificato',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verificato" IN (0, 1))',
    ),
  );
  static const VerificationMeta _creatoIlMeta = const VerificationMeta(
    'creatoIl',
  );
  @override
  late final GeneratedColumn<String> creatoIl = GeneratedColumn<String>(
    'creato_il',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    stato,
    destinazioneCitta,
    destinazionePaese,
    periodoApprossimativo,
    dataInizio,
    dataFine,
    oraArrivo,
    oraPartenza,
    creatoreId,
    importato,
    verificato,
    creatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'viaggio';
  @override
  VerificationContext validateIntegrity(
    Insertable<Viaggio> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('stato')) {
      context.handle(
        _statoMeta,
        stato.isAcceptableOrUnknown(data['stato']!, _statoMeta),
      );
    } else if (isInserting) {
      context.missing(_statoMeta);
    }
    if (data.containsKey('destinazione_citta')) {
      context.handle(
        _destinazioneCittaMeta,
        destinazioneCitta.isAcceptableOrUnknown(
          data['destinazione_citta']!,
          _destinazioneCittaMeta,
        ),
      );
    }
    if (data.containsKey('destinazione_paese')) {
      context.handle(
        _destinazionePaeseMeta,
        destinazionePaese.isAcceptableOrUnknown(
          data['destinazione_paese']!,
          _destinazionePaeseMeta,
        ),
      );
    }
    if (data.containsKey('periodo_approssimativo')) {
      context.handle(
        _periodoApprossimativoMeta,
        periodoApprossimativo.isAcceptableOrUnknown(
          data['periodo_approssimativo']!,
          _periodoApprossimativoMeta,
        ),
      );
    }
    if (data.containsKey('data_inizio')) {
      context.handle(
        _dataInizioMeta,
        dataInizio.isAcceptableOrUnknown(data['data_inizio']!, _dataInizioMeta),
      );
    }
    if (data.containsKey('data_fine')) {
      context.handle(
        _dataFineMeta,
        dataFine.isAcceptableOrUnknown(data['data_fine']!, _dataFineMeta),
      );
    }
    if (data.containsKey('ora_arrivo')) {
      context.handle(
        _oraArrivoMeta,
        oraArrivo.isAcceptableOrUnknown(data['ora_arrivo']!, _oraArrivoMeta),
      );
    }
    if (data.containsKey('ora_partenza')) {
      context.handle(
        _oraPartenzaMeta,
        oraPartenza.isAcceptableOrUnknown(
          data['ora_partenza']!,
          _oraPartenzaMeta,
        ),
      );
    }
    if (data.containsKey('creatore_id')) {
      context.handle(
        _creatoreIdMeta,
        creatoreId.isAcceptableOrUnknown(data['creatore_id']!, _creatoreIdMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoreIdMeta);
    }
    if (data.containsKey('importato')) {
      context.handle(
        _importatoMeta,
        importato.isAcceptableOrUnknown(data['importato']!, _importatoMeta),
      );
    } else if (isInserting) {
      context.missing(_importatoMeta);
    }
    if (data.containsKey('verificato')) {
      context.handle(
        _verificatoMeta,
        verificato.isAcceptableOrUnknown(data['verificato']!, _verificatoMeta),
      );
    } else if (isInserting) {
      context.missing(_verificatoMeta);
    }
    if (data.containsKey('creato_il')) {
      context.handle(
        _creatoIlMeta,
        creatoIl.isAcceptableOrUnknown(data['creato_il']!, _creatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Viaggio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Viaggio(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      stato: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stato'],
      )!,
      destinazioneCitta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destinazione_citta'],
      ),
      destinazionePaese: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destinazione_paese'],
      ),
      periodoApprossimativo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}periodo_approssimativo'],
      ),
      dataInizio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_inizio'],
      ),
      dataFine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_fine'],
      ),
      oraArrivo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ora_arrivo'],
      ),
      oraPartenza: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ora_partenza'],
      ),
      creatoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creatore_id'],
      )!,
      importato: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}importato'],
      )!,
      verificato: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verificato'],
      )!,
      creatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_il'],
      )!,
    );
  }

  @override
  $ViaggiTable createAlias(String alias) {
    return $ViaggiTable(attachedDatabase, alias);
  }
}

class Viaggio extends DataClass implements Insertable<Viaggio> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String stato;
  final String? destinazioneCitta;
  final String? destinazionePaese;
  final String? periodoApprossimativo;
  final String? dataInizio;
  final String? dataFine;
  final String? oraArrivo;
  final String? oraPartenza;
  final String creatoreId;
  final bool importato;
  final bool verificato;
  final String creatoIl;
  const Viaggio({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.stato,
    this.destinazioneCitta,
    this.destinazionePaese,
    this.periodoApprossimativo,
    this.dataInizio,
    this.dataFine,
    this.oraArrivo,
    this.oraPartenza,
    required this.creatoreId,
    required this.importato,
    required this.verificato,
    required this.creatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['stato'] = Variable<String>(stato);
    if (!nullToAbsent || destinazioneCitta != null) {
      map['destinazione_citta'] = Variable<String>(destinazioneCitta);
    }
    if (!nullToAbsent || destinazionePaese != null) {
      map['destinazione_paese'] = Variable<String>(destinazionePaese);
    }
    if (!nullToAbsent || periodoApprossimativo != null) {
      map['periodo_approssimativo'] = Variable<String>(periodoApprossimativo);
    }
    if (!nullToAbsent || dataInizio != null) {
      map['data_inizio'] = Variable<String>(dataInizio);
    }
    if (!nullToAbsent || dataFine != null) {
      map['data_fine'] = Variable<String>(dataFine);
    }
    if (!nullToAbsent || oraArrivo != null) {
      map['ora_arrivo'] = Variable<String>(oraArrivo);
    }
    if (!nullToAbsent || oraPartenza != null) {
      map['ora_partenza'] = Variable<String>(oraPartenza);
    }
    map['creatore_id'] = Variable<String>(creatoreId);
    map['importato'] = Variable<bool>(importato);
    map['verificato'] = Variable<bool>(verificato);
    map['creato_il'] = Variable<String>(creatoIl);
    return map;
  }

  ViaggiCompanion toCompanion(bool nullToAbsent) {
    return ViaggiCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      stato: Value(stato),
      destinazioneCitta: destinazioneCitta == null && nullToAbsent
          ? const Value.absent()
          : Value(destinazioneCitta),
      destinazionePaese: destinazionePaese == null && nullToAbsent
          ? const Value.absent()
          : Value(destinazionePaese),
      periodoApprossimativo: periodoApprossimativo == null && nullToAbsent
          ? const Value.absent()
          : Value(periodoApprossimativo),
      dataInizio: dataInizio == null && nullToAbsent
          ? const Value.absent()
          : Value(dataInizio),
      dataFine: dataFine == null && nullToAbsent
          ? const Value.absent()
          : Value(dataFine),
      oraArrivo: oraArrivo == null && nullToAbsent
          ? const Value.absent()
          : Value(oraArrivo),
      oraPartenza: oraPartenza == null && nullToAbsent
          ? const Value.absent()
          : Value(oraPartenza),
      creatoreId: Value(creatoreId),
      importato: Value(importato),
      verificato: Value(verificato),
      creatoIl: Value(creatoIl),
    );
  }

  factory Viaggio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Viaggio(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      stato: serializer.fromJson<String>(json['stato']),
      destinazioneCitta: serializer.fromJson<String?>(
        json['destinazioneCitta'],
      ),
      destinazionePaese: serializer.fromJson<String?>(
        json['destinazionePaese'],
      ),
      periodoApprossimativo: serializer.fromJson<String?>(
        json['periodoApprossimativo'],
      ),
      dataInizio: serializer.fromJson<String?>(json['dataInizio']),
      dataFine: serializer.fromJson<String?>(json['dataFine']),
      oraArrivo: serializer.fromJson<String?>(json['oraArrivo']),
      oraPartenza: serializer.fromJson<String?>(json['oraPartenza']),
      creatoreId: serializer.fromJson<String>(json['creatoreId']),
      importato: serializer.fromJson<bool>(json['importato']),
      verificato: serializer.fromJson<bool>(json['verificato']),
      creatoIl: serializer.fromJson<String>(json['creatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'stato': serializer.toJson<String>(stato),
      'destinazioneCitta': serializer.toJson<String?>(destinazioneCitta),
      'destinazionePaese': serializer.toJson<String?>(destinazionePaese),
      'periodoApprossimativo': serializer.toJson<String?>(
        periodoApprossimativo,
      ),
      'dataInizio': serializer.toJson<String?>(dataInizio),
      'dataFine': serializer.toJson<String?>(dataFine),
      'oraArrivo': serializer.toJson<String?>(oraArrivo),
      'oraPartenza': serializer.toJson<String?>(oraPartenza),
      'creatoreId': serializer.toJson<String>(creatoreId),
      'importato': serializer.toJson<bool>(importato),
      'verificato': serializer.toJson<bool>(verificato),
      'creatoIl': serializer.toJson<String>(creatoIl),
    };
  }

  Viaggio copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? stato,
    Value<String?> destinazioneCitta = const Value.absent(),
    Value<String?> destinazionePaese = const Value.absent(),
    Value<String?> periodoApprossimativo = const Value.absent(),
    Value<String?> dataInizio = const Value.absent(),
    Value<String?> dataFine = const Value.absent(),
    Value<String?> oraArrivo = const Value.absent(),
    Value<String?> oraPartenza = const Value.absent(),
    String? creatoreId,
    bool? importato,
    bool? verificato,
    String? creatoIl,
  }) => Viaggio(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    stato: stato ?? this.stato,
    destinazioneCitta: destinazioneCitta.present
        ? destinazioneCitta.value
        : this.destinazioneCitta,
    destinazionePaese: destinazionePaese.present
        ? destinazionePaese.value
        : this.destinazionePaese,
    periodoApprossimativo: periodoApprossimativo.present
        ? periodoApprossimativo.value
        : this.periodoApprossimativo,
    dataInizio: dataInizio.present ? dataInizio.value : this.dataInizio,
    dataFine: dataFine.present ? dataFine.value : this.dataFine,
    oraArrivo: oraArrivo.present ? oraArrivo.value : this.oraArrivo,
    oraPartenza: oraPartenza.present ? oraPartenza.value : this.oraPartenza,
    creatoreId: creatoreId ?? this.creatoreId,
    importato: importato ?? this.importato,
    verificato: verificato ?? this.verificato,
    creatoIl: creatoIl ?? this.creatoIl,
  );
  Viaggio copyWithCompanion(ViaggiCompanion data) {
    return Viaggio(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      stato: data.stato.present ? data.stato.value : this.stato,
      destinazioneCitta: data.destinazioneCitta.present
          ? data.destinazioneCitta.value
          : this.destinazioneCitta,
      destinazionePaese: data.destinazionePaese.present
          ? data.destinazionePaese.value
          : this.destinazionePaese,
      periodoApprossimativo: data.periodoApprossimativo.present
          ? data.periodoApprossimativo.value
          : this.periodoApprossimativo,
      dataInizio: data.dataInizio.present
          ? data.dataInizio.value
          : this.dataInizio,
      dataFine: data.dataFine.present ? data.dataFine.value : this.dataFine,
      oraArrivo: data.oraArrivo.present ? data.oraArrivo.value : this.oraArrivo,
      oraPartenza: data.oraPartenza.present
          ? data.oraPartenza.value
          : this.oraPartenza,
      creatoreId: data.creatoreId.present
          ? data.creatoreId.value
          : this.creatoreId,
      importato: data.importato.present ? data.importato.value : this.importato,
      verificato: data.verificato.present
          ? data.verificato.value
          : this.verificato,
      creatoIl: data.creatoIl.present ? data.creatoIl.value : this.creatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Viaggio(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('stato: $stato, ')
          ..write('destinazioneCitta: $destinazioneCitta, ')
          ..write('destinazionePaese: $destinazionePaese, ')
          ..write('periodoApprossimativo: $periodoApprossimativo, ')
          ..write('dataInizio: $dataInizio, ')
          ..write('dataFine: $dataFine, ')
          ..write('oraArrivo: $oraArrivo, ')
          ..write('oraPartenza: $oraPartenza, ')
          ..write('creatoreId: $creatoreId, ')
          ..write('importato: $importato, ')
          ..write('verificato: $verificato, ')
          ..write('creatoIl: $creatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    stato,
    destinazioneCitta,
    destinazionePaese,
    periodoApprossimativo,
    dataInizio,
    dataFine,
    oraArrivo,
    oraPartenza,
    creatoreId,
    importato,
    verificato,
    creatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Viaggio &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.stato == this.stato &&
          other.destinazioneCitta == this.destinazioneCitta &&
          other.destinazionePaese == this.destinazionePaese &&
          other.periodoApprossimativo == this.periodoApprossimativo &&
          other.dataInizio == this.dataInizio &&
          other.dataFine == this.dataFine &&
          other.oraArrivo == this.oraArrivo &&
          other.oraPartenza == this.oraPartenza &&
          other.creatoreId == this.creatoreId &&
          other.importato == this.importato &&
          other.verificato == this.verificato &&
          other.creatoIl == this.creatoIl);
}

class ViaggiCompanion extends UpdateCompanion<Viaggio> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> stato;
  final Value<String?> destinazioneCitta;
  final Value<String?> destinazionePaese;
  final Value<String?> periodoApprossimativo;
  final Value<String?> dataInizio;
  final Value<String?> dataFine;
  final Value<String?> oraArrivo;
  final Value<String?> oraPartenza;
  final Value<String> creatoreId;
  final Value<bool> importato;
  final Value<bool> verificato;
  final Value<String> creatoIl;
  final Value<int> rowid;
  const ViaggiCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.stato = const Value.absent(),
    this.destinazioneCitta = const Value.absent(),
    this.destinazionePaese = const Value.absent(),
    this.periodoApprossimativo = const Value.absent(),
    this.dataInizio = const Value.absent(),
    this.dataFine = const Value.absent(),
    this.oraArrivo = const Value.absent(),
    this.oraPartenza = const Value.absent(),
    this.creatoreId = const Value.absent(),
    this.importato = const Value.absent(),
    this.verificato = const Value.absent(),
    this.creatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ViaggiCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String stato,
    this.destinazioneCitta = const Value.absent(),
    this.destinazionePaese = const Value.absent(),
    this.periodoApprossimativo = const Value.absent(),
    this.dataInizio = const Value.absent(),
    this.dataFine = const Value.absent(),
    this.oraArrivo = const Value.absent(),
    this.oraPartenza = const Value.absent(),
    required String creatoreId,
    required bool importato,
    required bool verificato,
    required String creatoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       stato = Value(stato),
       creatoreId = Value(creatoreId),
       importato = Value(importato),
       verificato = Value(verificato),
       creatoIl = Value(creatoIl);
  static Insertable<Viaggio> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? stato,
    Expression<String>? destinazioneCitta,
    Expression<String>? destinazionePaese,
    Expression<String>? periodoApprossimativo,
    Expression<String>? dataInizio,
    Expression<String>? dataFine,
    Expression<String>? oraArrivo,
    Expression<String>? oraPartenza,
    Expression<String>? creatoreId,
    Expression<bool>? importato,
    Expression<bool>? verificato,
    Expression<String>? creatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (stato != null) 'stato': stato,
      if (destinazioneCitta != null) 'destinazione_citta': destinazioneCitta,
      if (destinazionePaese != null) 'destinazione_paese': destinazionePaese,
      if (periodoApprossimativo != null)
        'periodo_approssimativo': periodoApprossimativo,
      if (dataInizio != null) 'data_inizio': dataInizio,
      if (dataFine != null) 'data_fine': dataFine,
      if (oraArrivo != null) 'ora_arrivo': oraArrivo,
      if (oraPartenza != null) 'ora_partenza': oraPartenza,
      if (creatoreId != null) 'creatore_id': creatoreId,
      if (importato != null) 'importato': importato,
      if (verificato != null) 'verificato': verificato,
      if (creatoIl != null) 'creato_il': creatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ViaggiCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? stato,
    Value<String?>? destinazioneCitta,
    Value<String?>? destinazionePaese,
    Value<String?>? periodoApprossimativo,
    Value<String?>? dataInizio,
    Value<String?>? dataFine,
    Value<String?>? oraArrivo,
    Value<String?>? oraPartenza,
    Value<String>? creatoreId,
    Value<bool>? importato,
    Value<bool>? verificato,
    Value<String>? creatoIl,
    Value<int>? rowid,
  }) {
    return ViaggiCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      stato: stato ?? this.stato,
      destinazioneCitta: destinazioneCitta ?? this.destinazioneCitta,
      destinazionePaese: destinazionePaese ?? this.destinazionePaese,
      periodoApprossimativo:
          periodoApprossimativo ?? this.periodoApprossimativo,
      dataInizio: dataInizio ?? this.dataInizio,
      dataFine: dataFine ?? this.dataFine,
      oraArrivo: oraArrivo ?? this.oraArrivo,
      oraPartenza: oraPartenza ?? this.oraPartenza,
      creatoreId: creatoreId ?? this.creatoreId,
      importato: importato ?? this.importato,
      verificato: verificato ?? this.verificato,
      creatoIl: creatoIl ?? this.creatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (stato.present) {
      map['stato'] = Variable<String>(stato.value);
    }
    if (destinazioneCitta.present) {
      map['destinazione_citta'] = Variable<String>(destinazioneCitta.value);
    }
    if (destinazionePaese.present) {
      map['destinazione_paese'] = Variable<String>(destinazionePaese.value);
    }
    if (periodoApprossimativo.present) {
      map['periodo_approssimativo'] = Variable<String>(
        periodoApprossimativo.value,
      );
    }
    if (dataInizio.present) {
      map['data_inizio'] = Variable<String>(dataInizio.value);
    }
    if (dataFine.present) {
      map['data_fine'] = Variable<String>(dataFine.value);
    }
    if (oraArrivo.present) {
      map['ora_arrivo'] = Variable<String>(oraArrivo.value);
    }
    if (oraPartenza.present) {
      map['ora_partenza'] = Variable<String>(oraPartenza.value);
    }
    if (creatoreId.present) {
      map['creatore_id'] = Variable<String>(creatoreId.value);
    }
    if (importato.present) {
      map['importato'] = Variable<bool>(importato.value);
    }
    if (verificato.present) {
      map['verificato'] = Variable<bool>(verificato.value);
    }
    if (creatoIl.present) {
      map['creato_il'] = Variable<String>(creatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ViaggiCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('stato: $stato, ')
          ..write('destinazioneCitta: $destinazioneCitta, ')
          ..write('destinazionePaese: $destinazionePaese, ')
          ..write('periodoApprossimativo: $periodoApprossimativo, ')
          ..write('dataInizio: $dataInizio, ')
          ..write('dataFine: $dataFine, ')
          ..write('oraArrivo: $oraArrivo, ')
          ..write('oraPartenza: $oraPartenza, ')
          ..write('creatoreId: $creatoreId, ')
          ..write('importato: $importato, ')
          ..write('verificato: $verificato, ')
          ..write('creatoIl: $creatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartecipazioniTable extends Partecipazioni
    with TableInfo<$PartecipazioniTable, Partecipazione> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartecipazioniTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _utenteIdMeta = const VerificationMeta(
    'utenteId',
  );
  @override
  late final GeneratedColumn<String> utenteId = GeneratedColumn<String>(
    'utente_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruoloMeta = const VerificationMeta('ruolo');
  @override
  late final GeneratedColumn<String> ruolo = GeneratedColumn<String>(
    'ruolo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statoMeta = const VerificationMeta('stato');
  @override
  late final GeneratedColumn<String> stato = GeneratedColumn<String>(
    'stato',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    utenteId,
    ruolo,
    stato,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'partecipazione';
  @override
  VerificationContext validateIntegrity(
    Insertable<Partecipazione> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('utente_id')) {
      context.handle(
        _utenteIdMeta,
        utenteId.isAcceptableOrUnknown(data['utente_id']!, _utenteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_utenteIdMeta);
    }
    if (data.containsKey('ruolo')) {
      context.handle(
        _ruoloMeta,
        ruolo.isAcceptableOrUnknown(data['ruolo']!, _ruoloMeta),
      );
    } else if (isInserting) {
      context.missing(_ruoloMeta);
    }
    if (data.containsKey('stato')) {
      context.handle(
        _statoMeta,
        stato.isAcceptableOrUnknown(data['stato']!, _statoMeta),
      );
    } else if (isInserting) {
      context.missing(_statoMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Partecipazione map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Partecipazione(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      utenteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}utente_id'],
      )!,
      ruolo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ruolo'],
      )!,
      stato: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stato'],
      )!,
    );
  }

  @override
  $PartecipazioniTable createAlias(String alias) {
    return $PartecipazioniTable(attachedDatabase, alias);
  }
}

class Partecipazione extends DataClass implements Insertable<Partecipazione> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;
  final String utenteId;
  final String ruolo;
  final String stato;
  const Partecipazione({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.utenteId,
    required this.ruolo,
    required this.stato,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['utente_id'] = Variable<String>(utenteId);
    map['ruolo'] = Variable<String>(ruolo);
    map['stato'] = Variable<String>(stato);
    return map;
  }

  PartecipazioniCompanion toCompanion(bool nullToAbsent) {
    return PartecipazioniCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      utenteId: Value(utenteId),
      ruolo: Value(ruolo),
      stato: Value(stato),
    );
  }

  factory Partecipazione.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Partecipazione(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      utenteId: serializer.fromJson<String>(json['utenteId']),
      ruolo: serializer.fromJson<String>(json['ruolo']),
      stato: serializer.fromJson<String>(json['stato']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'utenteId': serializer.toJson<String>(utenteId),
      'ruolo': serializer.toJson<String>(ruolo),
      'stato': serializer.toJson<String>(stato),
    };
  }

  Partecipazione copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? utenteId,
    String? ruolo,
    String? stato,
  }) => Partecipazione(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    utenteId: utenteId ?? this.utenteId,
    ruolo: ruolo ?? this.ruolo,
    stato: stato ?? this.stato,
  );
  Partecipazione copyWithCompanion(PartecipazioniCompanion data) {
    return Partecipazione(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      utenteId: data.utenteId.present ? data.utenteId.value : this.utenteId,
      ruolo: data.ruolo.present ? data.ruolo.value : this.ruolo,
      stato: data.stato.present ? data.stato.value : this.stato,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Partecipazione(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('utenteId: $utenteId, ')
          ..write('ruolo: $ruolo, ')
          ..write('stato: $stato')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    utenteId,
    ruolo,
    stato,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Partecipazione &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.utenteId == this.utenteId &&
          other.ruolo == this.ruolo &&
          other.stato == this.stato);
}

class PartecipazioniCompanion extends UpdateCompanion<Partecipazione> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> utenteId;
  final Value<String> ruolo;
  final Value<String> stato;
  final Value<int> rowid;
  const PartecipazioniCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.utenteId = const Value.absent(),
    this.ruolo = const Value.absent(),
    this.stato = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartecipazioniCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String utenteId,
    required String ruolo,
    required String stato,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       utenteId = Value(utenteId),
       ruolo = Value(ruolo),
       stato = Value(stato);
  static Insertable<Partecipazione> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? utenteId,
    Expression<String>? ruolo,
    Expression<String>? stato,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (utenteId != null) 'utente_id': utenteId,
      if (ruolo != null) 'ruolo': ruolo,
      if (stato != null) 'stato': stato,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartecipazioniCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? utenteId,
    Value<String>? ruolo,
    Value<String>? stato,
    Value<int>? rowid,
  }) {
    return PartecipazioniCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      utenteId: utenteId ?? this.utenteId,
      ruolo: ruolo ?? this.ruolo,
      stato: stato ?? this.stato,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (utenteId.present) {
      map['utente_id'] = Variable<String>(utenteId.value);
    }
    if (ruolo.present) {
      map['ruolo'] = Variable<String>(ruolo.value);
    }
    if (stato.present) {
      map['stato'] = Variable<String>(stato.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartecipazioniCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('utenteId: $utenteId, ')
          ..write('ruolo: $ruolo, ')
          ..write('stato: $stato, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GiorniTable extends Giorni with TableInfo<$GiorniTable, Giorno> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GiorniTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finestraInizioMeta = const VerificationMeta(
    'finestraInizio',
  );
  @override
  late final GeneratedColumn<String> finestraInizio = GeneratedColumn<String>(
    'finestra_inizio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finestraFineMeta = const VerificationMeta(
    'finestraFine',
  );
  @override
  late final GeneratedColumn<String> finestraFine = GeneratedColumn<String>(
    'finestra_fine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    data,
    finestraInizio,
    finestraFine,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'giorno';
  @override
  VerificationContext validateIntegrity(
    Insertable<Giorno> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('finestra_inizio')) {
      context.handle(
        _finestraInizioMeta,
        finestraInizio.isAcceptableOrUnknown(
          data['finestra_inizio']!,
          _finestraInizioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finestraInizioMeta);
    }
    if (data.containsKey('finestra_fine')) {
      context.handle(
        _finestraFineMeta,
        finestraFine.isAcceptableOrUnknown(
          data['finestra_fine']!,
          _finestraFineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finestraFineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Giorno map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Giorno(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      finestraInizio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finestra_inizio'],
      )!,
      finestraFine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finestra_fine'],
      )!,
    );
  }

  @override
  $GiorniTable createAlias(String alias) {
    return $GiorniTable(attachedDatabase, alias);
  }
}

class Giorno extends DataClass implements Insertable<Giorno> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;
  final String data;
  final String finestraInizio;
  final String finestraFine;
  const Giorno({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.data,
    required this.finestraInizio,
    required this.finestraFine,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['data'] = Variable<String>(data);
    map['finestra_inizio'] = Variable<String>(finestraInizio);
    map['finestra_fine'] = Variable<String>(finestraFine);
    return map;
  }

  GiorniCompanion toCompanion(bool nullToAbsent) {
    return GiorniCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      data: Value(data),
      finestraInizio: Value(finestraInizio),
      finestraFine: Value(finestraFine),
    );
  }

  factory Giorno.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Giorno(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      data: serializer.fromJson<String>(json['data']),
      finestraInizio: serializer.fromJson<String>(json['finestraInizio']),
      finestraFine: serializer.fromJson<String>(json['finestraFine']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'data': serializer.toJson<String>(data),
      'finestraInizio': serializer.toJson<String>(finestraInizio),
      'finestraFine': serializer.toJson<String>(finestraFine),
    };
  }

  Giorno copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? data,
    String? finestraInizio,
    String? finestraFine,
  }) => Giorno(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    data: data ?? this.data,
    finestraInizio: finestraInizio ?? this.finestraInizio,
    finestraFine: finestraFine ?? this.finestraFine,
  );
  Giorno copyWithCompanion(GiorniCompanion data) {
    return Giorno(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      data: data.data.present ? data.data.value : this.data,
      finestraInizio: data.finestraInizio.present
          ? data.finestraInizio.value
          : this.finestraInizio,
      finestraFine: data.finestraFine.present
          ? data.finestraFine.value
          : this.finestraFine,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Giorno(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('data: $data, ')
          ..write('finestraInizio: $finestraInizio, ')
          ..write('finestraFine: $finestraFine')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    data,
    finestraInizio,
    finestraFine,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Giorno &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.data == this.data &&
          other.finestraInizio == this.finestraInizio &&
          other.finestraFine == this.finestraFine);
}

class GiorniCompanion extends UpdateCompanion<Giorno> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> data;
  final Value<String> finestraInizio;
  final Value<String> finestraFine;
  final Value<int> rowid;
  const GiorniCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.data = const Value.absent(),
    this.finestraInizio = const Value.absent(),
    this.finestraFine = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GiorniCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String data,
    required String finestraInizio,
    required String finestraFine,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       data = Value(data),
       finestraInizio = Value(finestraInizio),
       finestraFine = Value(finestraFine);
  static Insertable<Giorno> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? data,
    Expression<String>? finestraInizio,
    Expression<String>? finestraFine,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (data != null) 'data': data,
      if (finestraInizio != null) 'finestra_inizio': finestraInizio,
      if (finestraFine != null) 'finestra_fine': finestraFine,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GiorniCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? data,
    Value<String>? finestraInizio,
    Value<String>? finestraFine,
    Value<int>? rowid,
  }) {
    return GiorniCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      data: data ?? this.data,
      finestraInizio: finestraInizio ?? this.finestraInizio,
      finestraFine: finestraFine ?? this.finestraFine,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (finestraInizio.present) {
      map['finestra_inizio'] = Variable<String>(finestraInizio.value);
    }
    if (finestraFine.present) {
      map['finestra_fine'] = Variable<String>(finestraFine.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GiorniCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('data: $data, ')
          ..write('finestraInizio: $finestraInizio, ')
          ..write('finestraFine: $finestraFine, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TappeTable extends Tappe with TableInfo<$TappeTable, Tappa> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TappeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _giornoIdMeta = const VerificationMeta(
    'giornoId',
  );
  @override
  late final GeneratedColumn<String> giornoId = GeneratedColumn<String>(
    'giorno_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordineMeta = const VerificationMeta('ordine');
  @override
  late final GeneratedColumn<int> ordine = GeneratedColumn<int>(
    'ordine',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titoloMeta = const VerificationMeta('titolo');
  @override
  late final GeneratedColumn<String> titolo = GeneratedColumn<String>(
    'titolo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _luogoNomeMeta = const VerificationMeta(
    'luogoNome',
  );
  @override
  late final GeneratedColumn<String> luogoNome = GeneratedColumn<String>(
    'luogo_nome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durataStimataMinMeta = const VerificationMeta(
    'durataStimataMin',
  );
  @override
  late final GeneratedColumn<int> durataStimataMin = GeneratedColumn<int>(
    'durata_stimata_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oraInizioMeta = const VerificationMeta(
    'oraInizio',
  );
  @override
  late final GeneratedColumn<String> oraInizio = GeneratedColumn<String>(
    'ora_inizio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statoMeta = const VerificationMeta('stato');
  @override
  late final GeneratedColumn<String> stato = GeneratedColumn<String>(
    'stato',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marcataIlMeta = const VerificationMeta(
    'marcataIl',
  );
  @override
  late final GeneratedColumn<String> marcataIl = GeneratedColumn<String>(
    'marcata_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marcataDuranteIlViaggioMeta =
      const VerificationMeta('marcataDuranteIlViaggio');
  @override
  late final GeneratedColumn<bool> marcataDuranteIlViaggio =
      GeneratedColumn<bool>(
        'marcata_durante_il_viaggio',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("marcata_durante_il_viaggio" IN (0, 1))',
        ),
      );
  static const VerificationMeta _eccedenteMeta = const VerificationMeta(
    'eccedente',
  );
  @override
  late final GeneratedColumn<bool> eccedente = GeneratedColumn<bool>(
    'eccedente',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("eccedente" IN (0, 1))',
    ),
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatoDaMeta = const VerificationMeta(
    'creatoDa',
  );
  @override
  late final GeneratedColumn<String> creatoDa = GeneratedColumn<String>(
    'creato_da',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatoIlMeta = const VerificationMeta(
    'creatoIl',
  );
  @override
  late final GeneratedColumn<String> creatoIl = GeneratedColumn<String>(
    'creato_il',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    giornoId,
    ordine,
    titolo,
    luogoNome,
    lat,
    lon,
    durataStimataMin,
    oraInizio,
    stato,
    marcataIl,
    marcataDuranteIlViaggio,
    eccedente,
    tipo,
    creatoDa,
    creatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tappa';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tappa> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('giorno_id')) {
      context.handle(
        _giornoIdMeta,
        giornoId.isAcceptableOrUnknown(data['giorno_id']!, _giornoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_giornoIdMeta);
    }
    if (data.containsKey('ordine')) {
      context.handle(
        _ordineMeta,
        ordine.isAcceptableOrUnknown(data['ordine']!, _ordineMeta),
      );
    } else if (isInserting) {
      context.missing(_ordineMeta);
    }
    if (data.containsKey('titolo')) {
      context.handle(
        _titoloMeta,
        titolo.isAcceptableOrUnknown(data['titolo']!, _titoloMeta),
      );
    } else if (isInserting) {
      context.missing(_titoloMeta);
    }
    if (data.containsKey('luogo_nome')) {
      context.handle(
        _luogoNomeMeta,
        luogoNome.isAcceptableOrUnknown(data['luogo_nome']!, _luogoNomeMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('durata_stimata_min')) {
      context.handle(
        _durataStimataMinMeta,
        durataStimataMin.isAcceptableOrUnknown(
          data['durata_stimata_min']!,
          _durataStimataMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durataStimataMinMeta);
    }
    if (data.containsKey('ora_inizio')) {
      context.handle(
        _oraInizioMeta,
        oraInizio.isAcceptableOrUnknown(data['ora_inizio']!, _oraInizioMeta),
      );
    }
    if (data.containsKey('stato')) {
      context.handle(
        _statoMeta,
        stato.isAcceptableOrUnknown(data['stato']!, _statoMeta),
      );
    } else if (isInserting) {
      context.missing(_statoMeta);
    }
    if (data.containsKey('marcata_il')) {
      context.handle(
        _marcataIlMeta,
        marcataIl.isAcceptableOrUnknown(data['marcata_il']!, _marcataIlMeta),
      );
    }
    if (data.containsKey('marcata_durante_il_viaggio')) {
      context.handle(
        _marcataDuranteIlViaggioMeta,
        marcataDuranteIlViaggio.isAcceptableOrUnknown(
          data['marcata_durante_il_viaggio']!,
          _marcataDuranteIlViaggioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marcataDuranteIlViaggioMeta);
    }
    if (data.containsKey('eccedente')) {
      context.handle(
        _eccedenteMeta,
        eccedente.isAcceptableOrUnknown(data['eccedente']!, _eccedenteMeta),
      );
    } else if (isInserting) {
      context.missing(_eccedenteMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    }
    if (data.containsKey('creato_da')) {
      context.handle(
        _creatoDaMeta,
        creatoDa.isAcceptableOrUnknown(data['creato_da']!, _creatoDaMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoDaMeta);
    }
    if (data.containsKey('creato_il')) {
      context.handle(
        _creatoIlMeta,
        creatoIl.isAcceptableOrUnknown(data['creato_il']!, _creatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tappa map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tappa(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      giornoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}giorno_id'],
      )!,
      ordine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordine'],
      )!,
      titolo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titolo'],
      )!,
      luogoNome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}luogo_nome'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      durataStimataMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}durata_stimata_min'],
      )!,
      oraInizio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ora_inizio'],
      ),
      stato: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stato'],
      )!,
      marcataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marcata_il'],
      ),
      marcataDuranteIlViaggio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marcata_durante_il_viaggio'],
      )!,
      eccedente: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}eccedente'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      ),
      creatoDa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_da'],
      )!,
      creatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_il'],
      )!,
    );
  }

  @override
  $TappeTable createAlias(String alias) {
    return $TappeTable(attachedDatabase, alias);
  }
}

class Tappa extends DataClass implements Insertable<Tappa> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;
  final String giornoId;
  final int ordine;
  final String titolo;
  final String? luogoNome;
  final double? lat;
  final double? lon;
  final int durataStimataMin;
  final String? oraInizio;
  final String stato;
  final String? marcataIl;
  final bool marcataDuranteIlViaggio;
  final bool eccedente;

  /// Facoltativo: le tappe incollate da un itinerario (1.6) possono non averlo.
  final String? tipo;

  /// Chi l'ha aggiunta: il primo contributo di un invitato si riconosce così.
  final String creatoDa;

  /// A pari ordine, due tappe aggiunte insieme da due telefoni si mettono in
  /// fila per quando sono nate.
  final String creatoIl;
  const Tappa({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.giornoId,
    required this.ordine,
    required this.titolo,
    this.luogoNome,
    this.lat,
    this.lon,
    required this.durataStimataMin,
    this.oraInizio,
    required this.stato,
    this.marcataIl,
    required this.marcataDuranteIlViaggio,
    required this.eccedente,
    this.tipo,
    required this.creatoDa,
    required this.creatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['giorno_id'] = Variable<String>(giornoId);
    map['ordine'] = Variable<int>(ordine);
    map['titolo'] = Variable<String>(titolo);
    if (!nullToAbsent || luogoNome != null) {
      map['luogo_nome'] = Variable<String>(luogoNome);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    map['durata_stimata_min'] = Variable<int>(durataStimataMin);
    if (!nullToAbsent || oraInizio != null) {
      map['ora_inizio'] = Variable<String>(oraInizio);
    }
    map['stato'] = Variable<String>(stato);
    if (!nullToAbsent || marcataIl != null) {
      map['marcata_il'] = Variable<String>(marcataIl);
    }
    map['marcata_durante_il_viaggio'] = Variable<bool>(marcataDuranteIlViaggio);
    map['eccedente'] = Variable<bool>(eccedente);
    if (!nullToAbsent || tipo != null) {
      map['tipo'] = Variable<String>(tipo);
    }
    map['creato_da'] = Variable<String>(creatoDa);
    map['creato_il'] = Variable<String>(creatoIl);
    return map;
  }

  TappeCompanion toCompanion(bool nullToAbsent) {
    return TappeCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      giornoId: Value(giornoId),
      ordine: Value(ordine),
      titolo: Value(titolo),
      luogoNome: luogoNome == null && nullToAbsent
          ? const Value.absent()
          : Value(luogoNome),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      durataStimataMin: Value(durataStimataMin),
      oraInizio: oraInizio == null && nullToAbsent
          ? const Value.absent()
          : Value(oraInizio),
      stato: Value(stato),
      marcataIl: marcataIl == null && nullToAbsent
          ? const Value.absent()
          : Value(marcataIl),
      marcataDuranteIlViaggio: Value(marcataDuranteIlViaggio),
      eccedente: Value(eccedente),
      tipo: tipo == null && nullToAbsent ? const Value.absent() : Value(tipo),
      creatoDa: Value(creatoDa),
      creatoIl: Value(creatoIl),
    );
  }

  factory Tappa.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tappa(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      giornoId: serializer.fromJson<String>(json['giornoId']),
      ordine: serializer.fromJson<int>(json['ordine']),
      titolo: serializer.fromJson<String>(json['titolo']),
      luogoNome: serializer.fromJson<String?>(json['luogoNome']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      durataStimataMin: serializer.fromJson<int>(json['durataStimataMin']),
      oraInizio: serializer.fromJson<String?>(json['oraInizio']),
      stato: serializer.fromJson<String>(json['stato']),
      marcataIl: serializer.fromJson<String?>(json['marcataIl']),
      marcataDuranteIlViaggio: serializer.fromJson<bool>(
        json['marcataDuranteIlViaggio'],
      ),
      eccedente: serializer.fromJson<bool>(json['eccedente']),
      tipo: serializer.fromJson<String?>(json['tipo']),
      creatoDa: serializer.fromJson<String>(json['creatoDa']),
      creatoIl: serializer.fromJson<String>(json['creatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'giornoId': serializer.toJson<String>(giornoId),
      'ordine': serializer.toJson<int>(ordine),
      'titolo': serializer.toJson<String>(titolo),
      'luogoNome': serializer.toJson<String?>(luogoNome),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'durataStimataMin': serializer.toJson<int>(durataStimataMin),
      'oraInizio': serializer.toJson<String?>(oraInizio),
      'stato': serializer.toJson<String>(stato),
      'marcataIl': serializer.toJson<String?>(marcataIl),
      'marcataDuranteIlViaggio': serializer.toJson<bool>(
        marcataDuranteIlViaggio,
      ),
      'eccedente': serializer.toJson<bool>(eccedente),
      'tipo': serializer.toJson<String?>(tipo),
      'creatoDa': serializer.toJson<String>(creatoDa),
      'creatoIl': serializer.toJson<String>(creatoIl),
    };
  }

  Tappa copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? giornoId,
    int? ordine,
    String? titolo,
    Value<String?> luogoNome = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    int? durataStimataMin,
    Value<String?> oraInizio = const Value.absent(),
    String? stato,
    Value<String?> marcataIl = const Value.absent(),
    bool? marcataDuranteIlViaggio,
    bool? eccedente,
    Value<String?> tipo = const Value.absent(),
    String? creatoDa,
    String? creatoIl,
  }) => Tappa(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    giornoId: giornoId ?? this.giornoId,
    ordine: ordine ?? this.ordine,
    titolo: titolo ?? this.titolo,
    luogoNome: luogoNome.present ? luogoNome.value : this.luogoNome,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    durataStimataMin: durataStimataMin ?? this.durataStimataMin,
    oraInizio: oraInizio.present ? oraInizio.value : this.oraInizio,
    stato: stato ?? this.stato,
    marcataIl: marcataIl.present ? marcataIl.value : this.marcataIl,
    marcataDuranteIlViaggio:
        marcataDuranteIlViaggio ?? this.marcataDuranteIlViaggio,
    eccedente: eccedente ?? this.eccedente,
    tipo: tipo.present ? tipo.value : this.tipo,
    creatoDa: creatoDa ?? this.creatoDa,
    creatoIl: creatoIl ?? this.creatoIl,
  );
  Tappa copyWithCompanion(TappeCompanion data) {
    return Tappa(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      giornoId: data.giornoId.present ? data.giornoId.value : this.giornoId,
      ordine: data.ordine.present ? data.ordine.value : this.ordine,
      titolo: data.titolo.present ? data.titolo.value : this.titolo,
      luogoNome: data.luogoNome.present ? data.luogoNome.value : this.luogoNome,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      durataStimataMin: data.durataStimataMin.present
          ? data.durataStimataMin.value
          : this.durataStimataMin,
      oraInizio: data.oraInizio.present ? data.oraInizio.value : this.oraInizio,
      stato: data.stato.present ? data.stato.value : this.stato,
      marcataIl: data.marcataIl.present ? data.marcataIl.value : this.marcataIl,
      marcataDuranteIlViaggio: data.marcataDuranteIlViaggio.present
          ? data.marcataDuranteIlViaggio.value
          : this.marcataDuranteIlViaggio,
      eccedente: data.eccedente.present ? data.eccedente.value : this.eccedente,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      creatoDa: data.creatoDa.present ? data.creatoDa.value : this.creatoDa,
      creatoIl: data.creatoIl.present ? data.creatoIl.value : this.creatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tappa(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('giornoId: $giornoId, ')
          ..write('ordine: $ordine, ')
          ..write('titolo: $titolo, ')
          ..write('luogoNome: $luogoNome, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('durataStimataMin: $durataStimataMin, ')
          ..write('oraInizio: $oraInizio, ')
          ..write('stato: $stato, ')
          ..write('marcataIl: $marcataIl, ')
          ..write('marcataDuranteIlViaggio: $marcataDuranteIlViaggio, ')
          ..write('eccedente: $eccedente, ')
          ..write('tipo: $tipo, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    giornoId,
    ordine,
    titolo,
    luogoNome,
    lat,
    lon,
    durataStimataMin,
    oraInizio,
    stato,
    marcataIl,
    marcataDuranteIlViaggio,
    eccedente,
    tipo,
    creatoDa,
    creatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tappa &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.giornoId == this.giornoId &&
          other.ordine == this.ordine &&
          other.titolo == this.titolo &&
          other.luogoNome == this.luogoNome &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.durataStimataMin == this.durataStimataMin &&
          other.oraInizio == this.oraInizio &&
          other.stato == this.stato &&
          other.marcataIl == this.marcataIl &&
          other.marcataDuranteIlViaggio == this.marcataDuranteIlViaggio &&
          other.eccedente == this.eccedente &&
          other.tipo == this.tipo &&
          other.creatoDa == this.creatoDa &&
          other.creatoIl == this.creatoIl);
}

class TappeCompanion extends UpdateCompanion<Tappa> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> giornoId;
  final Value<int> ordine;
  final Value<String> titolo;
  final Value<String?> luogoNome;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<int> durataStimataMin;
  final Value<String?> oraInizio;
  final Value<String> stato;
  final Value<String?> marcataIl;
  final Value<bool> marcataDuranteIlViaggio;
  final Value<bool> eccedente;
  final Value<String?> tipo;
  final Value<String> creatoDa;
  final Value<String> creatoIl;
  final Value<int> rowid;
  const TappeCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.giornoId = const Value.absent(),
    this.ordine = const Value.absent(),
    this.titolo = const Value.absent(),
    this.luogoNome = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.durataStimataMin = const Value.absent(),
    this.oraInizio = const Value.absent(),
    this.stato = const Value.absent(),
    this.marcataIl = const Value.absent(),
    this.marcataDuranteIlViaggio = const Value.absent(),
    this.eccedente = const Value.absent(),
    this.tipo = const Value.absent(),
    this.creatoDa = const Value.absent(),
    this.creatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TappeCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String giornoId,
    required int ordine,
    required String titolo,
    this.luogoNome = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    required int durataStimataMin,
    this.oraInizio = const Value.absent(),
    required String stato,
    this.marcataIl = const Value.absent(),
    required bool marcataDuranteIlViaggio,
    required bool eccedente,
    this.tipo = const Value.absent(),
    required String creatoDa,
    required String creatoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       giornoId = Value(giornoId),
       ordine = Value(ordine),
       titolo = Value(titolo),
       durataStimataMin = Value(durataStimataMin),
       stato = Value(stato),
       marcataDuranteIlViaggio = Value(marcataDuranteIlViaggio),
       eccedente = Value(eccedente),
       creatoDa = Value(creatoDa),
       creatoIl = Value(creatoIl);
  static Insertable<Tappa> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? giornoId,
    Expression<int>? ordine,
    Expression<String>? titolo,
    Expression<String>? luogoNome,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<int>? durataStimataMin,
    Expression<String>? oraInizio,
    Expression<String>? stato,
    Expression<String>? marcataIl,
    Expression<bool>? marcataDuranteIlViaggio,
    Expression<bool>? eccedente,
    Expression<String>? tipo,
    Expression<String>? creatoDa,
    Expression<String>? creatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (giornoId != null) 'giorno_id': giornoId,
      if (ordine != null) 'ordine': ordine,
      if (titolo != null) 'titolo': titolo,
      if (luogoNome != null) 'luogo_nome': luogoNome,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (durataStimataMin != null) 'durata_stimata_min': durataStimataMin,
      if (oraInizio != null) 'ora_inizio': oraInizio,
      if (stato != null) 'stato': stato,
      if (marcataIl != null) 'marcata_il': marcataIl,
      if (marcataDuranteIlViaggio != null)
        'marcata_durante_il_viaggio': marcataDuranteIlViaggio,
      if (eccedente != null) 'eccedente': eccedente,
      if (tipo != null) 'tipo': tipo,
      if (creatoDa != null) 'creato_da': creatoDa,
      if (creatoIl != null) 'creato_il': creatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TappeCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? giornoId,
    Value<int>? ordine,
    Value<String>? titolo,
    Value<String?>? luogoNome,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<int>? durataStimataMin,
    Value<String?>? oraInizio,
    Value<String>? stato,
    Value<String?>? marcataIl,
    Value<bool>? marcataDuranteIlViaggio,
    Value<bool>? eccedente,
    Value<String?>? tipo,
    Value<String>? creatoDa,
    Value<String>? creatoIl,
    Value<int>? rowid,
  }) {
    return TappeCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      giornoId: giornoId ?? this.giornoId,
      ordine: ordine ?? this.ordine,
      titolo: titolo ?? this.titolo,
      luogoNome: luogoNome ?? this.luogoNome,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      durataStimataMin: durataStimataMin ?? this.durataStimataMin,
      oraInizio: oraInizio ?? this.oraInizio,
      stato: stato ?? this.stato,
      marcataIl: marcataIl ?? this.marcataIl,
      marcataDuranteIlViaggio:
          marcataDuranteIlViaggio ?? this.marcataDuranteIlViaggio,
      eccedente: eccedente ?? this.eccedente,
      tipo: tipo ?? this.tipo,
      creatoDa: creatoDa ?? this.creatoDa,
      creatoIl: creatoIl ?? this.creatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (giornoId.present) {
      map['giorno_id'] = Variable<String>(giornoId.value);
    }
    if (ordine.present) {
      map['ordine'] = Variable<int>(ordine.value);
    }
    if (titolo.present) {
      map['titolo'] = Variable<String>(titolo.value);
    }
    if (luogoNome.present) {
      map['luogo_nome'] = Variable<String>(luogoNome.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (durataStimataMin.present) {
      map['durata_stimata_min'] = Variable<int>(durataStimataMin.value);
    }
    if (oraInizio.present) {
      map['ora_inizio'] = Variable<String>(oraInizio.value);
    }
    if (stato.present) {
      map['stato'] = Variable<String>(stato.value);
    }
    if (marcataIl.present) {
      map['marcata_il'] = Variable<String>(marcataIl.value);
    }
    if (marcataDuranteIlViaggio.present) {
      map['marcata_durante_il_viaggio'] = Variable<bool>(
        marcataDuranteIlViaggio.value,
      );
    }
    if (eccedente.present) {
      map['eccedente'] = Variable<bool>(eccedente.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (creatoDa.present) {
      map['creato_da'] = Variable<String>(creatoDa.value);
    }
    if (creatoIl.present) {
      map['creato_il'] = Variable<String>(creatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TappeCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('giornoId: $giornoId, ')
          ..write('ordine: $ordine, ')
          ..write('titolo: $titolo, ')
          ..write('luogoNome: $luogoNome, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('durataStimataMin: $durataStimataMin, ')
          ..write('oraInizio: $oraInizio, ')
          ..write('stato: $stato, ')
          ..write('marcataIl: $marcataIl, ')
          ..write('marcataDuranteIlViaggio: $marcataDuranteIlViaggio, ')
          ..write('eccedente: $eccedente, ')
          ..write('tipo: $tipo, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeseTable extends Spese with TableInfo<$SpeseTable, Spesa> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeseTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importoMeta = const VerificationMeta(
    'importo',
  );
  @override
  late final GeneratedColumn<String> importo = GeneratedColumn<String>(
    'importo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valutaMeta = const VerificationMeta('valuta');
  @override
  late final GeneratedColumn<String> valuta = GeneratedColumn<String>(
    'valuta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tassoUsatoMeta = const VerificationMeta(
    'tassoUsato',
  );
  @override
  late final GeneratedColumn<String> tassoUsato = GeneratedColumn<String>(
    'tasso_usato',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tassoAlMeta = const VerificationMeta(
    'tassoAl',
  );
  @override
  late final GeneratedColumn<String> tassoAl = GeneratedColumn<String>(
    'tasso_al',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paganteIdMeta = const VerificationMeta(
    'paganteId',
  );
  @override
  late final GeneratedColumn<String> paganteId = GeneratedColumn<String>(
    'pagante_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descrizioneMeta = const VerificationMeta(
    'descrizione',
  );
  @override
  late final GeneratedColumn<String> descrizione = GeneratedColumn<String>(
    'descrizione',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatoDaMeta = const VerificationMeta(
    'creatoDa',
  );
  @override
  late final GeneratedColumn<String> creatoDa = GeneratedColumn<String>(
    'creato_da',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatoIlMeta = const VerificationMeta(
    'creatoIl',
  );
  @override
  late final GeneratedColumn<String> creatoIl = GeneratedColumn<String>(
    'creato_il',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    importo,
    valuta,
    tassoUsato,
    tassoAl,
    paganteId,
    data,
    descrizione,
    creatoDa,
    creatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spesa';
  @override
  VerificationContext validateIntegrity(
    Insertable<Spesa> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('importo')) {
      context.handle(
        _importoMeta,
        importo.isAcceptableOrUnknown(data['importo']!, _importoMeta),
      );
    } else if (isInserting) {
      context.missing(_importoMeta);
    }
    if (data.containsKey('valuta')) {
      context.handle(
        _valutaMeta,
        valuta.isAcceptableOrUnknown(data['valuta']!, _valutaMeta),
      );
    } else if (isInserting) {
      context.missing(_valutaMeta);
    }
    if (data.containsKey('tasso_usato')) {
      context.handle(
        _tassoUsatoMeta,
        tassoUsato.isAcceptableOrUnknown(data['tasso_usato']!, _tassoUsatoMeta),
      );
    }
    if (data.containsKey('tasso_al')) {
      context.handle(
        _tassoAlMeta,
        tassoAl.isAcceptableOrUnknown(data['tasso_al']!, _tassoAlMeta),
      );
    }
    if (data.containsKey('pagante_id')) {
      context.handle(
        _paganteIdMeta,
        paganteId.isAcceptableOrUnknown(data['pagante_id']!, _paganteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_paganteIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('descrizione')) {
      context.handle(
        _descrizioneMeta,
        descrizione.isAcceptableOrUnknown(
          data['descrizione']!,
          _descrizioneMeta,
        ),
      );
    }
    if (data.containsKey('creato_da')) {
      context.handle(
        _creatoDaMeta,
        creatoDa.isAcceptableOrUnknown(data['creato_da']!, _creatoDaMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoDaMeta);
    }
    if (data.containsKey('creato_il')) {
      context.handle(
        _creatoIlMeta,
        creatoIl.isAcceptableOrUnknown(data['creato_il']!, _creatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Spesa map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Spesa(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      importo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importo'],
      )!,
      valuta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuta'],
      )!,
      tassoUsato: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tasso_usato'],
      ),
      tassoAl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tasso_al'],
      ),
      paganteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pagante_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      descrizione: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descrizione'],
      ),
      creatoDa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_da'],
      )!,
      creatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_il'],
      )!,
    );
  }

  @override
  $SpeseTable createAlias(String alias) {
    return $SpeseTable(attachedDatabase, alias);
  }
}

class Spesa extends DataClass implements Insertable<Spesa> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;

  /// Testo e non numero: l'importo nella valuta originale è il dato vero,
  /// e un double lo arrotonderebbe.
  final String importo;
  final String valuta;
  final String? tassoUsato;
  final String? tassoAl;
  final String paganteId;
  final String data;
  final String? descrizione;

  /// Chi l'ha registrata: il primo contributo di un invitato si riconosce così.
  final String creatoDa;

  /// A pari data, l'ultima registrata va in cima.
  final String creatoIl;
  const Spesa({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.importo,
    required this.valuta,
    this.tassoUsato,
    this.tassoAl,
    required this.paganteId,
    required this.data,
    this.descrizione,
    required this.creatoDa,
    required this.creatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['importo'] = Variable<String>(importo);
    map['valuta'] = Variable<String>(valuta);
    if (!nullToAbsent || tassoUsato != null) {
      map['tasso_usato'] = Variable<String>(tassoUsato);
    }
    if (!nullToAbsent || tassoAl != null) {
      map['tasso_al'] = Variable<String>(tassoAl);
    }
    map['pagante_id'] = Variable<String>(paganteId);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || descrizione != null) {
      map['descrizione'] = Variable<String>(descrizione);
    }
    map['creato_da'] = Variable<String>(creatoDa);
    map['creato_il'] = Variable<String>(creatoIl);
    return map;
  }

  SpeseCompanion toCompanion(bool nullToAbsent) {
    return SpeseCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      importo: Value(importo),
      valuta: Value(valuta),
      tassoUsato: tassoUsato == null && nullToAbsent
          ? const Value.absent()
          : Value(tassoUsato),
      tassoAl: tassoAl == null && nullToAbsent
          ? const Value.absent()
          : Value(tassoAl),
      paganteId: Value(paganteId),
      data: Value(data),
      descrizione: descrizione == null && nullToAbsent
          ? const Value.absent()
          : Value(descrizione),
      creatoDa: Value(creatoDa),
      creatoIl: Value(creatoIl),
    );
  }

  factory Spesa.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Spesa(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      importo: serializer.fromJson<String>(json['importo']),
      valuta: serializer.fromJson<String>(json['valuta']),
      tassoUsato: serializer.fromJson<String?>(json['tassoUsato']),
      tassoAl: serializer.fromJson<String?>(json['tassoAl']),
      paganteId: serializer.fromJson<String>(json['paganteId']),
      data: serializer.fromJson<String>(json['data']),
      descrizione: serializer.fromJson<String?>(json['descrizione']),
      creatoDa: serializer.fromJson<String>(json['creatoDa']),
      creatoIl: serializer.fromJson<String>(json['creatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'importo': serializer.toJson<String>(importo),
      'valuta': serializer.toJson<String>(valuta),
      'tassoUsato': serializer.toJson<String?>(tassoUsato),
      'tassoAl': serializer.toJson<String?>(tassoAl),
      'paganteId': serializer.toJson<String>(paganteId),
      'data': serializer.toJson<String>(data),
      'descrizione': serializer.toJson<String?>(descrizione),
      'creatoDa': serializer.toJson<String>(creatoDa),
      'creatoIl': serializer.toJson<String>(creatoIl),
    };
  }

  Spesa copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? importo,
    String? valuta,
    Value<String?> tassoUsato = const Value.absent(),
    Value<String?> tassoAl = const Value.absent(),
    String? paganteId,
    String? data,
    Value<String?> descrizione = const Value.absent(),
    String? creatoDa,
    String? creatoIl,
  }) => Spesa(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    importo: importo ?? this.importo,
    valuta: valuta ?? this.valuta,
    tassoUsato: tassoUsato.present ? tassoUsato.value : this.tassoUsato,
    tassoAl: tassoAl.present ? tassoAl.value : this.tassoAl,
    paganteId: paganteId ?? this.paganteId,
    data: data ?? this.data,
    descrizione: descrizione.present ? descrizione.value : this.descrizione,
    creatoDa: creatoDa ?? this.creatoDa,
    creatoIl: creatoIl ?? this.creatoIl,
  );
  Spesa copyWithCompanion(SpeseCompanion data) {
    return Spesa(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      importo: data.importo.present ? data.importo.value : this.importo,
      valuta: data.valuta.present ? data.valuta.value : this.valuta,
      tassoUsato: data.tassoUsato.present
          ? data.tassoUsato.value
          : this.tassoUsato,
      tassoAl: data.tassoAl.present ? data.tassoAl.value : this.tassoAl,
      paganteId: data.paganteId.present ? data.paganteId.value : this.paganteId,
      data: data.data.present ? data.data.value : this.data,
      descrizione: data.descrizione.present
          ? data.descrizione.value
          : this.descrizione,
      creatoDa: data.creatoDa.present ? data.creatoDa.value : this.creatoDa,
      creatoIl: data.creatoIl.present ? data.creatoIl.value : this.creatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Spesa(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('importo: $importo, ')
          ..write('valuta: $valuta, ')
          ..write('tassoUsato: $tassoUsato, ')
          ..write('tassoAl: $tassoAl, ')
          ..write('paganteId: $paganteId, ')
          ..write('data: $data, ')
          ..write('descrizione: $descrizione, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    importo,
    valuta,
    tassoUsato,
    tassoAl,
    paganteId,
    data,
    descrizione,
    creatoDa,
    creatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Spesa &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.importo == this.importo &&
          other.valuta == this.valuta &&
          other.tassoUsato == this.tassoUsato &&
          other.tassoAl == this.tassoAl &&
          other.paganteId == this.paganteId &&
          other.data == this.data &&
          other.descrizione == this.descrizione &&
          other.creatoDa == this.creatoDa &&
          other.creatoIl == this.creatoIl);
}

class SpeseCompanion extends UpdateCompanion<Spesa> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> importo;
  final Value<String> valuta;
  final Value<String?> tassoUsato;
  final Value<String?> tassoAl;
  final Value<String> paganteId;
  final Value<String> data;
  final Value<String?> descrizione;
  final Value<String> creatoDa;
  final Value<String> creatoIl;
  final Value<int> rowid;
  const SpeseCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.importo = const Value.absent(),
    this.valuta = const Value.absent(),
    this.tassoUsato = const Value.absent(),
    this.tassoAl = const Value.absent(),
    this.paganteId = const Value.absent(),
    this.data = const Value.absent(),
    this.descrizione = const Value.absent(),
    this.creatoDa = const Value.absent(),
    this.creatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeseCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String importo,
    required String valuta,
    this.tassoUsato = const Value.absent(),
    this.tassoAl = const Value.absent(),
    required String paganteId,
    required String data,
    this.descrizione = const Value.absent(),
    required String creatoDa,
    required String creatoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       importo = Value(importo),
       valuta = Value(valuta),
       paganteId = Value(paganteId),
       data = Value(data),
       creatoDa = Value(creatoDa),
       creatoIl = Value(creatoIl);
  static Insertable<Spesa> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? importo,
    Expression<String>? valuta,
    Expression<String>? tassoUsato,
    Expression<String>? tassoAl,
    Expression<String>? paganteId,
    Expression<String>? data,
    Expression<String>? descrizione,
    Expression<String>? creatoDa,
    Expression<String>? creatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (importo != null) 'importo': importo,
      if (valuta != null) 'valuta': valuta,
      if (tassoUsato != null) 'tasso_usato': tassoUsato,
      if (tassoAl != null) 'tasso_al': tassoAl,
      if (paganteId != null) 'pagante_id': paganteId,
      if (data != null) 'data': data,
      if (descrizione != null) 'descrizione': descrizione,
      if (creatoDa != null) 'creato_da': creatoDa,
      if (creatoIl != null) 'creato_il': creatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeseCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? importo,
    Value<String>? valuta,
    Value<String?>? tassoUsato,
    Value<String?>? tassoAl,
    Value<String>? paganteId,
    Value<String>? data,
    Value<String?>? descrizione,
    Value<String>? creatoDa,
    Value<String>? creatoIl,
    Value<int>? rowid,
  }) {
    return SpeseCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      importo: importo ?? this.importo,
      valuta: valuta ?? this.valuta,
      tassoUsato: tassoUsato ?? this.tassoUsato,
      tassoAl: tassoAl ?? this.tassoAl,
      paganteId: paganteId ?? this.paganteId,
      data: data ?? this.data,
      descrizione: descrizione ?? this.descrizione,
      creatoDa: creatoDa ?? this.creatoDa,
      creatoIl: creatoIl ?? this.creatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (importo.present) {
      map['importo'] = Variable<String>(importo.value);
    }
    if (valuta.present) {
      map['valuta'] = Variable<String>(valuta.value);
    }
    if (tassoUsato.present) {
      map['tasso_usato'] = Variable<String>(tassoUsato.value);
    }
    if (tassoAl.present) {
      map['tasso_al'] = Variable<String>(tassoAl.value);
    }
    if (paganteId.present) {
      map['pagante_id'] = Variable<String>(paganteId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (descrizione.present) {
      map['descrizione'] = Variable<String>(descrizione.value);
    }
    if (creatoDa.present) {
      map['creato_da'] = Variable<String>(creatoDa.value);
    }
    if (creatoIl.present) {
      map['creato_il'] = Variable<String>(creatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeseCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('importo: $importo, ')
          ..write('valuta: $valuta, ')
          ..write('tassoUsato: $tassoUsato, ')
          ..write('tassoAl: $tassoAl, ')
          ..write('paganteId: $paganteId, ')
          ..write('data: $data, ')
          ..write('descrizione: $descrizione, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeseQuoteTable extends SpeseQuote
    with TableInfo<$SpeseQuoteTable, SpesaQuota> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeseQuoteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spesaIdMeta = const VerificationMeta(
    'spesaId',
  );
  @override
  late final GeneratedColumn<String> spesaId = GeneratedColumn<String>(
    'spesa_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _utenteIdMeta = const VerificationMeta(
    'utenteId',
  );
  @override
  late final GeneratedColumn<String> utenteId = GeneratedColumn<String>(
    'utente_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quotaMeta = const VerificationMeta('quota');
  @override
  late final GeneratedColumn<String> quota = GeneratedColumn<String>(
    'quota',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    spesaId,
    utenteId,
    quota,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spesa_quota';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpesaQuota> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('spesa_id')) {
      context.handle(
        _spesaIdMeta,
        spesaId.isAcceptableOrUnknown(data['spesa_id']!, _spesaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spesaIdMeta);
    }
    if (data.containsKey('utente_id')) {
      context.handle(
        _utenteIdMeta,
        utenteId.isAcceptableOrUnknown(data['utente_id']!, _utenteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_utenteIdMeta);
    }
    if (data.containsKey('quota')) {
      context.handle(
        _quotaMeta,
        quota.isAcceptableOrUnknown(data['quota']!, _quotaMeta),
      );
    } else if (isInserting) {
      context.missing(_quotaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpesaQuota map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpesaQuota(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      spesaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spesa_id'],
      )!,
      utenteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}utente_id'],
      )!,
      quota: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quota'],
      )!,
    );
  }

  @override
  $SpeseQuoteTable createAlias(String alias) {
    return $SpeseQuoteTable(attachedDatabase, alias);
  }
}

class SpesaQuota extends DataClass implements Insertable<SpesaQuota> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;
  final String spesaId;
  final String utenteId;
  final String quota;
  const SpesaQuota({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.spesaId,
    required this.utenteId,
    required this.quota,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['spesa_id'] = Variable<String>(spesaId);
    map['utente_id'] = Variable<String>(utenteId);
    map['quota'] = Variable<String>(quota);
    return map;
  }

  SpeseQuoteCompanion toCompanion(bool nullToAbsent) {
    return SpeseQuoteCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      spesaId: Value(spesaId),
      utenteId: Value(utenteId),
      quota: Value(quota),
    );
  }

  factory SpesaQuota.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpesaQuota(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      spesaId: serializer.fromJson<String>(json['spesaId']),
      utenteId: serializer.fromJson<String>(json['utenteId']),
      quota: serializer.fromJson<String>(json['quota']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'spesaId': serializer.toJson<String>(spesaId),
      'utenteId': serializer.toJson<String>(utenteId),
      'quota': serializer.toJson<String>(quota),
    };
  }

  SpesaQuota copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? spesaId,
    String? utenteId,
    String? quota,
  }) => SpesaQuota(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    spesaId: spesaId ?? this.spesaId,
    utenteId: utenteId ?? this.utenteId,
    quota: quota ?? this.quota,
  );
  SpesaQuota copyWithCompanion(SpeseQuoteCompanion data) {
    return SpesaQuota(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      spesaId: data.spesaId.present ? data.spesaId.value : this.spesaId,
      utenteId: data.utenteId.present ? data.utenteId.value : this.utenteId,
      quota: data.quota.present ? data.quota.value : this.quota,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpesaQuota(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('spesaId: $spesaId, ')
          ..write('utenteId: $utenteId, ')
          ..write('quota: $quota')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    spesaId,
    utenteId,
    quota,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpesaQuota &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.spesaId == this.spesaId &&
          other.utenteId == this.utenteId &&
          other.quota == this.quota);
}

class SpeseQuoteCompanion extends UpdateCompanion<SpesaQuota> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> spesaId;
  final Value<String> utenteId;
  final Value<String> quota;
  final Value<int> rowid;
  const SpeseQuoteCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.spesaId = const Value.absent(),
    this.utenteId = const Value.absent(),
    this.quota = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeseQuoteCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String spesaId,
    required String utenteId,
    required String quota,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       spesaId = Value(spesaId),
       utenteId = Value(utenteId),
       quota = Value(quota);
  static Insertable<SpesaQuota> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? spesaId,
    Expression<String>? utenteId,
    Expression<String>? quota,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (spesaId != null) 'spesa_id': spesaId,
      if (utenteId != null) 'utente_id': utenteId,
      if (quota != null) 'quota': quota,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeseQuoteCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? spesaId,
    Value<String>? utenteId,
    Value<String>? quota,
    Value<int>? rowid,
  }) {
    return SpeseQuoteCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      spesaId: spesaId ?? this.spesaId,
      utenteId: utenteId ?? this.utenteId,
      quota: quota ?? this.quota,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (spesaId.present) {
      map['spesa_id'] = Variable<String>(spesaId.value);
    }
    if (utenteId.present) {
      map['utente_id'] = Variable<String>(utenteId.value);
    }
    if (quota.present) {
      map['quota'] = Variable<String>(quota.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeseQuoteCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('spesaId: $spesaId, ')
          ..write('utenteId: $utenteId, ')
          ..write('quota: $quota, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VociListaTable extends VociLista
    with TableInfo<$VociListaTable, VoceLista> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VociListaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testoMeta = const VerificationMeta('testo');
  @override
  late final GeneratedColumn<String> testo = GeneratedColumn<String>(
    'testo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantitaMeta = const VerificationMeta(
    'quantita',
  );
  @override
  late final GeneratedColumn<int> quantita = GeneratedColumn<int>(
    'quantita',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proprietarioIdMeta = const VerificationMeta(
    'proprietarioId',
  );
  @override
  late final GeneratedColumn<String> proprietarioId = GeneratedColumn<String>(
    'proprietario_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assegnatoAMeta = const VerificationMeta(
    'assegnatoA',
  );
  @override
  late final GeneratedColumn<String> assegnatoA = GeneratedColumn<String>(
    'assegnato_a',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spuntataMeta = const VerificationMeta(
    'spuntata',
  );
  @override
  late final GeneratedColumn<bool> spuntata = GeneratedColumn<bool>(
    'spuntata',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("spuntata" IN (0, 1))',
    ),
  );
  static const VerificationMeta _creatoDaMeta = const VerificationMeta(
    'creatoDa',
  );
  @override
  late final GeneratedColumn<String> creatoDa = GeneratedColumn<String>(
    'creato_da',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatoIlMeta = const VerificationMeta(
    'creatoIl',
  );
  @override
  late final GeneratedColumn<String> creatoIl = GeneratedColumn<String>(
    'creato_il',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    testo,
    quantita,
    tipo,
    proprietarioId,
    assegnatoA,
    spuntata,
    creatoDa,
    creatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voce_lista';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoceLista> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('testo')) {
      context.handle(
        _testoMeta,
        testo.isAcceptableOrUnknown(data['testo']!, _testoMeta),
      );
    } else if (isInserting) {
      context.missing(_testoMeta);
    }
    if (data.containsKey('quantita')) {
      context.handle(
        _quantitaMeta,
        quantita.isAcceptableOrUnknown(data['quantita']!, _quantitaMeta),
      );
    } else if (isInserting) {
      context.missing(_quantitaMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('proprietario_id')) {
      context.handle(
        _proprietarioIdMeta,
        proprietarioId.isAcceptableOrUnknown(
          data['proprietario_id']!,
          _proprietarioIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_proprietarioIdMeta);
    }
    if (data.containsKey('assegnato_a')) {
      context.handle(
        _assegnatoAMeta,
        assegnatoA.isAcceptableOrUnknown(data['assegnato_a']!, _assegnatoAMeta),
      );
    }
    if (data.containsKey('spuntata')) {
      context.handle(
        _spuntataMeta,
        spuntata.isAcceptableOrUnknown(data['spuntata']!, _spuntataMeta),
      );
    } else if (isInserting) {
      context.missing(_spuntataMeta);
    }
    if (data.containsKey('creato_da')) {
      context.handle(
        _creatoDaMeta,
        creatoDa.isAcceptableOrUnknown(data['creato_da']!, _creatoDaMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoDaMeta);
    }
    if (data.containsKey('creato_il')) {
      context.handle(
        _creatoIlMeta,
        creatoIl.isAcceptableOrUnknown(data['creato_il']!, _creatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoceLista map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoceLista(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      testo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}testo'],
      )!,
      quantita: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantita'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      proprietarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proprietario_id'],
      )!,
      assegnatoA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assegnato_a'],
      ),
      spuntata: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}spuntata'],
      )!,
      creatoDa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_da'],
      )!,
      creatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_il'],
      )!,
    );
  }

  @override
  $VociListaTable createAlias(String alias) {
    return $VociListaTable(attachedDatabase, alias);
  }
}

class VoceLista extends DataClass implements Insertable<VoceLista> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;
  final String testo;

  /// Quanti pezzi: cinque magliette sono una voce sola (05, schermate).
  final int quantita;
  final String tipo;
  final String proprietarioId;
  final String? assegnatoA;
  final bool spuntata;

  /// Chi l'ha aggiunta: il primo contributo di un invitato si riconosce così.
  final String creatoDa;

  /// La lista va nell'ordine in cui le voci sono nate.
  final String creatoIl;
  const VoceLista({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.testo,
    required this.quantita,
    required this.tipo,
    required this.proprietarioId,
    this.assegnatoA,
    required this.spuntata,
    required this.creatoDa,
    required this.creatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['testo'] = Variable<String>(testo);
    map['quantita'] = Variable<int>(quantita);
    map['tipo'] = Variable<String>(tipo);
    map['proprietario_id'] = Variable<String>(proprietarioId);
    if (!nullToAbsent || assegnatoA != null) {
      map['assegnato_a'] = Variable<String>(assegnatoA);
    }
    map['spuntata'] = Variable<bool>(spuntata);
    map['creato_da'] = Variable<String>(creatoDa);
    map['creato_il'] = Variable<String>(creatoIl);
    return map;
  }

  VociListaCompanion toCompanion(bool nullToAbsent) {
    return VociListaCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      testo: Value(testo),
      quantita: Value(quantita),
      tipo: Value(tipo),
      proprietarioId: Value(proprietarioId),
      assegnatoA: assegnatoA == null && nullToAbsent
          ? const Value.absent()
          : Value(assegnatoA),
      spuntata: Value(spuntata),
      creatoDa: Value(creatoDa),
      creatoIl: Value(creatoIl),
    );
  }

  factory VoceLista.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoceLista(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      testo: serializer.fromJson<String>(json['testo']),
      quantita: serializer.fromJson<int>(json['quantita']),
      tipo: serializer.fromJson<String>(json['tipo']),
      proprietarioId: serializer.fromJson<String>(json['proprietarioId']),
      assegnatoA: serializer.fromJson<String?>(json['assegnatoA']),
      spuntata: serializer.fromJson<bool>(json['spuntata']),
      creatoDa: serializer.fromJson<String>(json['creatoDa']),
      creatoIl: serializer.fromJson<String>(json['creatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'testo': serializer.toJson<String>(testo),
      'quantita': serializer.toJson<int>(quantita),
      'tipo': serializer.toJson<String>(tipo),
      'proprietarioId': serializer.toJson<String>(proprietarioId),
      'assegnatoA': serializer.toJson<String?>(assegnatoA),
      'spuntata': serializer.toJson<bool>(spuntata),
      'creatoDa': serializer.toJson<String>(creatoDa),
      'creatoIl': serializer.toJson<String>(creatoIl),
    };
  }

  VoceLista copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? testo,
    int? quantita,
    String? tipo,
    String? proprietarioId,
    Value<String?> assegnatoA = const Value.absent(),
    bool? spuntata,
    String? creatoDa,
    String? creatoIl,
  }) => VoceLista(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    testo: testo ?? this.testo,
    quantita: quantita ?? this.quantita,
    tipo: tipo ?? this.tipo,
    proprietarioId: proprietarioId ?? this.proprietarioId,
    assegnatoA: assegnatoA.present ? assegnatoA.value : this.assegnatoA,
    spuntata: spuntata ?? this.spuntata,
    creatoDa: creatoDa ?? this.creatoDa,
    creatoIl: creatoIl ?? this.creatoIl,
  );
  VoceLista copyWithCompanion(VociListaCompanion data) {
    return VoceLista(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      testo: data.testo.present ? data.testo.value : this.testo,
      quantita: data.quantita.present ? data.quantita.value : this.quantita,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      proprietarioId: data.proprietarioId.present
          ? data.proprietarioId.value
          : this.proprietarioId,
      assegnatoA: data.assegnatoA.present
          ? data.assegnatoA.value
          : this.assegnatoA,
      spuntata: data.spuntata.present ? data.spuntata.value : this.spuntata,
      creatoDa: data.creatoDa.present ? data.creatoDa.value : this.creatoDa,
      creatoIl: data.creatoIl.present ? data.creatoIl.value : this.creatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoceLista(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('testo: $testo, ')
          ..write('quantita: $quantita, ')
          ..write('tipo: $tipo, ')
          ..write('proprietarioId: $proprietarioId, ')
          ..write('assegnatoA: $assegnatoA, ')
          ..write('spuntata: $spuntata, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    testo,
    quantita,
    tipo,
    proprietarioId,
    assegnatoA,
    spuntata,
    creatoDa,
    creatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoceLista &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.testo == this.testo &&
          other.quantita == this.quantita &&
          other.tipo == this.tipo &&
          other.proprietarioId == this.proprietarioId &&
          other.assegnatoA == this.assegnatoA &&
          other.spuntata == this.spuntata &&
          other.creatoDa == this.creatoDa &&
          other.creatoIl == this.creatoIl);
}

class VociListaCompanion extends UpdateCompanion<VoceLista> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> testo;
  final Value<int> quantita;
  final Value<String> tipo;
  final Value<String> proprietarioId;
  final Value<String?> assegnatoA;
  final Value<bool> spuntata;
  final Value<String> creatoDa;
  final Value<String> creatoIl;
  final Value<int> rowid;
  const VociListaCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.testo = const Value.absent(),
    this.quantita = const Value.absent(),
    this.tipo = const Value.absent(),
    this.proprietarioId = const Value.absent(),
    this.assegnatoA = const Value.absent(),
    this.spuntata = const Value.absent(),
    this.creatoDa = const Value.absent(),
    this.creatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VociListaCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String testo,
    required int quantita,
    required String tipo,
    required String proprietarioId,
    this.assegnatoA = const Value.absent(),
    required bool spuntata,
    required String creatoDa,
    required String creatoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       testo = Value(testo),
       quantita = Value(quantita),
       tipo = Value(tipo),
       proprietarioId = Value(proprietarioId),
       spuntata = Value(spuntata),
       creatoDa = Value(creatoDa),
       creatoIl = Value(creatoIl);
  static Insertable<VoceLista> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? testo,
    Expression<int>? quantita,
    Expression<String>? tipo,
    Expression<String>? proprietarioId,
    Expression<String>? assegnatoA,
    Expression<bool>? spuntata,
    Expression<String>? creatoDa,
    Expression<String>? creatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (testo != null) 'testo': testo,
      if (quantita != null) 'quantita': quantita,
      if (tipo != null) 'tipo': tipo,
      if (proprietarioId != null) 'proprietario_id': proprietarioId,
      if (assegnatoA != null) 'assegnato_a': assegnatoA,
      if (spuntata != null) 'spuntata': spuntata,
      if (creatoDa != null) 'creato_da': creatoDa,
      if (creatoIl != null) 'creato_il': creatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VociListaCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? testo,
    Value<int>? quantita,
    Value<String>? tipo,
    Value<String>? proprietarioId,
    Value<String?>? assegnatoA,
    Value<bool>? spuntata,
    Value<String>? creatoDa,
    Value<String>? creatoIl,
    Value<int>? rowid,
  }) {
    return VociListaCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      testo: testo ?? this.testo,
      quantita: quantita ?? this.quantita,
      tipo: tipo ?? this.tipo,
      proprietarioId: proprietarioId ?? this.proprietarioId,
      assegnatoA: assegnatoA ?? this.assegnatoA,
      spuntata: spuntata ?? this.spuntata,
      creatoDa: creatoDa ?? this.creatoDa,
      creatoIl: creatoIl ?? this.creatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (testo.present) {
      map['testo'] = Variable<String>(testo.value);
    }
    if (quantita.present) {
      map['quantita'] = Variable<int>(quantita.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (proprietarioId.present) {
      map['proprietario_id'] = Variable<String>(proprietarioId.value);
    }
    if (assegnatoA.present) {
      map['assegnato_a'] = Variable<String>(assegnatoA.value);
    }
    if (spuntata.present) {
      map['spuntata'] = Variable<bool>(spuntata.value);
    }
    if (creatoDa.present) {
      map['creato_da'] = Variable<String>(creatoDa.value);
    }
    if (creatoIl.present) {
      map['creato_il'] = Variable<String>(creatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VociListaCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('testo: $testo, ')
          ..write('quantita: $quantita, ')
          ..write('tipo: $tipo, ')
          ..write('proprietarioId: $proprietarioId, ')
          ..write('assegnatoA: $assegnatoA, ')
          ..write('spuntata: $spuntata, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTable extends Note with TableInfo<$NoteTable, Nota> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versioneMeta = const VerificationMeta(
    'versione',
  );
  @override
  late final GeneratedColumn<int> versione = GeneratedColumn<int>(
    'versione',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eliminatoIlMeta = const VerificationMeta(
    'eliminatoIl',
  );
  @override
  late final GeneratedColumn<String> eliminatoIl = GeneratedColumn<String>(
    'eliminato_il',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _testoMeta = const VerificationMeta('testo');
  @override
  late final GeneratedColumn<String> testo = GeneratedColumn<String>(
    'testo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _origineMeta = const VerificationMeta(
    'origine',
  );
  @override
  late final GeneratedColumn<String> origine = GeneratedColumn<String>(
    'origine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatoDaMeta = const VerificationMeta(
    'creatoDa',
  );
  @override
  late final GeneratedColumn<String> creatoDa = GeneratedColumn<String>(
    'creato_da',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatoIlMeta = const VerificationMeta(
    'creatoIl',
  );
  @override
  late final GeneratedColumn<String> creatoIl = GeneratedColumn<String>(
    'creato_il',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    testo,
    origine,
    creatoDa,
    creatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nota';
  @override
  VerificationContext validateIntegrity(
    Insertable<Nota> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('versione')) {
      context.handle(
        _versioneMeta,
        versione.isAcceptableOrUnknown(data['versione']!, _versioneMeta),
      );
    } else if (isInserting) {
      context.missing(_versioneMeta);
    }
    if (data.containsKey('eliminato_il')) {
      context.handle(
        _eliminatoIlMeta,
        eliminatoIl.isAcceptableOrUnknown(
          data['eliminato_il']!,
          _eliminatoIlMeta,
        ),
      );
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('testo')) {
      context.handle(
        _testoMeta,
        testo.isAcceptableOrUnknown(data['testo']!, _testoMeta),
      );
    } else if (isInserting) {
      context.missing(_testoMeta);
    }
    if (data.containsKey('origine')) {
      context.handle(
        _origineMeta,
        origine.isAcceptableOrUnknown(data['origine']!, _origineMeta),
      );
    } else if (isInserting) {
      context.missing(_origineMeta);
    }
    if (data.containsKey('creato_da')) {
      context.handle(
        _creatoDaMeta,
        creatoDa.isAcceptableOrUnknown(data['creato_da']!, _creatoDaMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoDaMeta);
    }
    if (data.containsKey('creato_il')) {
      context.handle(
        _creatoIlMeta,
        creatoIl.isAcceptableOrUnknown(data['creato_il']!, _creatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Nota map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Nota(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      versione: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}versione'],
      )!,
      eliminatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eliminato_il'],
      ),
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      testo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}testo'],
      )!,
      origine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origine'],
      )!,
      creatoDa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_da'],
      )!,
      creatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creato_il'],
      )!,
    );
  }

  @override
  $NoteTable createAlias(String alias) {
    return $NoteTable(attachedDatabase, alias);
  }
}

class Nota extends DataClass implements Insertable<Nota> {
  final String id;
  final int versione;
  final String? eliminatoIl;

  /// Quando è stata scaricata: serve a dire "aggiornato due giorni fa"
  /// invece di far credere che sia fresca.
  final DateTime scaricatoIl;
  final String viaggioId;
  final String testo;

  /// `incollata` o `scritta`.
  final String origine;
  final String creatoDa;
  final String creatoIl;
  const Nota({
    required this.id,
    required this.versione,
    this.eliminatoIl,
    required this.scaricatoIl,
    required this.viaggioId,
    required this.testo,
    required this.origine,
    required this.creatoDa,
    required this.creatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['versione'] = Variable<int>(versione);
    if (!nullToAbsent || eliminatoIl != null) {
      map['eliminato_il'] = Variable<String>(eliminatoIl);
    }
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    map['viaggio_id'] = Variable<String>(viaggioId);
    map['testo'] = Variable<String>(testo);
    map['origine'] = Variable<String>(origine);
    map['creato_da'] = Variable<String>(creatoDa);
    map['creato_il'] = Variable<String>(creatoIl);
    return map;
  }

  NoteCompanion toCompanion(bool nullToAbsent) {
    return NoteCompanion(
      id: Value(id),
      versione: Value(versione),
      eliminatoIl: eliminatoIl == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminatoIl),
      scaricatoIl: Value(scaricatoIl),
      viaggioId: Value(viaggioId),
      testo: Value(testo),
      origine: Value(origine),
      creatoDa: Value(creatoDa),
      creatoIl: Value(creatoIl),
    );
  }

  factory Nota.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Nota(
      id: serializer.fromJson<String>(json['id']),
      versione: serializer.fromJson<int>(json['versione']),
      eliminatoIl: serializer.fromJson<String?>(json['eliminatoIl']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      testo: serializer.fromJson<String>(json['testo']),
      origine: serializer.fromJson<String>(json['origine']),
      creatoDa: serializer.fromJson<String>(json['creatoDa']),
      creatoIl: serializer.fromJson<String>(json['creatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versione': serializer.toJson<int>(versione),
      'eliminatoIl': serializer.toJson<String?>(eliminatoIl),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'testo': serializer.toJson<String>(testo),
      'origine': serializer.toJson<String>(origine),
      'creatoDa': serializer.toJson<String>(creatoDa),
      'creatoIl': serializer.toJson<String>(creatoIl),
    };
  }

  Nota copyWith({
    String? id,
    int? versione,
    Value<String?> eliminatoIl = const Value.absent(),
    DateTime? scaricatoIl,
    String? viaggioId,
    String? testo,
    String? origine,
    String? creatoDa,
    String? creatoIl,
  }) => Nota(
    id: id ?? this.id,
    versione: versione ?? this.versione,
    eliminatoIl: eliminatoIl.present ? eliminatoIl.value : this.eliminatoIl,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
    viaggioId: viaggioId ?? this.viaggioId,
    testo: testo ?? this.testo,
    origine: origine ?? this.origine,
    creatoDa: creatoDa ?? this.creatoDa,
    creatoIl: creatoIl ?? this.creatoIl,
  );
  Nota copyWithCompanion(NoteCompanion data) {
    return Nota(
      id: data.id.present ? data.id.value : this.id,
      versione: data.versione.present ? data.versione.value : this.versione,
      eliminatoIl: data.eliminatoIl.present
          ? data.eliminatoIl.value
          : this.eliminatoIl,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      testo: data.testo.present ? data.testo.value : this.testo,
      origine: data.origine.present ? data.origine.value : this.origine,
      creatoDa: data.creatoDa.present ? data.creatoDa.value : this.creatoDa,
      creatoIl: data.creatoIl.present ? data.creatoIl.value : this.creatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Nota(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('testo: $testo, ')
          ..write('origine: $origine, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versione,
    eliminatoIl,
    scaricatoIl,
    viaggioId,
    testo,
    origine,
    creatoDa,
    creatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nota &&
          other.id == this.id &&
          other.versione == this.versione &&
          other.eliminatoIl == this.eliminatoIl &&
          other.scaricatoIl == this.scaricatoIl &&
          other.viaggioId == this.viaggioId &&
          other.testo == this.testo &&
          other.origine == this.origine &&
          other.creatoDa == this.creatoDa &&
          other.creatoIl == this.creatoIl);
}

class NoteCompanion extends UpdateCompanion<Nota> {
  final Value<String> id;
  final Value<int> versione;
  final Value<String?> eliminatoIl;
  final Value<DateTime> scaricatoIl;
  final Value<String> viaggioId;
  final Value<String> testo;
  final Value<String> origine;
  final Value<String> creatoDa;
  final Value<String> creatoIl;
  final Value<int> rowid;
  const NoteCompanion({
    this.id = const Value.absent(),
    this.versione = const Value.absent(),
    this.eliminatoIl = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.testo = const Value.absent(),
    this.origine = const Value.absent(),
    this.creatoDa = const Value.absent(),
    this.creatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteCompanion.insert({
    required String id,
    required int versione,
    this.eliminatoIl = const Value.absent(),
    required DateTime scaricatoIl,
    required String viaggioId,
    required String testo,
    required String origine,
    required String creatoDa,
    required String creatoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       versione = Value(versione),
       scaricatoIl = Value(scaricatoIl),
       viaggioId = Value(viaggioId),
       testo = Value(testo),
       origine = Value(origine),
       creatoDa = Value(creatoDa),
       creatoIl = Value(creatoIl);
  static Insertable<Nota> custom({
    Expression<String>? id,
    Expression<int>? versione,
    Expression<String>? eliminatoIl,
    Expression<DateTime>? scaricatoIl,
    Expression<String>? viaggioId,
    Expression<String>? testo,
    Expression<String>? origine,
    Expression<String>? creatoDa,
    Expression<String>? creatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versione != null) 'versione': versione,
      if (eliminatoIl != null) 'eliminato_il': eliminatoIl,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (testo != null) 'testo': testo,
      if (origine != null) 'origine': origine,
      if (creatoDa != null) 'creato_da': creatoDa,
      if (creatoIl != null) 'creato_il': creatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteCompanion copyWith({
    Value<String>? id,
    Value<int>? versione,
    Value<String?>? eliminatoIl,
    Value<DateTime>? scaricatoIl,
    Value<String>? viaggioId,
    Value<String>? testo,
    Value<String>? origine,
    Value<String>? creatoDa,
    Value<String>? creatoIl,
    Value<int>? rowid,
  }) {
    return NoteCompanion(
      id: id ?? this.id,
      versione: versione ?? this.versione,
      eliminatoIl: eliminatoIl ?? this.eliminatoIl,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      viaggioId: viaggioId ?? this.viaggioId,
      testo: testo ?? this.testo,
      origine: origine ?? this.origine,
      creatoDa: creatoDa ?? this.creatoDa,
      creatoIl: creatoIl ?? this.creatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versione.present) {
      map['versione'] = Variable<int>(versione.value);
    }
    if (eliminatoIl.present) {
      map['eliminato_il'] = Variable<String>(eliminatoIl.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (testo.present) {
      map['testo'] = Variable<String>(testo.value);
    }
    if (origine.present) {
      map['origine'] = Variable<String>(origine.value);
    }
    if (creatoDa.present) {
      map['creato_da'] = Variable<String>(creatoDa.value);
    }
    if (creatoIl.present) {
      map['creato_il'] = Variable<String>(creatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteCompanion(')
          ..write('id: $id, ')
          ..write('versione: $versione, ')
          ..write('eliminatoIl: $eliminatoIl, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('testo: $testo, ')
          ..write('origine: $origine, ')
          ..write('creatoDa: $creatoDa, ')
          ..write('creatoIl: $creatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TassiCambioTable extends TassiCambio
    with TableInfo<$TassiCambioTable, TassoCambio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TassiCambioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _valutaMeta = const VerificationMeta('valuta');
  @override
  late final GeneratedColumn<String> valuta = GeneratedColumn<String>(
    'valuta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _perEuroMeta = const VerificationMeta(
    'perEuro',
  );
  @override
  late final GeneratedColumn<String> perEuro = GeneratedColumn<String>(
    'per_euro',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _delMeta = const VerificationMeta('del');
  @override
  late final GeneratedColumn<String> del = GeneratedColumn<String>(
    'del',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [valuta, perEuro, del, scaricatoIl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasso_cambio';
  @override
  VerificationContext validateIntegrity(
    Insertable<TassoCambio> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('valuta')) {
      context.handle(
        _valutaMeta,
        valuta.isAcceptableOrUnknown(data['valuta']!, _valutaMeta),
      );
    } else if (isInserting) {
      context.missing(_valutaMeta);
    }
    if (data.containsKey('per_euro')) {
      context.handle(
        _perEuroMeta,
        perEuro.isAcceptableOrUnknown(data['per_euro']!, _perEuroMeta),
      );
    } else if (isInserting) {
      context.missing(_perEuroMeta);
    }
    if (data.containsKey('del')) {
      context.handle(
        _delMeta,
        del.isAcceptableOrUnknown(data['del']!, _delMeta),
      );
    } else if (isInserting) {
      context.missing(_delMeta);
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {valuta};
  @override
  TassoCambio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TassoCambio(
      valuta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuta'],
      )!,
      perEuro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}per_euro'],
      )!,
      del: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}del'],
      )!,
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
    );
  }

  @override
  $TassiCambioTable createAlias(String alias) {
    return $TassiCambioTable(attachedDatabase, alias);
  }
}

class TassoCambio extends DataClass implements Insertable<TassoCambio> {
  final String valuta;

  /// Quanto vale un euro in questa valuta. Testo, come gli importi.
  final String perEuro;

  /// Il giorno del tasso secondo il fornitore: `2026-10-03`.
  final String del;

  /// Quando questo telefono l'ha scaricato.
  final DateTime scaricatoIl;
  const TassoCambio({
    required this.valuta,
    required this.perEuro,
    required this.del,
    required this.scaricatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['valuta'] = Variable<String>(valuta);
    map['per_euro'] = Variable<String>(perEuro);
    map['del'] = Variable<String>(del);
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    return map;
  }

  TassiCambioCompanion toCompanion(bool nullToAbsent) {
    return TassiCambioCompanion(
      valuta: Value(valuta),
      perEuro: Value(perEuro),
      del: Value(del),
      scaricatoIl: Value(scaricatoIl),
    );
  }

  factory TassoCambio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TassoCambio(
      valuta: serializer.fromJson<String>(json['valuta']),
      perEuro: serializer.fromJson<String>(json['perEuro']),
      del: serializer.fromJson<String>(json['del']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'valuta': serializer.toJson<String>(valuta),
      'perEuro': serializer.toJson<String>(perEuro),
      'del': serializer.toJson<String>(del),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
    };
  }

  TassoCambio copyWith({
    String? valuta,
    String? perEuro,
    String? del,
    DateTime? scaricatoIl,
  }) => TassoCambio(
    valuta: valuta ?? this.valuta,
    perEuro: perEuro ?? this.perEuro,
    del: del ?? this.del,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
  );
  TassoCambio copyWithCompanion(TassiCambioCompanion data) {
    return TassoCambio(
      valuta: data.valuta.present ? data.valuta.value : this.valuta,
      perEuro: data.perEuro.present ? data.perEuro.value : this.perEuro,
      del: data.del.present ? data.del.value : this.del,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TassoCambio(')
          ..write('valuta: $valuta, ')
          ..write('perEuro: $perEuro, ')
          ..write('del: $del, ')
          ..write('scaricatoIl: $scaricatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(valuta, perEuro, del, scaricatoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TassoCambio &&
          other.valuta == this.valuta &&
          other.perEuro == this.perEuro &&
          other.del == this.del &&
          other.scaricatoIl == this.scaricatoIl);
}

class TassiCambioCompanion extends UpdateCompanion<TassoCambio> {
  final Value<String> valuta;
  final Value<String> perEuro;
  final Value<String> del;
  final Value<DateTime> scaricatoIl;
  final Value<int> rowid;
  const TassiCambioCompanion({
    this.valuta = const Value.absent(),
    this.perEuro = const Value.absent(),
    this.del = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TassiCambioCompanion.insert({
    required String valuta,
    required String perEuro,
    required String del,
    required DateTime scaricatoIl,
    this.rowid = const Value.absent(),
  }) : valuta = Value(valuta),
       perEuro = Value(perEuro),
       del = Value(del),
       scaricatoIl = Value(scaricatoIl);
  static Insertable<TassoCambio> custom({
    Expression<String>? valuta,
    Expression<String>? perEuro,
    Expression<String>? del,
    Expression<DateTime>? scaricatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (valuta != null) 'valuta': valuta,
      if (perEuro != null) 'per_euro': perEuro,
      if (del != null) 'del': del,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TassiCambioCompanion copyWith({
    Value<String>? valuta,
    Value<String>? perEuro,
    Value<String>? del,
    Value<DateTime>? scaricatoIl,
    Value<int>? rowid,
  }) {
    return TassiCambioCompanion(
      valuta: valuta ?? this.valuta,
      perEuro: perEuro ?? this.perEuro,
      del: del ?? this.del,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (valuta.present) {
      map['valuta'] = Variable<String>(valuta.value);
    }
    if (perEuro.present) {
      map['per_euro'] = Variable<String>(perEuro.value);
    }
    if (del.present) {
      map['del'] = Variable<String>(del.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TassiCambioCompanion(')
          ..write('valuta: $valuta, ')
          ..write('perEuro: $perEuro, ')
          ..write('del: $del, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConfigurazioniTable extends Configurazioni
    with TableInfo<$ConfigurazioniTable, Configurazione> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConfigurazioniTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chiaveMeta = const VerificationMeta('chiave');
  @override
  late final GeneratedColumn<String> chiave = GeneratedColumn<String>(
    'chiave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valoreMeta = const VerificationMeta('valore');
  @override
  late final GeneratedColumn<String> valore = GeneratedColumn<String>(
    'valore',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scaricatoIlMeta = const VerificationMeta(
    'scaricatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> scaricatoIl = GeneratedColumn<DateTime>(
    'scaricato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chiave, valore, scaricatoIl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'configurazione';
  @override
  VerificationContext validateIntegrity(
    Insertable<Configurazione> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chiave')) {
      context.handle(
        _chiaveMeta,
        chiave.isAcceptableOrUnknown(data['chiave']!, _chiaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chiaveMeta);
    }
    if (data.containsKey('valore')) {
      context.handle(
        _valoreMeta,
        valore.isAcceptableOrUnknown(data['valore']!, _valoreMeta),
      );
    } else if (isInserting) {
      context.missing(_valoreMeta);
    }
    if (data.containsKey('scaricato_il')) {
      context.handle(
        _scaricatoIlMeta,
        scaricatoIl.isAcceptableOrUnknown(
          data['scaricato_il']!,
          _scaricatoIlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scaricatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chiave};
  @override
  Configurazione map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Configurazione(
      chiave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chiave'],
      )!,
      valore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valore'],
      )!,
      scaricatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scaricato_il'],
      )!,
    );
  }

  @override
  $ConfigurazioniTable createAlias(String alias) {
    return $ConfigurazioniTable(attachedDatabase, alias);
  }
}

class Configurazione extends DataClass implements Insertable<Configurazione> {
  final String chiave;
  final String valore;
  final DateTime scaricatoIl;
  const Configurazione({
    required this.chiave,
    required this.valore,
    required this.scaricatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chiave'] = Variable<String>(chiave);
    map['valore'] = Variable<String>(valore);
    map['scaricato_il'] = Variable<DateTime>(scaricatoIl);
    return map;
  }

  ConfigurazioniCompanion toCompanion(bool nullToAbsent) {
    return ConfigurazioniCompanion(
      chiave: Value(chiave),
      valore: Value(valore),
      scaricatoIl: Value(scaricatoIl),
    );
  }

  factory Configurazione.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Configurazione(
      chiave: serializer.fromJson<String>(json['chiave']),
      valore: serializer.fromJson<String>(json['valore']),
      scaricatoIl: serializer.fromJson<DateTime>(json['scaricatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chiave': serializer.toJson<String>(chiave),
      'valore': serializer.toJson<String>(valore),
      'scaricatoIl': serializer.toJson<DateTime>(scaricatoIl),
    };
  }

  Configurazione copyWith({
    String? chiave,
    String? valore,
    DateTime? scaricatoIl,
  }) => Configurazione(
    chiave: chiave ?? this.chiave,
    valore: valore ?? this.valore,
    scaricatoIl: scaricatoIl ?? this.scaricatoIl,
  );
  Configurazione copyWithCompanion(ConfigurazioniCompanion data) {
    return Configurazione(
      chiave: data.chiave.present ? data.chiave.value : this.chiave,
      valore: data.valore.present ? data.valore.value : this.valore,
      scaricatoIl: data.scaricatoIl.present
          ? data.scaricatoIl.value
          : this.scaricatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Configurazione(')
          ..write('chiave: $chiave, ')
          ..write('valore: $valore, ')
          ..write('scaricatoIl: $scaricatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chiave, valore, scaricatoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Configurazione &&
          other.chiave == this.chiave &&
          other.valore == this.valore &&
          other.scaricatoIl == this.scaricatoIl);
}

class ConfigurazioniCompanion extends UpdateCompanion<Configurazione> {
  final Value<String> chiave;
  final Value<String> valore;
  final Value<DateTime> scaricatoIl;
  final Value<int> rowid;
  const ConfigurazioniCompanion({
    this.chiave = const Value.absent(),
    this.valore = const Value.absent(),
    this.scaricatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConfigurazioniCompanion.insert({
    required String chiave,
    required String valore,
    required DateTime scaricatoIl,
    this.rowid = const Value.absent(),
  }) : chiave = Value(chiave),
       valore = Value(valore),
       scaricatoIl = Value(scaricatoIl);
  static Insertable<Configurazione> custom({
    Expression<String>? chiave,
    Expression<String>? valore,
    Expression<DateTime>? scaricatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chiave != null) 'chiave': chiave,
      if (valore != null) 'valore': valore,
      if (scaricatoIl != null) 'scaricato_il': scaricatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConfigurazioniCompanion copyWith({
    Value<String>? chiave,
    Value<String>? valore,
    Value<DateTime>? scaricatoIl,
    Value<int>? rowid,
  }) {
    return ConfigurazioniCompanion(
      chiave: chiave ?? this.chiave,
      valore: valore ?? this.valore,
      scaricatoIl: scaricatoIl ?? this.scaricatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chiave.present) {
      map['chiave'] = Variable<String>(chiave.value);
    }
    if (valore.present) {
      map['valore'] = Variable<String>(valore.value);
    }
    if (scaricatoIl.present) {
      map['scaricato_il'] = Variable<DateTime>(scaricatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfigurazioniCompanion(')
          ..write('chiave: $chiave, ')
          ..write('valore: $valore, ')
          ..write('scaricatoIl: $scaricatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CodaScritturaTable extends CodaScrittura
    with TableInfo<$CodaScritturaTable, OperazioneInCoda> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CodaScritturaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<GestoOffline, String> gesto =
      GeneratedColumn<String>(
        'gesto',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<GestoOffline>($CodaScritturaTable.$convertergesto);
  static const VerificationMeta _caricoMeta = const VerificationMeta('carico');
  @override
  late final GeneratedColumn<String> carico = GeneratedColumn<String>(
    'carico',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creataIlMeta = const VerificationMeta(
    'creataIl',
  );
  @override
  late final GeneratedColumn<DateTime> creataIl = GeneratedColumn<DateTime>(
    'creata_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tentativiMeta = const VerificationMeta(
    'tentativi',
  );
  @override
  late final GeneratedColumn<int> tentativi = GeneratedColumn<int>(
    'tentativi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ultimoErroreMeta = const VerificationMeta(
    'ultimoErrore',
  );
  @override
  late final GeneratedColumn<String> ultimoErrore = GeneratedColumn<String>(
    'ultimo_errore',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messaDaParteMeta = const VerificationMeta(
    'messaDaParte',
  );
  @override
  late final GeneratedColumn<bool> messaDaParte = GeneratedColumn<bool>(
    'messa_da_parte',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("messa_da_parte" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    viaggioId,
    gesto,
    carico,
    creataIl,
    tentativi,
    ultimoErrore,
    messaDaParte,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coda_scrittura';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperazioneInCoda> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('carico')) {
      context.handle(
        _caricoMeta,
        carico.isAcceptableOrUnknown(data['carico']!, _caricoMeta),
      );
    } else if (isInserting) {
      context.missing(_caricoMeta);
    }
    if (data.containsKey('creata_il')) {
      context.handle(
        _creataIlMeta,
        creataIl.isAcceptableOrUnknown(data['creata_il']!, _creataIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creataIlMeta);
    }
    if (data.containsKey('tentativi')) {
      context.handle(
        _tentativiMeta,
        tentativi.isAcceptableOrUnknown(data['tentativi']!, _tentativiMeta),
      );
    }
    if (data.containsKey('ultimo_errore')) {
      context.handle(
        _ultimoErroreMeta,
        ultimoErrore.isAcceptableOrUnknown(
          data['ultimo_errore']!,
          _ultimoErroreMeta,
        ),
      );
    }
    if (data.containsKey('messa_da_parte')) {
      context.handle(
        _messaDaParteMeta,
        messaDaParte.isAcceptableOrUnknown(
          data['messa_da_parte']!,
          _messaDaParteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperazioneInCoda map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperazioneInCoda(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      gesto: $CodaScritturaTable.$convertergesto.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}gesto'],
        )!,
      ),
      carico: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}carico'],
      )!,
      creataIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creata_il'],
      )!,
      tentativi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tentativi'],
      )!,
      ultimoErrore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ultimo_errore'],
      ),
      messaDaParte: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}messa_da_parte'],
      )!,
    );
  }

  @override
  $CodaScritturaTable createAlias(String alias) {
    return $CodaScritturaTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<GestoOffline, String, String> $convertergesto =
      const EnumNameConverter<GestoOffline>(GestoOffline.values);
}

class OperazioneInCoda extends DataClass
    implements Insertable<OperazioneInCoda> {
  /// Generato dal client: rimandare l'operazione non la applica due volte.
  final String id;
  final String viaggioId;
  final GestoOffline gesto;

  /// La riga da inviare, in JSON, con i nomi di colonna del server.
  final String carico;
  final DateTime creataIl;
  final int tentativi;
  final String? ultimoErrore;

  /// Fallita ripetutamente: si segnala senza fermare quelle dietro.
  final bool messaDaParte;
  const OperazioneInCoda({
    required this.id,
    required this.viaggioId,
    required this.gesto,
    required this.carico,
    required this.creataIl,
    required this.tentativi,
    this.ultimoErrore,
    required this.messaDaParte,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['viaggio_id'] = Variable<String>(viaggioId);
    {
      map['gesto'] = Variable<String>(
        $CodaScritturaTable.$convertergesto.toSql(gesto),
      );
    }
    map['carico'] = Variable<String>(carico);
    map['creata_il'] = Variable<DateTime>(creataIl);
    map['tentativi'] = Variable<int>(tentativi);
    if (!nullToAbsent || ultimoErrore != null) {
      map['ultimo_errore'] = Variable<String>(ultimoErrore);
    }
    map['messa_da_parte'] = Variable<bool>(messaDaParte);
    return map;
  }

  CodaScritturaCompanion toCompanion(bool nullToAbsent) {
    return CodaScritturaCompanion(
      id: Value(id),
      viaggioId: Value(viaggioId),
      gesto: Value(gesto),
      carico: Value(carico),
      creataIl: Value(creataIl),
      tentativi: Value(tentativi),
      ultimoErrore: ultimoErrore == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimoErrore),
      messaDaParte: Value(messaDaParte),
    );
  }

  factory OperazioneInCoda.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperazioneInCoda(
      id: serializer.fromJson<String>(json['id']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      gesto: $CodaScritturaTable.$convertergesto.fromJson(
        serializer.fromJson<String>(json['gesto']),
      ),
      carico: serializer.fromJson<String>(json['carico']),
      creataIl: serializer.fromJson<DateTime>(json['creataIl']),
      tentativi: serializer.fromJson<int>(json['tentativi']),
      ultimoErrore: serializer.fromJson<String?>(json['ultimoErrore']),
      messaDaParte: serializer.fromJson<bool>(json['messaDaParte']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'gesto': serializer.toJson<String>(
        $CodaScritturaTable.$convertergesto.toJson(gesto),
      ),
      'carico': serializer.toJson<String>(carico),
      'creataIl': serializer.toJson<DateTime>(creataIl),
      'tentativi': serializer.toJson<int>(tentativi),
      'ultimoErrore': serializer.toJson<String?>(ultimoErrore),
      'messaDaParte': serializer.toJson<bool>(messaDaParte),
    };
  }

  OperazioneInCoda copyWith({
    String? id,
    String? viaggioId,
    GestoOffline? gesto,
    String? carico,
    DateTime? creataIl,
    int? tentativi,
    Value<String?> ultimoErrore = const Value.absent(),
    bool? messaDaParte,
  }) => OperazioneInCoda(
    id: id ?? this.id,
    viaggioId: viaggioId ?? this.viaggioId,
    gesto: gesto ?? this.gesto,
    carico: carico ?? this.carico,
    creataIl: creataIl ?? this.creataIl,
    tentativi: tentativi ?? this.tentativi,
    ultimoErrore: ultimoErrore.present ? ultimoErrore.value : this.ultimoErrore,
    messaDaParte: messaDaParte ?? this.messaDaParte,
  );
  OperazioneInCoda copyWithCompanion(CodaScritturaCompanion data) {
    return OperazioneInCoda(
      id: data.id.present ? data.id.value : this.id,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      gesto: data.gesto.present ? data.gesto.value : this.gesto,
      carico: data.carico.present ? data.carico.value : this.carico,
      creataIl: data.creataIl.present ? data.creataIl.value : this.creataIl,
      tentativi: data.tentativi.present ? data.tentativi.value : this.tentativi,
      ultimoErrore: data.ultimoErrore.present
          ? data.ultimoErrore.value
          : this.ultimoErrore,
      messaDaParte: data.messaDaParte.present
          ? data.messaDaParte.value
          : this.messaDaParte,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperazioneInCoda(')
          ..write('id: $id, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('gesto: $gesto, ')
          ..write('carico: $carico, ')
          ..write('creataIl: $creataIl, ')
          ..write('tentativi: $tentativi, ')
          ..write('ultimoErrore: $ultimoErrore, ')
          ..write('messaDaParte: $messaDaParte')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    viaggioId,
    gesto,
    carico,
    creataIl,
    tentativi,
    ultimoErrore,
    messaDaParte,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperazioneInCoda &&
          other.id == this.id &&
          other.viaggioId == this.viaggioId &&
          other.gesto == this.gesto &&
          other.carico == this.carico &&
          other.creataIl == this.creataIl &&
          other.tentativi == this.tentativi &&
          other.ultimoErrore == this.ultimoErrore &&
          other.messaDaParte == this.messaDaParte);
}

class CodaScritturaCompanion extends UpdateCompanion<OperazioneInCoda> {
  final Value<String> id;
  final Value<String> viaggioId;
  final Value<GestoOffline> gesto;
  final Value<String> carico;
  final Value<DateTime> creataIl;
  final Value<int> tentativi;
  final Value<String?> ultimoErrore;
  final Value<bool> messaDaParte;
  final Value<int> rowid;
  const CodaScritturaCompanion({
    this.id = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.gesto = const Value.absent(),
    this.carico = const Value.absent(),
    this.creataIl = const Value.absent(),
    this.tentativi = const Value.absent(),
    this.ultimoErrore = const Value.absent(),
    this.messaDaParte = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CodaScritturaCompanion.insert({
    required String id,
    required String viaggioId,
    required GestoOffline gesto,
    required String carico,
    required DateTime creataIl,
    this.tentativi = const Value.absent(),
    this.ultimoErrore = const Value.absent(),
    this.messaDaParte = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       viaggioId = Value(viaggioId),
       gesto = Value(gesto),
       carico = Value(carico),
       creataIl = Value(creataIl);
  static Insertable<OperazioneInCoda> custom({
    Expression<String>? id,
    Expression<String>? viaggioId,
    Expression<String>? gesto,
    Expression<String>? carico,
    Expression<DateTime>? creataIl,
    Expression<int>? tentativi,
    Expression<String>? ultimoErrore,
    Expression<bool>? messaDaParte,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (gesto != null) 'gesto': gesto,
      if (carico != null) 'carico': carico,
      if (creataIl != null) 'creata_il': creataIl,
      if (tentativi != null) 'tentativi': tentativi,
      if (ultimoErrore != null) 'ultimo_errore': ultimoErrore,
      if (messaDaParte != null) 'messa_da_parte': messaDaParte,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CodaScritturaCompanion copyWith({
    Value<String>? id,
    Value<String>? viaggioId,
    Value<GestoOffline>? gesto,
    Value<String>? carico,
    Value<DateTime>? creataIl,
    Value<int>? tentativi,
    Value<String?>? ultimoErrore,
    Value<bool>? messaDaParte,
    Value<int>? rowid,
  }) {
    return CodaScritturaCompanion(
      id: id ?? this.id,
      viaggioId: viaggioId ?? this.viaggioId,
      gesto: gesto ?? this.gesto,
      carico: carico ?? this.carico,
      creataIl: creataIl ?? this.creataIl,
      tentativi: tentativi ?? this.tentativi,
      ultimoErrore: ultimoErrore ?? this.ultimoErrore,
      messaDaParte: messaDaParte ?? this.messaDaParte,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (gesto.present) {
      map['gesto'] = Variable<String>(
        $CodaScritturaTable.$convertergesto.toSql(gesto.value),
      );
    }
    if (carico.present) {
      map['carico'] = Variable<String>(carico.value);
    }
    if (creataIl.present) {
      map['creata_il'] = Variable<DateTime>(creataIl.value);
    }
    if (tentativi.present) {
      map['tentativi'] = Variable<int>(tentativi.value);
    }
    if (ultimoErrore.present) {
      map['ultimo_errore'] = Variable<String>(ultimoErrore.value);
    }
    if (messaDaParte.present) {
      map['messa_da_parte'] = Variable<bool>(messaDaParte.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CodaScritturaCompanion(')
          ..write('id: $id, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('gesto: $gesto, ')
          ..write('carico: $carico, ')
          ..write('creataIl: $creataIl, ')
          ..write('tentativi: $tentativi, ')
          ..write('ultimoErrore: $ultimoErrore, ')
          ..write('messaDaParte: $messaDaParte, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentiTable extends Documenti
    with TableInfo<$DocumentiTable, Documento> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viaggioIdMeta = const VerificationMeta(
    'viaggioId',
  );
  @override
  late final GeneratedColumn<String> viaggioId = GeneratedColumn<String>(
    'viaggio_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _giornoIdMeta = const VerificationMeta(
    'giornoId',
  );
  @override
  late final GeneratedColumn<String> giornoId = GeneratedColumn<String>(
    'giorno_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oraMeta = const VerificationMeta('ora');
  @override
  late final GeneratedColumn<String> ora = GeneratedColumn<String>(
    'ora',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percorsoLocaleMeta = const VerificationMeta(
    'percorsoLocale',
  );
  @override
  late final GeneratedColumn<String> percorsoLocale = GeneratedColumn<String>(
    'percorso_locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatoMeta = const VerificationMeta(
    'formato',
  );
  @override
  late final GeneratedColumn<String> formato = GeneratedColumn<String>(
    'formato',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pagineMeta = const VerificationMeta('pagine');
  @override
  late final GeneratedColumn<int> pagine = GeneratedColumn<int>(
    'pagine',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sorgenteMeta = const VerificationMeta(
    'sorgente',
  );
  @override
  late final GeneratedColumn<String> sorgente = GeneratedColumn<String>(
    'sorgente',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proprietarioIdMeta = const VerificationMeta(
    'proprietarioId',
  );
  @override
  late final GeneratedColumn<String> proprietarioId = GeneratedColumn<String>(
    'proprietario_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatoIlMeta = const VerificationMeta(
    'creatoIl',
  );
  @override
  late final GeneratedColumn<DateTime> creatoIl = GeneratedColumn<DateTime>(
    'creato_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    viaggioId,
    giornoId,
    ora,
    nome,
    percorsoLocale,
    formato,
    pagine,
    sorgente,
    proprietarioId,
    creatoIl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documento';
  @override
  VerificationContext validateIntegrity(
    Insertable<Documento> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('viaggio_id')) {
      context.handle(
        _viaggioIdMeta,
        viaggioId.isAcceptableOrUnknown(data['viaggio_id']!, _viaggioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viaggioIdMeta);
    }
    if (data.containsKey('giorno_id')) {
      context.handle(
        _giornoIdMeta,
        giornoId.isAcceptableOrUnknown(data['giorno_id']!, _giornoIdMeta),
      );
    }
    if (data.containsKey('ora')) {
      context.handle(
        _oraMeta,
        ora.isAcceptableOrUnknown(data['ora']!, _oraMeta),
      );
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('percorso_locale')) {
      context.handle(
        _percorsoLocaleMeta,
        percorsoLocale.isAcceptableOrUnknown(
          data['percorso_locale']!,
          _percorsoLocaleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_percorsoLocaleMeta);
    }
    if (data.containsKey('formato')) {
      context.handle(
        _formatoMeta,
        formato.isAcceptableOrUnknown(data['formato']!, _formatoMeta),
      );
    } else if (isInserting) {
      context.missing(_formatoMeta);
    }
    if (data.containsKey('pagine')) {
      context.handle(
        _pagineMeta,
        pagine.isAcceptableOrUnknown(data['pagine']!, _pagineMeta),
      );
    }
    if (data.containsKey('sorgente')) {
      context.handle(
        _sorgenteMeta,
        sorgente.isAcceptableOrUnknown(data['sorgente']!, _sorgenteMeta),
      );
    } else if (isInserting) {
      context.missing(_sorgenteMeta);
    }
    if (data.containsKey('proprietario_id')) {
      context.handle(
        _proprietarioIdMeta,
        proprietarioId.isAcceptableOrUnknown(
          data['proprietario_id']!,
          _proprietarioIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_proprietarioIdMeta);
    }
    if (data.containsKey('creato_il')) {
      context.handle(
        _creatoIlMeta,
        creatoIl.isAcceptableOrUnknown(data['creato_il']!, _creatoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_creatoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Documento map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Documento(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      viaggioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viaggio_id'],
      )!,
      giornoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}giorno_id'],
      ),
      ora: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ora'],
      ),
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      percorsoLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}percorso_locale'],
      )!,
      formato: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}formato'],
      )!,
      pagine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pagine'],
      ),
      sorgente: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sorgente'],
      )!,
      proprietarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proprietario_id'],
      )!,
      creatoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creato_il'],
      )!,
    );
  }

  @override
  $DocumentiTable createAlias(String alias) {
    return $DocumentiTable(attachedDatabase, alias);
  }
}

class Documento extends DataClass implements Insertable<Documento> {
  final String id;
  final String viaggioId;

  /// Il giorno in cui serve; nessuno se serve per tutto il viaggio.
  final String? giornoId;

  /// A che ora serve, `07:05:00`, se si è detto.
  final String? ora;
  final String nome;

  /// Relativo alla cartella dell'app, mai assoluto: ripristinato da un backup
  /// su un telefono nuovo, il contenitore dell'app ha un altro percorso (03).
  final String percorsoLocale;

  /// `pdf` o `immagine` (dominio/documenti.dart).
  final String formato;

  /// Quante pagine ha, se è un PDF.
  final int? pagine;

  /// Da dove è arrivato: `scansione`, `foto`, `file`.
  final String sorgente;

  /// Chi l'ha aggiunto: su un telefono dove entra un'altra persona, non si vede.
  final String proprietarioId;
  final DateTime creatoIl;
  const Documento({
    required this.id,
    required this.viaggioId,
    this.giornoId,
    this.ora,
    required this.nome,
    required this.percorsoLocale,
    required this.formato,
    this.pagine,
    required this.sorgente,
    required this.proprietarioId,
    required this.creatoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['viaggio_id'] = Variable<String>(viaggioId);
    if (!nullToAbsent || giornoId != null) {
      map['giorno_id'] = Variable<String>(giornoId);
    }
    if (!nullToAbsent || ora != null) {
      map['ora'] = Variable<String>(ora);
    }
    map['nome'] = Variable<String>(nome);
    map['percorso_locale'] = Variable<String>(percorsoLocale);
    map['formato'] = Variable<String>(formato);
    if (!nullToAbsent || pagine != null) {
      map['pagine'] = Variable<int>(pagine);
    }
    map['sorgente'] = Variable<String>(sorgente);
    map['proprietario_id'] = Variable<String>(proprietarioId);
    map['creato_il'] = Variable<DateTime>(creatoIl);
    return map;
  }

  DocumentiCompanion toCompanion(bool nullToAbsent) {
    return DocumentiCompanion(
      id: Value(id),
      viaggioId: Value(viaggioId),
      giornoId: giornoId == null && nullToAbsent
          ? const Value.absent()
          : Value(giornoId),
      ora: ora == null && nullToAbsent ? const Value.absent() : Value(ora),
      nome: Value(nome),
      percorsoLocale: Value(percorsoLocale),
      formato: Value(formato),
      pagine: pagine == null && nullToAbsent
          ? const Value.absent()
          : Value(pagine),
      sorgente: Value(sorgente),
      proprietarioId: Value(proprietarioId),
      creatoIl: Value(creatoIl),
    );
  }

  factory Documento.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Documento(
      id: serializer.fromJson<String>(json['id']),
      viaggioId: serializer.fromJson<String>(json['viaggioId']),
      giornoId: serializer.fromJson<String?>(json['giornoId']),
      ora: serializer.fromJson<String?>(json['ora']),
      nome: serializer.fromJson<String>(json['nome']),
      percorsoLocale: serializer.fromJson<String>(json['percorsoLocale']),
      formato: serializer.fromJson<String>(json['formato']),
      pagine: serializer.fromJson<int?>(json['pagine']),
      sorgente: serializer.fromJson<String>(json['sorgente']),
      proprietarioId: serializer.fromJson<String>(json['proprietarioId']),
      creatoIl: serializer.fromJson<DateTime>(json['creatoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'viaggioId': serializer.toJson<String>(viaggioId),
      'giornoId': serializer.toJson<String?>(giornoId),
      'ora': serializer.toJson<String?>(ora),
      'nome': serializer.toJson<String>(nome),
      'percorsoLocale': serializer.toJson<String>(percorsoLocale),
      'formato': serializer.toJson<String>(formato),
      'pagine': serializer.toJson<int?>(pagine),
      'sorgente': serializer.toJson<String>(sorgente),
      'proprietarioId': serializer.toJson<String>(proprietarioId),
      'creatoIl': serializer.toJson<DateTime>(creatoIl),
    };
  }

  Documento copyWith({
    String? id,
    String? viaggioId,
    Value<String?> giornoId = const Value.absent(),
    Value<String?> ora = const Value.absent(),
    String? nome,
    String? percorsoLocale,
    String? formato,
    Value<int?> pagine = const Value.absent(),
    String? sorgente,
    String? proprietarioId,
    DateTime? creatoIl,
  }) => Documento(
    id: id ?? this.id,
    viaggioId: viaggioId ?? this.viaggioId,
    giornoId: giornoId.present ? giornoId.value : this.giornoId,
    ora: ora.present ? ora.value : this.ora,
    nome: nome ?? this.nome,
    percorsoLocale: percorsoLocale ?? this.percorsoLocale,
    formato: formato ?? this.formato,
    pagine: pagine.present ? pagine.value : this.pagine,
    sorgente: sorgente ?? this.sorgente,
    proprietarioId: proprietarioId ?? this.proprietarioId,
    creatoIl: creatoIl ?? this.creatoIl,
  );
  Documento copyWithCompanion(DocumentiCompanion data) {
    return Documento(
      id: data.id.present ? data.id.value : this.id,
      viaggioId: data.viaggioId.present ? data.viaggioId.value : this.viaggioId,
      giornoId: data.giornoId.present ? data.giornoId.value : this.giornoId,
      ora: data.ora.present ? data.ora.value : this.ora,
      nome: data.nome.present ? data.nome.value : this.nome,
      percorsoLocale: data.percorsoLocale.present
          ? data.percorsoLocale.value
          : this.percorsoLocale,
      formato: data.formato.present ? data.formato.value : this.formato,
      pagine: data.pagine.present ? data.pagine.value : this.pagine,
      sorgente: data.sorgente.present ? data.sorgente.value : this.sorgente,
      proprietarioId: data.proprietarioId.present
          ? data.proprietarioId.value
          : this.proprietarioId,
      creatoIl: data.creatoIl.present ? data.creatoIl.value : this.creatoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Documento(')
          ..write('id: $id, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('giornoId: $giornoId, ')
          ..write('ora: $ora, ')
          ..write('nome: $nome, ')
          ..write('percorsoLocale: $percorsoLocale, ')
          ..write('formato: $formato, ')
          ..write('pagine: $pagine, ')
          ..write('sorgente: $sorgente, ')
          ..write('proprietarioId: $proprietarioId, ')
          ..write('creatoIl: $creatoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    viaggioId,
    giornoId,
    ora,
    nome,
    percorsoLocale,
    formato,
    pagine,
    sorgente,
    proprietarioId,
    creatoIl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Documento &&
          other.id == this.id &&
          other.viaggioId == this.viaggioId &&
          other.giornoId == this.giornoId &&
          other.ora == this.ora &&
          other.nome == this.nome &&
          other.percorsoLocale == this.percorsoLocale &&
          other.formato == this.formato &&
          other.pagine == this.pagine &&
          other.sorgente == this.sorgente &&
          other.proprietarioId == this.proprietarioId &&
          other.creatoIl == this.creatoIl);
}

class DocumentiCompanion extends UpdateCompanion<Documento> {
  final Value<String> id;
  final Value<String> viaggioId;
  final Value<String?> giornoId;
  final Value<String?> ora;
  final Value<String> nome;
  final Value<String> percorsoLocale;
  final Value<String> formato;
  final Value<int?> pagine;
  final Value<String> sorgente;
  final Value<String> proprietarioId;
  final Value<DateTime> creatoIl;
  final Value<int> rowid;
  const DocumentiCompanion({
    this.id = const Value.absent(),
    this.viaggioId = const Value.absent(),
    this.giornoId = const Value.absent(),
    this.ora = const Value.absent(),
    this.nome = const Value.absent(),
    this.percorsoLocale = const Value.absent(),
    this.formato = const Value.absent(),
    this.pagine = const Value.absent(),
    this.sorgente = const Value.absent(),
    this.proprietarioId = const Value.absent(),
    this.creatoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentiCompanion.insert({
    required String id,
    required String viaggioId,
    this.giornoId = const Value.absent(),
    this.ora = const Value.absent(),
    required String nome,
    required String percorsoLocale,
    required String formato,
    this.pagine = const Value.absent(),
    required String sorgente,
    required String proprietarioId,
    required DateTime creatoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       viaggioId = Value(viaggioId),
       nome = Value(nome),
       percorsoLocale = Value(percorsoLocale),
       formato = Value(formato),
       sorgente = Value(sorgente),
       proprietarioId = Value(proprietarioId),
       creatoIl = Value(creatoIl);
  static Insertable<Documento> custom({
    Expression<String>? id,
    Expression<String>? viaggioId,
    Expression<String>? giornoId,
    Expression<String>? ora,
    Expression<String>? nome,
    Expression<String>? percorsoLocale,
    Expression<String>? formato,
    Expression<int>? pagine,
    Expression<String>? sorgente,
    Expression<String>? proprietarioId,
    Expression<DateTime>? creatoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (viaggioId != null) 'viaggio_id': viaggioId,
      if (giornoId != null) 'giorno_id': giornoId,
      if (ora != null) 'ora': ora,
      if (nome != null) 'nome': nome,
      if (percorsoLocale != null) 'percorso_locale': percorsoLocale,
      if (formato != null) 'formato': formato,
      if (pagine != null) 'pagine': pagine,
      if (sorgente != null) 'sorgente': sorgente,
      if (proprietarioId != null) 'proprietario_id': proprietarioId,
      if (creatoIl != null) 'creato_il': creatoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentiCompanion copyWith({
    Value<String>? id,
    Value<String>? viaggioId,
    Value<String?>? giornoId,
    Value<String?>? ora,
    Value<String>? nome,
    Value<String>? percorsoLocale,
    Value<String>? formato,
    Value<int?>? pagine,
    Value<String>? sorgente,
    Value<String>? proprietarioId,
    Value<DateTime>? creatoIl,
    Value<int>? rowid,
  }) {
    return DocumentiCompanion(
      id: id ?? this.id,
      viaggioId: viaggioId ?? this.viaggioId,
      giornoId: giornoId ?? this.giornoId,
      ora: ora ?? this.ora,
      nome: nome ?? this.nome,
      percorsoLocale: percorsoLocale ?? this.percorsoLocale,
      formato: formato ?? this.formato,
      pagine: pagine ?? this.pagine,
      sorgente: sorgente ?? this.sorgente,
      proprietarioId: proprietarioId ?? this.proprietarioId,
      creatoIl: creatoIl ?? this.creatoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (viaggioId.present) {
      map['viaggio_id'] = Variable<String>(viaggioId.value);
    }
    if (giornoId.present) {
      map['giorno_id'] = Variable<String>(giornoId.value);
    }
    if (ora.present) {
      map['ora'] = Variable<String>(ora.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (percorsoLocale.present) {
      map['percorso_locale'] = Variable<String>(percorsoLocale.value);
    }
    if (formato.present) {
      map['formato'] = Variable<String>(formato.value);
    }
    if (pagine.present) {
      map['pagine'] = Variable<int>(pagine.value);
    }
    if (sorgente.present) {
      map['sorgente'] = Variable<String>(sorgente.value);
    }
    if (proprietarioId.present) {
      map['proprietario_id'] = Variable<String>(proprietarioId.value);
    }
    if (creatoIl.present) {
      map['creato_il'] = Variable<DateTime>(creatoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentiCompanion(')
          ..write('id: $id, ')
          ..write('viaggioId: $viaggioId, ')
          ..write('giornoId: $giornoId, ')
          ..write('ora: $ora, ')
          ..write('nome: $nome, ')
          ..write('percorsoLocale: $percorsoLocale, ')
          ..write('formato: $formato, ')
          ..write('pagine: $pagine, ')
          ..write('sorgente: $sorgente, ')
          ..write('proprietarioId: $proprietarioId, ')
          ..write('creatoIl: $creatoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventiInAttesaTable extends EventiInAttesa
    with TableInfo<$EventiInAttesaTable, EventoInAttesa> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventiInAttesaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proprietaMeta = const VerificationMeta(
    'proprieta',
  );
  @override
  late final GeneratedColumn<String> proprieta = GeneratedColumn<String>(
    'proprieta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avvenutoIlMeta = const VerificationMeta(
    'avvenutoIl',
  );
  @override
  late final GeneratedColumn<DateTime> avvenutoIl = GeneratedColumn<DateTime>(
    'avvenuto_il',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nome, proprieta, avvenutoIl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evento_in_attesa';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventoInAttesa> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('proprieta')) {
      context.handle(
        _proprietaMeta,
        proprieta.isAcceptableOrUnknown(data['proprieta']!, _proprietaMeta),
      );
    } else if (isInserting) {
      context.missing(_proprietaMeta);
    }
    if (data.containsKey('avvenuto_il')) {
      context.handle(
        _avvenutoIlMeta,
        avvenutoIl.isAcceptableOrUnknown(data['avvenuto_il']!, _avvenutoIlMeta),
      );
    } else if (isInserting) {
      context.missing(_avvenutoIlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventoInAttesa map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventoInAttesa(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      proprieta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proprieta'],
      )!,
      avvenutoIl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}avvenuto_il'],
      )!,
    );
  }

  @override
  $EventiInAttesaTable createAlias(String alias) {
    return $EventiInAttesaTable(attachedDatabase, alias);
  }
}

class EventoInAttesa extends DataClass implements Insertable<EventoInAttesa> {
  final String id;
  final String nome;
  final String proprieta;

  /// Quando è avvenuto, non quando parte.
  final DateTime avvenutoIl;
  const EventoInAttesa({
    required this.id,
    required this.nome,
    required this.proprieta,
    required this.avvenutoIl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nome'] = Variable<String>(nome);
    map['proprieta'] = Variable<String>(proprieta);
    map['avvenuto_il'] = Variable<DateTime>(avvenutoIl);
    return map;
  }

  EventiInAttesaCompanion toCompanion(bool nullToAbsent) {
    return EventiInAttesaCompanion(
      id: Value(id),
      nome: Value(nome),
      proprieta: Value(proprieta),
      avvenutoIl: Value(avvenutoIl),
    );
  }

  factory EventoInAttesa.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventoInAttesa(
      id: serializer.fromJson<String>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      proprieta: serializer.fromJson<String>(json['proprieta']),
      avvenutoIl: serializer.fromJson<DateTime>(json['avvenutoIl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nome': serializer.toJson<String>(nome),
      'proprieta': serializer.toJson<String>(proprieta),
      'avvenutoIl': serializer.toJson<DateTime>(avvenutoIl),
    };
  }

  EventoInAttesa copyWith({
    String? id,
    String? nome,
    String? proprieta,
    DateTime? avvenutoIl,
  }) => EventoInAttesa(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    proprieta: proprieta ?? this.proprieta,
    avvenutoIl: avvenutoIl ?? this.avvenutoIl,
  );
  EventoInAttesa copyWithCompanion(EventiInAttesaCompanion data) {
    return EventoInAttesa(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      proprieta: data.proprieta.present ? data.proprieta.value : this.proprieta,
      avvenutoIl: data.avvenutoIl.present
          ? data.avvenutoIl.value
          : this.avvenutoIl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventoInAttesa(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('proprieta: $proprieta, ')
          ..write('avvenutoIl: $avvenutoIl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nome, proprieta, avvenutoIl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventoInAttesa &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.proprieta == this.proprieta &&
          other.avvenutoIl == this.avvenutoIl);
}

class EventiInAttesaCompanion extends UpdateCompanion<EventoInAttesa> {
  final Value<String> id;
  final Value<String> nome;
  final Value<String> proprieta;
  final Value<DateTime> avvenutoIl;
  final Value<int> rowid;
  const EventiInAttesaCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.proprieta = const Value.absent(),
    this.avvenutoIl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventiInAttesaCompanion.insert({
    required String id,
    required String nome,
    required String proprieta,
    required DateTime avvenutoIl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nome = Value(nome),
       proprieta = Value(proprieta),
       avvenutoIl = Value(avvenutoIl);
  static Insertable<EventoInAttesa> custom({
    Expression<String>? id,
    Expression<String>? nome,
    Expression<String>? proprieta,
    Expression<DateTime>? avvenutoIl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (proprieta != null) 'proprieta': proprieta,
      if (avvenutoIl != null) 'avvenuto_il': avvenutoIl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventiInAttesaCompanion copyWith({
    Value<String>? id,
    Value<String>? nome,
    Value<String>? proprieta,
    Value<DateTime>? avvenutoIl,
    Value<int>? rowid,
  }) {
    return EventiInAttesaCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      proprieta: proprieta ?? this.proprieta,
      avvenutoIl: avvenutoIl ?? this.avvenutoIl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (proprieta.present) {
      map['proprieta'] = Variable<String>(proprieta.value);
    }
    if (avvenutoIl.present) {
      map['avvenuto_il'] = Variable<DateTime>(avvenutoIl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventiInAttesaCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('proprieta: $proprieta, ')
          ..write('avvenutoIl: $avvenutoIl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImpostazioniTable extends Impostazioni
    with TableInfo<$ImpostazioniTable, Impostazione> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImpostazioniTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chiaveMeta = const VerificationMeta('chiave');
  @override
  late final GeneratedColumn<String> chiave = GeneratedColumn<String>(
    'chiave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valoreMeta = const VerificationMeta('valore');
  @override
  late final GeneratedColumn<String> valore = GeneratedColumn<String>(
    'valore',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chiave, valore];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'impostazione';
  @override
  VerificationContext validateIntegrity(
    Insertable<Impostazione> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chiave')) {
      context.handle(
        _chiaveMeta,
        chiave.isAcceptableOrUnknown(data['chiave']!, _chiaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chiaveMeta);
    }
    if (data.containsKey('valore')) {
      context.handle(
        _valoreMeta,
        valore.isAcceptableOrUnknown(data['valore']!, _valoreMeta),
      );
    } else if (isInserting) {
      context.missing(_valoreMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chiave};
  @override
  Impostazione map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Impostazione(
      chiave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chiave'],
      )!,
      valore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valore'],
      )!,
    );
  }

  @override
  $ImpostazioniTable createAlias(String alias) {
    return $ImpostazioniTable(attachedDatabase, alias);
  }
}

class Impostazione extends DataClass implements Insertable<Impostazione> {
  final String chiave;
  final String valore;
  const Impostazione({required this.chiave, required this.valore});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chiave'] = Variable<String>(chiave);
    map['valore'] = Variable<String>(valore);
    return map;
  }

  ImpostazioniCompanion toCompanion(bool nullToAbsent) {
    return ImpostazioniCompanion(chiave: Value(chiave), valore: Value(valore));
  }

  factory Impostazione.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Impostazione(
      chiave: serializer.fromJson<String>(json['chiave']),
      valore: serializer.fromJson<String>(json['valore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chiave': serializer.toJson<String>(chiave),
      'valore': serializer.toJson<String>(valore),
    };
  }

  Impostazione copyWith({String? chiave, String? valore}) => Impostazione(
    chiave: chiave ?? this.chiave,
    valore: valore ?? this.valore,
  );
  Impostazione copyWithCompanion(ImpostazioniCompanion data) {
    return Impostazione(
      chiave: data.chiave.present ? data.chiave.value : this.chiave,
      valore: data.valore.present ? data.valore.value : this.valore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Impostazione(')
          ..write('chiave: $chiave, ')
          ..write('valore: $valore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chiave, valore);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Impostazione &&
          other.chiave == this.chiave &&
          other.valore == this.valore);
}

class ImpostazioniCompanion extends UpdateCompanion<Impostazione> {
  final Value<String> chiave;
  final Value<String> valore;
  final Value<int> rowid;
  const ImpostazioniCompanion({
    this.chiave = const Value.absent(),
    this.valore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImpostazioniCompanion.insert({
    required String chiave,
    required String valore,
    this.rowid = const Value.absent(),
  }) : chiave = Value(chiave),
       valore = Value(valore);
  static Insertable<Impostazione> custom({
    Expression<String>? chiave,
    Expression<String>? valore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chiave != null) 'chiave': chiave,
      if (valore != null) 'valore': valore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImpostazioniCompanion copyWith({
    Value<String>? chiave,
    Value<String>? valore,
    Value<int>? rowid,
  }) {
    return ImpostazioniCompanion(
      chiave: chiave ?? this.chiave,
      valore: valore ?? this.valore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chiave.present) {
      map['chiave'] = Variable<String>(chiave.value);
    }
    if (valore.present) {
      map['valore'] = Variable<String>(valore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImpostazioniCompanion(')
          ..write('chiave: $chiave, ')
          ..write('valore: $valore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DatabaseLocale extends GeneratedDatabase {
  _$DatabaseLocale(QueryExecutor e) : super(e);
  $DatabaseLocaleManager get managers => $DatabaseLocaleManager(this);
  late final $UtentiTable utenti = $UtentiTable(this);
  late final $ViaggiTable viaggi = $ViaggiTable(this);
  late final $PartecipazioniTable partecipazioni = $PartecipazioniTable(this);
  late final $GiorniTable giorni = $GiorniTable(this);
  late final $TappeTable tappe = $TappeTable(this);
  late final $SpeseTable spese = $SpeseTable(this);
  late final $SpeseQuoteTable speseQuote = $SpeseQuoteTable(this);
  late final $VociListaTable vociLista = $VociListaTable(this);
  late final $NoteTable note = $NoteTable(this);
  late final $TassiCambioTable tassiCambio = $TassiCambioTable(this);
  late final $ConfigurazioniTable configurazioni = $ConfigurazioniTable(this);
  late final $CodaScritturaTable codaScrittura = $CodaScritturaTable(this);
  late final $DocumentiTable documenti = $DocumentiTable(this);
  late final $EventiInAttesaTable eventiInAttesa = $EventiInAttesaTable(this);
  late final $ImpostazioniTable impostazioni = $ImpostazioniTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
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
    codaScrittura,
    documenti,
    eventiInAttesa,
    impostazioni,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$UtentiTableCreateCompanionBuilder = UtentiCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String nome,
  Value<String?> dataNascita,
  Value<String?> valutaPredefinita,
  Value<int> rowid,
});
typedef $$UtentiTableUpdateCompanionBuilder = UtentiCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> nome,
  Value<String?> dataNascita,
  Value<String?> valutaPredefinita,
  Value<int> rowid,
});

class $$UtentiTableFilterComposer
    extends Composer<_$DatabaseLocale, $UtentiTable> {
  $$UtentiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataNascita => $composableBuilder(
    column: $table.dataNascita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valutaPredefinita => $composableBuilder(
    column: $table.valutaPredefinita,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UtentiTableOrderingComposer
    extends Composer<_$DatabaseLocale, $UtentiTable> {
  $$UtentiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataNascita => $composableBuilder(
    column: $table.dataNascita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valutaPredefinita => $composableBuilder(
    column: $table.valutaPredefinita,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UtentiTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $UtentiTable> {
  $$UtentiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get dataNascita => $composableBuilder(
    column: $table.dataNascita,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valutaPredefinita => $composableBuilder(
    column: $table.valutaPredefinita,
    builder: (column) => column,
  );
}

class $$UtentiTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $UtentiTable,
          Utente,
          $$UtentiTableFilterComposer,
          $$UtentiTableOrderingComposer,
          $$UtentiTableAnnotationComposer,
          $$UtentiTableCreateCompanionBuilder,
          $$UtentiTableUpdateCompanionBuilder,
          (Utente, BaseReferences<_$DatabaseLocale, $UtentiTable, Utente>),
          Utente,
          PrefetchHooks Function()
        > {
  $$UtentiTableTableManager(_$DatabaseLocale db, $UtentiTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UtentiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UtentiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UtentiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String?> dataNascita = const Value.absent(),
                Value<String?> valutaPredefinita = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UtentiCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                nome: nome,
                dataNascita: dataNascita,
                valutaPredefinita: valutaPredefinita,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String nome,
                Value<String?> dataNascita = const Value.absent(),
                Value<String?> valutaPredefinita = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UtentiCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                nome: nome,
                dataNascita: dataNascita,
                valutaPredefinita: valutaPredefinita,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UtentiTable, Utente>(table),
                  BaseReferences<_$DatabaseLocale, $UtentiTable, Utente>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UtentiTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $UtentiTable,
      Utente,
      $$UtentiTableFilterComposer,
      $$UtentiTableOrderingComposer,
      $$UtentiTableAnnotationComposer,
      $$UtentiTableCreateCompanionBuilder,
      $$UtentiTableUpdateCompanionBuilder,
      (Utente, BaseReferences<_$DatabaseLocale, $UtentiTable, Utente>),
      Utente,
      PrefetchHooks Function()
    >;
typedef $$ViaggiTableCreateCompanionBuilder = ViaggiCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String stato,
  Value<String?> destinazioneCitta,
  Value<String?> destinazionePaese,
  Value<String?> periodoApprossimativo,
  Value<String?> dataInizio,
  Value<String?> dataFine,
  Value<String?> oraArrivo,
  Value<String?> oraPartenza,
  required String creatoreId,
  required bool importato,
  required bool verificato,
  required String creatoIl,
  Value<int> rowid,
});
typedef $$ViaggiTableUpdateCompanionBuilder = ViaggiCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> stato,
  Value<String?> destinazioneCitta,
  Value<String?> destinazionePaese,
  Value<String?> periodoApprossimativo,
  Value<String?> dataInizio,
  Value<String?> dataFine,
  Value<String?> oraArrivo,
  Value<String?> oraPartenza,
  Value<String> creatoreId,
  Value<bool> importato,
  Value<bool> verificato,
  Value<String> creatoIl,
  Value<int> rowid,
});

class $$ViaggiTableFilterComposer
    extends Composer<_$DatabaseLocale, $ViaggiTable> {
  $$ViaggiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinazioneCitta => $composableBuilder(
    column: $table.destinazioneCitta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinazionePaese => $composableBuilder(
    column: $table.destinazionePaese,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodoApprossimativo => $composableBuilder(
    column: $table.periodoApprossimativo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataInizio => $composableBuilder(
    column: $table.dataInizio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataFine => $composableBuilder(
    column: $table.dataFine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oraArrivo => $composableBuilder(
    column: $table.oraArrivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oraPartenza => $composableBuilder(
    column: $table.oraPartenza,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoreId => $composableBuilder(
    column: $table.creatoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get importato => $composableBuilder(
    column: $table.importato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verificato => $composableBuilder(
    column: $table.verificato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ViaggiTableOrderingComposer
    extends Composer<_$DatabaseLocale, $ViaggiTable> {
  $$ViaggiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinazioneCitta => $composableBuilder(
    column: $table.destinazioneCitta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinazionePaese => $composableBuilder(
    column: $table.destinazionePaese,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodoApprossimativo => $composableBuilder(
    column: $table.periodoApprossimativo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataInizio => $composableBuilder(
    column: $table.dataInizio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataFine => $composableBuilder(
    column: $table.dataFine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oraArrivo => $composableBuilder(
    column: $table.oraArrivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oraPartenza => $composableBuilder(
    column: $table.oraPartenza,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoreId => $composableBuilder(
    column: $table.creatoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get importato => $composableBuilder(
    column: $table.importato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verificato => $composableBuilder(
    column: $table.verificato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ViaggiTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $ViaggiTable> {
  $$ViaggiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stato =>
      $composableBuilder(column: $table.stato, builder: (column) => column);

  GeneratedColumn<String> get destinazioneCitta => $composableBuilder(
    column: $table.destinazioneCitta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinazionePaese => $composableBuilder(
    column: $table.destinazionePaese,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodoApprossimativo => $composableBuilder(
    column: $table.periodoApprossimativo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataInizio => $composableBuilder(
    column: $table.dataInizio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataFine =>
      $composableBuilder(column: $table.dataFine, builder: (column) => column);

  GeneratedColumn<String> get oraArrivo =>
      $composableBuilder(column: $table.oraArrivo, builder: (column) => column);

  GeneratedColumn<String> get oraPartenza => $composableBuilder(
    column: $table.oraPartenza,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creatoreId => $composableBuilder(
    column: $table.creatoreId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get importato =>
      $composableBuilder(column: $table.importato, builder: (column) => column);

  GeneratedColumn<bool> get verificato => $composableBuilder(
    column: $table.verificato,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creatoIl =>
      $composableBuilder(column: $table.creatoIl, builder: (column) => column);
}

class $$ViaggiTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $ViaggiTable,
          Viaggio,
          $$ViaggiTableFilterComposer,
          $$ViaggiTableOrderingComposer,
          $$ViaggiTableAnnotationComposer,
          $$ViaggiTableCreateCompanionBuilder,
          $$ViaggiTableUpdateCompanionBuilder,
          (Viaggio, BaseReferences<_$DatabaseLocale, $ViaggiTable, Viaggio>),
          Viaggio,
          PrefetchHooks Function()
        > {
  $$ViaggiTableTableManager(_$DatabaseLocale db, $ViaggiTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ViaggiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ViaggiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ViaggiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> stato = const Value.absent(),
                Value<String?> destinazioneCitta = const Value.absent(),
                Value<String?> destinazionePaese = const Value.absent(),
                Value<String?> periodoApprossimativo = const Value.absent(),
                Value<String?> dataInizio = const Value.absent(),
                Value<String?> dataFine = const Value.absent(),
                Value<String?> oraArrivo = const Value.absent(),
                Value<String?> oraPartenza = const Value.absent(),
                Value<String> creatoreId = const Value.absent(),
                Value<bool> importato = const Value.absent(),
                Value<bool> verificato = const Value.absent(),
                Value<String> creatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ViaggiCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                stato: stato,
                destinazioneCitta: destinazioneCitta,
                destinazionePaese: destinazionePaese,
                periodoApprossimativo: periodoApprossimativo,
                dataInizio: dataInizio,
                dataFine: dataFine,
                oraArrivo: oraArrivo,
                oraPartenza: oraPartenza,
                creatoreId: creatoreId,
                importato: importato,
                verificato: verificato,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String stato,
                Value<String?> destinazioneCitta = const Value.absent(),
                Value<String?> destinazionePaese = const Value.absent(),
                Value<String?> periodoApprossimativo = const Value.absent(),
                Value<String?> dataInizio = const Value.absent(),
                Value<String?> dataFine = const Value.absent(),
                Value<String?> oraArrivo = const Value.absent(),
                Value<String?> oraPartenza = const Value.absent(),
                required String creatoreId,
                required bool importato,
                required bool verificato,
                required String creatoIl,
                Value<int> rowid = const Value.absent(),
              }) => ViaggiCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                stato: stato,
                destinazioneCitta: destinazioneCitta,
                destinazionePaese: destinazionePaese,
                periodoApprossimativo: periodoApprossimativo,
                dataInizio: dataInizio,
                dataFine: dataFine,
                oraArrivo: oraArrivo,
                oraPartenza: oraPartenza,
                creatoreId: creatoreId,
                importato: importato,
                verificato: verificato,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ViaggiTable, Viaggio>(table),
                  BaseReferences<_$DatabaseLocale, $ViaggiTable, Viaggio>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ViaggiTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $ViaggiTable,
      Viaggio,
      $$ViaggiTableFilterComposer,
      $$ViaggiTableOrderingComposer,
      $$ViaggiTableAnnotationComposer,
      $$ViaggiTableCreateCompanionBuilder,
      $$ViaggiTableUpdateCompanionBuilder,
      (Viaggio, BaseReferences<_$DatabaseLocale, $ViaggiTable, Viaggio>),
      Viaggio,
      PrefetchHooks Function()
    >;
typedef $$PartecipazioniTableCreateCompanionBuilder =
    PartecipazioniCompanion Function({
      required String id,
      required int versione,
      Value<String?> eliminatoIl,
      required DateTime scaricatoIl,
      required String viaggioId,
      required String utenteId,
      required String ruolo,
      required String stato,
      Value<int> rowid,
    });
typedef $$PartecipazioniTableUpdateCompanionBuilder =
    PartecipazioniCompanion Function({
      Value<String> id,
      Value<int> versione,
      Value<String?> eliminatoIl,
      Value<DateTime> scaricatoIl,
      Value<String> viaggioId,
      Value<String> utenteId,
      Value<String> ruolo,
      Value<String> stato,
      Value<int> rowid,
    });

class $$PartecipazioniTableFilterComposer
    extends Composer<_$DatabaseLocale, $PartecipazioniTable> {
  $$PartecipazioniTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get utenteId => $composableBuilder(
    column: $table.utenteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruolo => $composableBuilder(
    column: $table.ruolo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PartecipazioniTableOrderingComposer
    extends Composer<_$DatabaseLocale, $PartecipazioniTable> {
  $$PartecipazioniTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get utenteId => $composableBuilder(
    column: $table.utenteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruolo => $composableBuilder(
    column: $table.ruolo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PartecipazioniTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $PartecipazioniTable> {
  $$PartecipazioniTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get utenteId =>
      $composableBuilder(column: $table.utenteId, builder: (column) => column);

  GeneratedColumn<String> get ruolo =>
      $composableBuilder(column: $table.ruolo, builder: (column) => column);

  GeneratedColumn<String> get stato =>
      $composableBuilder(column: $table.stato, builder: (column) => column);
}

class $$PartecipazioniTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $PartecipazioniTable,
          Partecipazione,
          $$PartecipazioniTableFilterComposer,
          $$PartecipazioniTableOrderingComposer,
          $$PartecipazioniTableAnnotationComposer,
          $$PartecipazioniTableCreateCompanionBuilder,
          $$PartecipazioniTableUpdateCompanionBuilder,
          (
            Partecipazione,
            BaseReferences<
              _$DatabaseLocale,
              $PartecipazioniTable,
              Partecipazione
            >,
          ),
          Partecipazione,
          PrefetchHooks Function()
        > {
  $$PartecipazioniTableTableManager(
    _$DatabaseLocale db,
    $PartecipazioniTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartecipazioniTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartecipazioniTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartecipazioniTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> utenteId = const Value.absent(),
                Value<String> ruolo = const Value.absent(),
                Value<String> stato = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartecipazioniCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                utenteId: utenteId,
                ruolo: ruolo,
                stato: stato,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String utenteId,
                required String ruolo,
                required String stato,
                Value<int> rowid = const Value.absent(),
              }) => PartecipazioniCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                utenteId: utenteId,
                ruolo: ruolo,
                stato: stato,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PartecipazioniTable, Partecipazione>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $PartecipazioniTable,
                    Partecipazione
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PartecipazioniTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $PartecipazioniTable,
      Partecipazione,
      $$PartecipazioniTableFilterComposer,
      $$PartecipazioniTableOrderingComposer,
      $$PartecipazioniTableAnnotationComposer,
      $$PartecipazioniTableCreateCompanionBuilder,
      $$PartecipazioniTableUpdateCompanionBuilder,
      (
        Partecipazione,
        BaseReferences<_$DatabaseLocale, $PartecipazioniTable, Partecipazione>,
      ),
      Partecipazione,
      PrefetchHooks Function()
    >;
typedef $$GiorniTableCreateCompanionBuilder = GiorniCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String viaggioId,
  required String data,
  required String finestraInizio,
  required String finestraFine,
  Value<int> rowid,
});
typedef $$GiorniTableUpdateCompanionBuilder = GiorniCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> viaggioId,
  Value<String> data,
  Value<String> finestraInizio,
  Value<String> finestraFine,
  Value<int> rowid,
});

class $$GiorniTableFilterComposer
    extends Composer<_$DatabaseLocale, $GiorniTable> {
  $$GiorniTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finestraInizio => $composableBuilder(
    column: $table.finestraInizio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finestraFine => $composableBuilder(
    column: $table.finestraFine,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GiorniTableOrderingComposer
    extends Composer<_$DatabaseLocale, $GiorniTable> {
  $$GiorniTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finestraInizio => $composableBuilder(
    column: $table.finestraInizio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finestraFine => $composableBuilder(
    column: $table.finestraFine,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GiorniTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $GiorniTable> {
  $$GiorniTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get finestraInizio => $composableBuilder(
    column: $table.finestraInizio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finestraFine => $composableBuilder(
    column: $table.finestraFine,
    builder: (column) => column,
  );
}

class $$GiorniTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $GiorniTable,
          Giorno,
          $$GiorniTableFilterComposer,
          $$GiorniTableOrderingComposer,
          $$GiorniTableAnnotationComposer,
          $$GiorniTableCreateCompanionBuilder,
          $$GiorniTableUpdateCompanionBuilder,
          (Giorno, BaseReferences<_$DatabaseLocale, $GiorniTable, Giorno>),
          Giorno,
          PrefetchHooks Function()
        > {
  $$GiorniTableTableManager(_$DatabaseLocale db, $GiorniTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GiorniTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GiorniTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GiorniTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> finestraInizio = const Value.absent(),
                Value<String> finestraFine = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GiorniCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                data: data,
                finestraInizio: finestraInizio,
                finestraFine: finestraFine,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String data,
                required String finestraInizio,
                required String finestraFine,
                Value<int> rowid = const Value.absent(),
              }) => GiorniCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                data: data,
                finestraInizio: finestraInizio,
                finestraFine: finestraFine,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GiorniTable, Giorno>(table),
                  BaseReferences<_$DatabaseLocale, $GiorniTable, Giorno>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GiorniTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $GiorniTable,
      Giorno,
      $$GiorniTableFilterComposer,
      $$GiorniTableOrderingComposer,
      $$GiorniTableAnnotationComposer,
      $$GiorniTableCreateCompanionBuilder,
      $$GiorniTableUpdateCompanionBuilder,
      (Giorno, BaseReferences<_$DatabaseLocale, $GiorniTable, Giorno>),
      Giorno,
      PrefetchHooks Function()
    >;
typedef $$TappeTableCreateCompanionBuilder = TappeCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String viaggioId,
  required String giornoId,
  required int ordine,
  required String titolo,
  Value<String?> luogoNome,
  Value<double?> lat,
  Value<double?> lon,
  required int durataStimataMin,
  Value<String?> oraInizio,
  required String stato,
  Value<String?> marcataIl,
  required bool marcataDuranteIlViaggio,
  required bool eccedente,
  Value<String?> tipo,
  required String creatoDa,
  required String creatoIl,
  Value<int> rowid,
});
typedef $$TappeTableUpdateCompanionBuilder = TappeCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> viaggioId,
  Value<String> giornoId,
  Value<int> ordine,
  Value<String> titolo,
  Value<String?> luogoNome,
  Value<double?> lat,
  Value<double?> lon,
  Value<int> durataStimataMin,
  Value<String?> oraInizio,
  Value<String> stato,
  Value<String?> marcataIl,
  Value<bool> marcataDuranteIlViaggio,
  Value<bool> eccedente,
  Value<String?> tipo,
  Value<String> creatoDa,
  Value<String> creatoIl,
  Value<int> rowid,
});

class $$TappeTableFilterComposer
    extends Composer<_$DatabaseLocale, $TappeTable> {
  $$TappeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get giornoId => $composableBuilder(
    column: $table.giornoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordine => $composableBuilder(
    column: $table.ordine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titolo => $composableBuilder(
    column: $table.titolo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get luogoNome => $composableBuilder(
    column: $table.luogoNome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durataStimataMin => $composableBuilder(
    column: $table.durataStimataMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oraInizio => $composableBuilder(
    column: $table.oraInizio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get marcataIl => $composableBuilder(
    column: $table.marcataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get marcataDuranteIlViaggio => $composableBuilder(
    column: $table.marcataDuranteIlViaggio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get eccedente => $composableBuilder(
    column: $table.eccedente,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TappeTableOrderingComposer
    extends Composer<_$DatabaseLocale, $TappeTable> {
  $$TappeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get giornoId => $composableBuilder(
    column: $table.giornoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordine => $composableBuilder(
    column: $table.ordine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titolo => $composableBuilder(
    column: $table.titolo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get luogoNome => $composableBuilder(
    column: $table.luogoNome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durataStimataMin => $composableBuilder(
    column: $table.durataStimataMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oraInizio => $composableBuilder(
    column: $table.oraInizio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stato => $composableBuilder(
    column: $table.stato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marcataIl => $composableBuilder(
    column: $table.marcataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get marcataDuranteIlViaggio => $composableBuilder(
    column: $table.marcataDuranteIlViaggio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get eccedente => $composableBuilder(
    column: $table.eccedente,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TappeTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $TappeTable> {
  $$TappeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get giornoId =>
      $composableBuilder(column: $table.giornoId, builder: (column) => column);

  GeneratedColumn<int> get ordine =>
      $composableBuilder(column: $table.ordine, builder: (column) => column);

  GeneratedColumn<String> get titolo =>
      $composableBuilder(column: $table.titolo, builder: (column) => column);

  GeneratedColumn<String> get luogoNome =>
      $composableBuilder(column: $table.luogoNome, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<int> get durataStimataMin => $composableBuilder(
    column: $table.durataStimataMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oraInizio =>
      $composableBuilder(column: $table.oraInizio, builder: (column) => column);

  GeneratedColumn<String> get stato =>
      $composableBuilder(column: $table.stato, builder: (column) => column);

  GeneratedColumn<String> get marcataIl =>
      $composableBuilder(column: $table.marcataIl, builder: (column) => column);

  GeneratedColumn<bool> get marcataDuranteIlViaggio => $composableBuilder(
    column: $table.marcataDuranteIlViaggio,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get eccedente =>
      $composableBuilder(column: $table.eccedente, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get creatoDa =>
      $composableBuilder(column: $table.creatoDa, builder: (column) => column);

  GeneratedColumn<String> get creatoIl =>
      $composableBuilder(column: $table.creatoIl, builder: (column) => column);
}

class $$TappeTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $TappeTable,
          Tappa,
          $$TappeTableFilterComposer,
          $$TappeTableOrderingComposer,
          $$TappeTableAnnotationComposer,
          $$TappeTableCreateCompanionBuilder,
          $$TappeTableUpdateCompanionBuilder,
          (Tappa, BaseReferences<_$DatabaseLocale, $TappeTable, Tappa>),
          Tappa,
          PrefetchHooks Function()
        > {
  $$TappeTableTableManager(_$DatabaseLocale db, $TappeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TappeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TappeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TappeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> giornoId = const Value.absent(),
                Value<int> ordine = const Value.absent(),
                Value<String> titolo = const Value.absent(),
                Value<String?> luogoNome = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int> durataStimataMin = const Value.absent(),
                Value<String?> oraInizio = const Value.absent(),
                Value<String> stato = const Value.absent(),
                Value<String?> marcataIl = const Value.absent(),
                Value<bool> marcataDuranteIlViaggio = const Value.absent(),
                Value<bool> eccedente = const Value.absent(),
                Value<String?> tipo = const Value.absent(),
                Value<String> creatoDa = const Value.absent(),
                Value<String> creatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TappeCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                giornoId: giornoId,
                ordine: ordine,
                titolo: titolo,
                luogoNome: luogoNome,
                lat: lat,
                lon: lon,
                durataStimataMin: durataStimataMin,
                oraInizio: oraInizio,
                stato: stato,
                marcataIl: marcataIl,
                marcataDuranteIlViaggio: marcataDuranteIlViaggio,
                eccedente: eccedente,
                tipo: tipo,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String giornoId,
                required int ordine,
                required String titolo,
                Value<String?> luogoNome = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                required int durataStimataMin,
                Value<String?> oraInizio = const Value.absent(),
                required String stato,
                Value<String?> marcataIl = const Value.absent(),
                required bool marcataDuranteIlViaggio,
                required bool eccedente,
                Value<String?> tipo = const Value.absent(),
                required String creatoDa,
                required String creatoIl,
                Value<int> rowid = const Value.absent(),
              }) => TappeCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                giornoId: giornoId,
                ordine: ordine,
                titolo: titolo,
                luogoNome: luogoNome,
                lat: lat,
                lon: lon,
                durataStimataMin: durataStimataMin,
                oraInizio: oraInizio,
                stato: stato,
                marcataIl: marcataIl,
                marcataDuranteIlViaggio: marcataDuranteIlViaggio,
                eccedente: eccedente,
                tipo: tipo,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TappeTable, Tappa>(table),
                  BaseReferences<_$DatabaseLocale, $TappeTable, Tappa>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TappeTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $TappeTable,
      Tappa,
      $$TappeTableFilterComposer,
      $$TappeTableOrderingComposer,
      $$TappeTableAnnotationComposer,
      $$TappeTableCreateCompanionBuilder,
      $$TappeTableUpdateCompanionBuilder,
      (Tappa, BaseReferences<_$DatabaseLocale, $TappeTable, Tappa>),
      Tappa,
      PrefetchHooks Function()
    >;
typedef $$SpeseTableCreateCompanionBuilder = SpeseCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String viaggioId,
  required String importo,
  required String valuta,
  Value<String?> tassoUsato,
  Value<String?> tassoAl,
  required String paganteId,
  required String data,
  Value<String?> descrizione,
  required String creatoDa,
  required String creatoIl,
  Value<int> rowid,
});
typedef $$SpeseTableUpdateCompanionBuilder = SpeseCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> viaggioId,
  Value<String> importo,
  Value<String> valuta,
  Value<String?> tassoUsato,
  Value<String?> tassoAl,
  Value<String> paganteId,
  Value<String> data,
  Value<String?> descrizione,
  Value<String> creatoDa,
  Value<String> creatoIl,
  Value<int> rowid,
});

class $$SpeseTableFilterComposer
    extends Composer<_$DatabaseLocale, $SpeseTable> {
  $$SpeseTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importo => $composableBuilder(
    column: $table.importo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuta => $composableBuilder(
    column: $table.valuta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tassoUsato => $composableBuilder(
    column: $table.tassoUsato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tassoAl => $composableBuilder(
    column: $table.tassoAl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paganteId => $composableBuilder(
    column: $table.paganteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpeseTableOrderingComposer
    extends Composer<_$DatabaseLocale, $SpeseTable> {
  $$SpeseTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importo => $composableBuilder(
    column: $table.importo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuta => $composableBuilder(
    column: $table.valuta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tassoUsato => $composableBuilder(
    column: $table.tassoUsato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tassoAl => $composableBuilder(
    column: $table.tassoAl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paganteId => $composableBuilder(
    column: $table.paganteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpeseTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $SpeseTable> {
  $$SpeseTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get importo =>
      $composableBuilder(column: $table.importo, builder: (column) => column);

  GeneratedColumn<String> get valuta =>
      $composableBuilder(column: $table.valuta, builder: (column) => column);

  GeneratedColumn<String> get tassoUsato => $composableBuilder(
    column: $table.tassoUsato,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tassoAl =>
      $composableBuilder(column: $table.tassoAl, builder: (column) => column);

  GeneratedColumn<String> get paganteId =>
      $composableBuilder(column: $table.paganteId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get descrizione => $composableBuilder(
    column: $table.descrizione,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creatoDa =>
      $composableBuilder(column: $table.creatoDa, builder: (column) => column);

  GeneratedColumn<String> get creatoIl =>
      $composableBuilder(column: $table.creatoIl, builder: (column) => column);
}

class $$SpeseTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $SpeseTable,
          Spesa,
          $$SpeseTableFilterComposer,
          $$SpeseTableOrderingComposer,
          $$SpeseTableAnnotationComposer,
          $$SpeseTableCreateCompanionBuilder,
          $$SpeseTableUpdateCompanionBuilder,
          (Spesa, BaseReferences<_$DatabaseLocale, $SpeseTable, Spesa>),
          Spesa,
          PrefetchHooks Function()
        > {
  $$SpeseTableTableManager(_$DatabaseLocale db, $SpeseTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeseTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeseTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeseTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> importo = const Value.absent(),
                Value<String> valuta = const Value.absent(),
                Value<String?> tassoUsato = const Value.absent(),
                Value<String?> tassoAl = const Value.absent(),
                Value<String> paganteId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> descrizione = const Value.absent(),
                Value<String> creatoDa = const Value.absent(),
                Value<String> creatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeseCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                importo: importo,
                valuta: valuta,
                tassoUsato: tassoUsato,
                tassoAl: tassoAl,
                paganteId: paganteId,
                data: data,
                descrizione: descrizione,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String importo,
                required String valuta,
                Value<String?> tassoUsato = const Value.absent(),
                Value<String?> tassoAl = const Value.absent(),
                required String paganteId,
                required String data,
                Value<String?> descrizione = const Value.absent(),
                required String creatoDa,
                required String creatoIl,
                Value<int> rowid = const Value.absent(),
              }) => SpeseCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                importo: importo,
                valuta: valuta,
                tassoUsato: tassoUsato,
                tassoAl: tassoAl,
                paganteId: paganteId,
                data: data,
                descrizione: descrizione,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeseTable, Spesa>(table),
                  BaseReferences<_$DatabaseLocale, $SpeseTable, Spesa>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpeseTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $SpeseTable,
      Spesa,
      $$SpeseTableFilterComposer,
      $$SpeseTableOrderingComposer,
      $$SpeseTableAnnotationComposer,
      $$SpeseTableCreateCompanionBuilder,
      $$SpeseTableUpdateCompanionBuilder,
      (Spesa, BaseReferences<_$DatabaseLocale, $SpeseTable, Spesa>),
      Spesa,
      PrefetchHooks Function()
    >;
typedef $$SpeseQuoteTableCreateCompanionBuilder = SpeseQuoteCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String viaggioId,
  required String spesaId,
  required String utenteId,
  required String quota,
  Value<int> rowid,
});
typedef $$SpeseQuoteTableUpdateCompanionBuilder = SpeseQuoteCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> viaggioId,
  Value<String> spesaId,
  Value<String> utenteId,
  Value<String> quota,
  Value<int> rowid,
});

class $$SpeseQuoteTableFilterComposer
    extends Composer<_$DatabaseLocale, $SpeseQuoteTable> {
  $$SpeseQuoteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spesaId => $composableBuilder(
    column: $table.spesaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get utenteId => $composableBuilder(
    column: $table.utenteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpeseQuoteTableOrderingComposer
    extends Composer<_$DatabaseLocale, $SpeseQuoteTable> {
  $$SpeseQuoteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spesaId => $composableBuilder(
    column: $table.spesaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get utenteId => $composableBuilder(
    column: $table.utenteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpeseQuoteTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $SpeseQuoteTable> {
  $$SpeseQuoteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get spesaId =>
      $composableBuilder(column: $table.spesaId, builder: (column) => column);

  GeneratedColumn<String> get utenteId =>
      $composableBuilder(column: $table.utenteId, builder: (column) => column);

  GeneratedColumn<String> get quota =>
      $composableBuilder(column: $table.quota, builder: (column) => column);
}

class $$SpeseQuoteTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $SpeseQuoteTable,
          SpesaQuota,
          $$SpeseQuoteTableFilterComposer,
          $$SpeseQuoteTableOrderingComposer,
          $$SpeseQuoteTableAnnotationComposer,
          $$SpeseQuoteTableCreateCompanionBuilder,
          $$SpeseQuoteTableUpdateCompanionBuilder,
          (
            SpesaQuota,
            BaseReferences<_$DatabaseLocale, $SpeseQuoteTable, SpesaQuota>,
          ),
          SpesaQuota,
          PrefetchHooks Function()
        > {
  $$SpeseQuoteTableTableManager(_$DatabaseLocale db, $SpeseQuoteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeseQuoteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeseQuoteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeseQuoteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> spesaId = const Value.absent(),
                Value<String> utenteId = const Value.absent(),
                Value<String> quota = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeseQuoteCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                spesaId: spesaId,
                utenteId: utenteId,
                quota: quota,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String spesaId,
                required String utenteId,
                required String quota,
                Value<int> rowid = const Value.absent(),
              }) => SpeseQuoteCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                spesaId: spesaId,
                utenteId: utenteId,
                quota: quota,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeseQuoteTable, SpesaQuota>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $SpeseQuoteTable,
                    SpesaQuota
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpeseQuoteTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $SpeseQuoteTable,
      SpesaQuota,
      $$SpeseQuoteTableFilterComposer,
      $$SpeseQuoteTableOrderingComposer,
      $$SpeseQuoteTableAnnotationComposer,
      $$SpeseQuoteTableCreateCompanionBuilder,
      $$SpeseQuoteTableUpdateCompanionBuilder,
      (
        SpesaQuota,
        BaseReferences<_$DatabaseLocale, $SpeseQuoteTable, SpesaQuota>,
      ),
      SpesaQuota,
      PrefetchHooks Function()
    >;
typedef $$VociListaTableCreateCompanionBuilder = VociListaCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String viaggioId,
  required String testo,
  required int quantita,
  required String tipo,
  required String proprietarioId,
  Value<String?> assegnatoA,
  required bool spuntata,
  required String creatoDa,
  required String creatoIl,
  Value<int> rowid,
});
typedef $$VociListaTableUpdateCompanionBuilder = VociListaCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> viaggioId,
  Value<String> testo,
  Value<int> quantita,
  Value<String> tipo,
  Value<String> proprietarioId,
  Value<String?> assegnatoA,
  Value<bool> spuntata,
  Value<String> creatoDa,
  Value<String> creatoIl,
  Value<int> rowid,
});

class $$VociListaTableFilterComposer
    extends Composer<_$DatabaseLocale, $VociListaTable> {
  $$VociListaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get testo => $composableBuilder(
    column: $table.testo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantita => $composableBuilder(
    column: $table.quantita,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proprietarioId => $composableBuilder(
    column: $table.proprietarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assegnatoA => $composableBuilder(
    column: $table.assegnatoA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get spuntata => $composableBuilder(
    column: $table.spuntata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VociListaTableOrderingComposer
    extends Composer<_$DatabaseLocale, $VociListaTable> {
  $$VociListaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get testo => $composableBuilder(
    column: $table.testo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantita => $composableBuilder(
    column: $table.quantita,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proprietarioId => $composableBuilder(
    column: $table.proprietarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assegnatoA => $composableBuilder(
    column: $table.assegnatoA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get spuntata => $composableBuilder(
    column: $table.spuntata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VociListaTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $VociListaTable> {
  $$VociListaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get testo =>
      $composableBuilder(column: $table.testo, builder: (column) => column);

  GeneratedColumn<int> get quantita =>
      $composableBuilder(column: $table.quantita, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get proprietarioId => $composableBuilder(
    column: $table.proprietarioId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assegnatoA => $composableBuilder(
    column: $table.assegnatoA,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get spuntata =>
      $composableBuilder(column: $table.spuntata, builder: (column) => column);

  GeneratedColumn<String> get creatoDa =>
      $composableBuilder(column: $table.creatoDa, builder: (column) => column);

  GeneratedColumn<String> get creatoIl =>
      $composableBuilder(column: $table.creatoIl, builder: (column) => column);
}

class $$VociListaTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $VociListaTable,
          VoceLista,
          $$VociListaTableFilterComposer,
          $$VociListaTableOrderingComposer,
          $$VociListaTableAnnotationComposer,
          $$VociListaTableCreateCompanionBuilder,
          $$VociListaTableUpdateCompanionBuilder,
          (
            VoceLista,
            BaseReferences<_$DatabaseLocale, $VociListaTable, VoceLista>,
          ),
          VoceLista,
          PrefetchHooks Function()
        > {
  $$VociListaTableTableManager(_$DatabaseLocale db, $VociListaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VociListaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VociListaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VociListaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> testo = const Value.absent(),
                Value<int> quantita = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> proprietarioId = const Value.absent(),
                Value<String?> assegnatoA = const Value.absent(),
                Value<bool> spuntata = const Value.absent(),
                Value<String> creatoDa = const Value.absent(),
                Value<String> creatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VociListaCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                testo: testo,
                quantita: quantita,
                tipo: tipo,
                proprietarioId: proprietarioId,
                assegnatoA: assegnatoA,
                spuntata: spuntata,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String testo,
                required int quantita,
                required String tipo,
                required String proprietarioId,
                Value<String?> assegnatoA = const Value.absent(),
                required bool spuntata,
                required String creatoDa,
                required String creatoIl,
                Value<int> rowid = const Value.absent(),
              }) => VociListaCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                testo: testo,
                quantita: quantita,
                tipo: tipo,
                proprietarioId: proprietarioId,
                assegnatoA: assegnatoA,
                spuntata: spuntata,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VociListaTable, VoceLista>(table),
                  BaseReferences<_$DatabaseLocale, $VociListaTable, VoceLista>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VociListaTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $VociListaTable,
      VoceLista,
      $$VociListaTableFilterComposer,
      $$VociListaTableOrderingComposer,
      $$VociListaTableAnnotationComposer,
      $$VociListaTableCreateCompanionBuilder,
      $$VociListaTableUpdateCompanionBuilder,
      (VoceLista, BaseReferences<_$DatabaseLocale, $VociListaTable, VoceLista>),
      VoceLista,
      PrefetchHooks Function()
    >;
typedef $$NoteTableCreateCompanionBuilder = NoteCompanion Function({
  required String id,
  required int versione,
  Value<String?> eliminatoIl,
  required DateTime scaricatoIl,
  required String viaggioId,
  required String testo,
  required String origine,
  required String creatoDa,
  required String creatoIl,
  Value<int> rowid,
});
typedef $$NoteTableUpdateCompanionBuilder = NoteCompanion Function({
  Value<String> id,
  Value<int> versione,
  Value<String?> eliminatoIl,
  Value<DateTime> scaricatoIl,
  Value<String> viaggioId,
  Value<String> testo,
  Value<String> origine,
  Value<String> creatoDa,
  Value<String> creatoIl,
  Value<int> rowid,
});

class $$NoteTableFilterComposer extends Composer<_$DatabaseLocale, $NoteTable> {
  $$NoteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get testo => $composableBuilder(
    column: $table.testo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origine => $composableBuilder(
    column: $table.origine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NoteTableOrderingComposer
    extends Composer<_$DatabaseLocale, $NoteTable> {
  $$NoteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versione => $composableBuilder(
    column: $table.versione,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get testo => $composableBuilder(
    column: $table.testo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origine => $composableBuilder(
    column: $table.origine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoDa => $composableBuilder(
    column: $table.creatoDa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $NoteTable> {
  $$NoteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get versione =>
      $composableBuilder(column: $table.versione, builder: (column) => column);

  GeneratedColumn<String> get eliminatoIl => $composableBuilder(
    column: $table.eliminatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get testo =>
      $composableBuilder(column: $table.testo, builder: (column) => column);

  GeneratedColumn<String> get origine =>
      $composableBuilder(column: $table.origine, builder: (column) => column);

  GeneratedColumn<String> get creatoDa =>
      $composableBuilder(column: $table.creatoDa, builder: (column) => column);

  GeneratedColumn<String> get creatoIl =>
      $composableBuilder(column: $table.creatoIl, builder: (column) => column);
}

class $$NoteTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $NoteTable,
          Nota,
          $$NoteTableFilterComposer,
          $$NoteTableOrderingComposer,
          $$NoteTableAnnotationComposer,
          $$NoteTableCreateCompanionBuilder,
          $$NoteTableUpdateCompanionBuilder,
          (Nota, BaseReferences<_$DatabaseLocale, $NoteTable, Nota>),
          Nota,
          PrefetchHooks Function()
        > {
  $$NoteTableTableManager(_$DatabaseLocale db, $NoteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> versione = const Value.absent(),
                Value<String?> eliminatoIl = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String> testo = const Value.absent(),
                Value<String> origine = const Value.absent(),
                Value<String> creatoDa = const Value.absent(),
                Value<String> creatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteCompanion(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                testo: testo,
                origine: origine,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int versione,
                Value<String?> eliminatoIl = const Value.absent(),
                required DateTime scaricatoIl,
                required String viaggioId,
                required String testo,
                required String origine,
                required String creatoDa,
                required String creatoIl,
                Value<int> rowid = const Value.absent(),
              }) => NoteCompanion.insert(
                id: id,
                versione: versione,
                eliminatoIl: eliminatoIl,
                scaricatoIl: scaricatoIl,
                viaggioId: viaggioId,
                testo: testo,
                origine: origine,
                creatoDa: creatoDa,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTable, Nota>(table),
                  BaseReferences<_$DatabaseLocale, $NoteTable, Nota>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NoteTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $NoteTable,
      Nota,
      $$NoteTableFilterComposer,
      $$NoteTableOrderingComposer,
      $$NoteTableAnnotationComposer,
      $$NoteTableCreateCompanionBuilder,
      $$NoteTableUpdateCompanionBuilder,
      (Nota, BaseReferences<_$DatabaseLocale, $NoteTable, Nota>),
      Nota,
      PrefetchHooks Function()
    >;
typedef $$TassiCambioTableCreateCompanionBuilder =
    TassiCambioCompanion Function({
      required String valuta,
      required String perEuro,
      required String del,
      required DateTime scaricatoIl,
      Value<int> rowid,
    });
typedef $$TassiCambioTableUpdateCompanionBuilder =
    TassiCambioCompanion Function({
      Value<String> valuta,
      Value<String> perEuro,
      Value<String> del,
      Value<DateTime> scaricatoIl,
      Value<int> rowid,
    });

class $$TassiCambioTableFilterComposer
    extends Composer<_$DatabaseLocale, $TassiCambioTable> {
  $$TassiCambioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get valuta => $composableBuilder(
    column: $table.valuta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get perEuro => $composableBuilder(
    column: $table.perEuro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get del => $composableBuilder(
    column: $table.del,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TassiCambioTableOrderingComposer
    extends Composer<_$DatabaseLocale, $TassiCambioTable> {
  $$TassiCambioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get valuta => $composableBuilder(
    column: $table.valuta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perEuro => $composableBuilder(
    column: $table.perEuro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get del => $composableBuilder(
    column: $table.del,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TassiCambioTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $TassiCambioTable> {
  $$TassiCambioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get valuta =>
      $composableBuilder(column: $table.valuta, builder: (column) => column);

  GeneratedColumn<String> get perEuro =>
      $composableBuilder(column: $table.perEuro, builder: (column) => column);

  GeneratedColumn<String> get del =>
      $composableBuilder(column: $table.del, builder: (column) => column);

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );
}

class $$TassiCambioTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $TassiCambioTable,
          TassoCambio,
          $$TassiCambioTableFilterComposer,
          $$TassiCambioTableOrderingComposer,
          $$TassiCambioTableAnnotationComposer,
          $$TassiCambioTableCreateCompanionBuilder,
          $$TassiCambioTableUpdateCompanionBuilder,
          (
            TassoCambio,
            BaseReferences<_$DatabaseLocale, $TassiCambioTable, TassoCambio>,
          ),
          TassoCambio,
          PrefetchHooks Function()
        > {
  $$TassiCambioTableTableManager(_$DatabaseLocale db, $TassiCambioTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TassiCambioTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TassiCambioTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TassiCambioTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> valuta = const Value.absent(),
                Value<String> perEuro = const Value.absent(),
                Value<String> del = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TassiCambioCompanion(
                valuta: valuta,
                perEuro: perEuro,
                del: del,
                scaricatoIl: scaricatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String valuta,
                required String perEuro,
                required String del,
                required DateTime scaricatoIl,
                Value<int> rowid = const Value.absent(),
              }) => TassiCambioCompanion.insert(
                valuta: valuta,
                perEuro: perEuro,
                del: del,
                scaricatoIl: scaricatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TassiCambioTable, TassoCambio>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $TassiCambioTable,
                    TassoCambio
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TassiCambioTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $TassiCambioTable,
      TassoCambio,
      $$TassiCambioTableFilterComposer,
      $$TassiCambioTableOrderingComposer,
      $$TassiCambioTableAnnotationComposer,
      $$TassiCambioTableCreateCompanionBuilder,
      $$TassiCambioTableUpdateCompanionBuilder,
      (
        TassoCambio,
        BaseReferences<_$DatabaseLocale, $TassiCambioTable, TassoCambio>,
      ),
      TassoCambio,
      PrefetchHooks Function()
    >;
typedef $$ConfigurazioniTableCreateCompanionBuilder =
    ConfigurazioniCompanion Function({
      required String chiave,
      required String valore,
      required DateTime scaricatoIl,
      Value<int> rowid,
    });
typedef $$ConfigurazioniTableUpdateCompanionBuilder =
    ConfigurazioniCompanion Function({
      Value<String> chiave,
      Value<String> valore,
      Value<DateTime> scaricatoIl,
      Value<int> rowid,
    });

class $$ConfigurazioniTableFilterComposer
    extends Composer<_$DatabaseLocale, $ConfigurazioniTable> {
  $$ConfigurazioniTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chiave => $composableBuilder(
    column: $table.chiave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConfigurazioniTableOrderingComposer
    extends Composer<_$DatabaseLocale, $ConfigurazioniTable> {
  $$ConfigurazioniTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chiave => $composableBuilder(
    column: $table.chiave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConfigurazioniTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $ConfigurazioniTable> {
  $$ConfigurazioniTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chiave =>
      $composableBuilder(column: $table.chiave, builder: (column) => column);

  GeneratedColumn<String> get valore =>
      $composableBuilder(column: $table.valore, builder: (column) => column);

  GeneratedColumn<DateTime> get scaricatoIl => $composableBuilder(
    column: $table.scaricatoIl,
    builder: (column) => column,
  );
}

class $$ConfigurazioniTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $ConfigurazioniTable,
          Configurazione,
          $$ConfigurazioniTableFilterComposer,
          $$ConfigurazioniTableOrderingComposer,
          $$ConfigurazioniTableAnnotationComposer,
          $$ConfigurazioniTableCreateCompanionBuilder,
          $$ConfigurazioniTableUpdateCompanionBuilder,
          (
            Configurazione,
            BaseReferences<
              _$DatabaseLocale,
              $ConfigurazioniTable,
              Configurazione
            >,
          ),
          Configurazione,
          PrefetchHooks Function()
        > {
  $$ConfigurazioniTableTableManager(
    _$DatabaseLocale db,
    $ConfigurazioniTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConfigurazioniTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConfigurazioniTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConfigurazioniTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chiave = const Value.absent(),
                Value<String> valore = const Value.absent(),
                Value<DateTime> scaricatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConfigurazioniCompanion(
                chiave: chiave,
                valore: valore,
                scaricatoIl: scaricatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chiave,
                required String valore,
                required DateTime scaricatoIl,
                Value<int> rowid = const Value.absent(),
              }) => ConfigurazioniCompanion.insert(
                chiave: chiave,
                valore: valore,
                scaricatoIl: scaricatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConfigurazioniTable, Configurazione>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $ConfigurazioniTable,
                    Configurazione
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConfigurazioniTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $ConfigurazioniTable,
      Configurazione,
      $$ConfigurazioniTableFilterComposer,
      $$ConfigurazioniTableOrderingComposer,
      $$ConfigurazioniTableAnnotationComposer,
      $$ConfigurazioniTableCreateCompanionBuilder,
      $$ConfigurazioniTableUpdateCompanionBuilder,
      (
        Configurazione,
        BaseReferences<_$DatabaseLocale, $ConfigurazioniTable, Configurazione>,
      ),
      Configurazione,
      PrefetchHooks Function()
    >;
typedef $$CodaScritturaTableCreateCompanionBuilder =
    CodaScritturaCompanion Function({
      required String id,
      required String viaggioId,
      required GestoOffline gesto,
      required String carico,
      required DateTime creataIl,
      Value<int> tentativi,
      Value<String?> ultimoErrore,
      Value<bool> messaDaParte,
      Value<int> rowid,
    });
typedef $$CodaScritturaTableUpdateCompanionBuilder =
    CodaScritturaCompanion Function({
      Value<String> id,
      Value<String> viaggioId,
      Value<GestoOffline> gesto,
      Value<String> carico,
      Value<DateTime> creataIl,
      Value<int> tentativi,
      Value<String?> ultimoErrore,
      Value<bool> messaDaParte,
      Value<int> rowid,
    });

class $$CodaScritturaTableFilterComposer
    extends Composer<_$DatabaseLocale, $CodaScritturaTable> {
  $$CodaScritturaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<GestoOffline, GestoOffline, String>
  get gesto => $composableBuilder(
    column: $table.gesto,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get carico => $composableBuilder(
    column: $table.carico,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creataIl => $composableBuilder(
    column: $table.creataIl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tentativi => $composableBuilder(
    column: $table.tentativi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ultimoErrore => $composableBuilder(
    column: $table.ultimoErrore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get messaDaParte => $composableBuilder(
    column: $table.messaDaParte,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CodaScritturaTableOrderingComposer
    extends Composer<_$DatabaseLocale, $CodaScritturaTable> {
  $$CodaScritturaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gesto => $composableBuilder(
    column: $table.gesto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carico => $composableBuilder(
    column: $table.carico,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creataIl => $composableBuilder(
    column: $table.creataIl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tentativi => $composableBuilder(
    column: $table.tentativi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ultimoErrore => $composableBuilder(
    column: $table.ultimoErrore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get messaDaParte => $composableBuilder(
    column: $table.messaDaParte,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CodaScritturaTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $CodaScritturaTable> {
  $$CodaScritturaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<GestoOffline, String> get gesto =>
      $composableBuilder(column: $table.gesto, builder: (column) => column);

  GeneratedColumn<String> get carico =>
      $composableBuilder(column: $table.carico, builder: (column) => column);

  GeneratedColumn<DateTime> get creataIl =>
      $composableBuilder(column: $table.creataIl, builder: (column) => column);

  GeneratedColumn<int> get tentativi =>
      $composableBuilder(column: $table.tentativi, builder: (column) => column);

  GeneratedColumn<String> get ultimoErrore => $composableBuilder(
    column: $table.ultimoErrore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get messaDaParte => $composableBuilder(
    column: $table.messaDaParte,
    builder: (column) => column,
  );
}

class $$CodaScritturaTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $CodaScritturaTable,
          OperazioneInCoda,
          $$CodaScritturaTableFilterComposer,
          $$CodaScritturaTableOrderingComposer,
          $$CodaScritturaTableAnnotationComposer,
          $$CodaScritturaTableCreateCompanionBuilder,
          $$CodaScritturaTableUpdateCompanionBuilder,
          (
            OperazioneInCoda,
            BaseReferences<
              _$DatabaseLocale,
              $CodaScritturaTable,
              OperazioneInCoda
            >,
          ),
          OperazioneInCoda,
          PrefetchHooks Function()
        > {
  $$CodaScritturaTableTableManager(
    _$DatabaseLocale db,
    $CodaScritturaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CodaScritturaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CodaScritturaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CodaScritturaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<GestoOffline> gesto = const Value.absent(),
                Value<String> carico = const Value.absent(),
                Value<DateTime> creataIl = const Value.absent(),
                Value<int> tentativi = const Value.absent(),
                Value<String?> ultimoErrore = const Value.absent(),
                Value<bool> messaDaParte = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CodaScritturaCompanion(
                id: id,
                viaggioId: viaggioId,
                gesto: gesto,
                carico: carico,
                creataIl: creataIl,
                tentativi: tentativi,
                ultimoErrore: ultimoErrore,
                messaDaParte: messaDaParte,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String viaggioId,
                required GestoOffline gesto,
                required String carico,
                required DateTime creataIl,
                Value<int> tentativi = const Value.absent(),
                Value<String?> ultimoErrore = const Value.absent(),
                Value<bool> messaDaParte = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CodaScritturaCompanion.insert(
                id: id,
                viaggioId: viaggioId,
                gesto: gesto,
                carico: carico,
                creataIl: creataIl,
                tentativi: tentativi,
                ultimoErrore: ultimoErrore,
                messaDaParte: messaDaParte,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CodaScritturaTable, OperazioneInCoda>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $CodaScritturaTable,
                    OperazioneInCoda
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CodaScritturaTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $CodaScritturaTable,
      OperazioneInCoda,
      $$CodaScritturaTableFilterComposer,
      $$CodaScritturaTableOrderingComposer,
      $$CodaScritturaTableAnnotationComposer,
      $$CodaScritturaTableCreateCompanionBuilder,
      $$CodaScritturaTableUpdateCompanionBuilder,
      (
        OperazioneInCoda,
        BaseReferences<_$DatabaseLocale, $CodaScritturaTable, OperazioneInCoda>,
      ),
      OperazioneInCoda,
      PrefetchHooks Function()
    >;
typedef $$DocumentiTableCreateCompanionBuilder = DocumentiCompanion Function({
  required String id,
  required String viaggioId,
  Value<String?> giornoId,
  Value<String?> ora,
  required String nome,
  required String percorsoLocale,
  required String formato,
  Value<int?> pagine,
  required String sorgente,
  required String proprietarioId,
  required DateTime creatoIl,
  Value<int> rowid,
});
typedef $$DocumentiTableUpdateCompanionBuilder = DocumentiCompanion Function({
  Value<String> id,
  Value<String> viaggioId,
  Value<String?> giornoId,
  Value<String?> ora,
  Value<String> nome,
  Value<String> percorsoLocale,
  Value<String> formato,
  Value<int?> pagine,
  Value<String> sorgente,
  Value<String> proprietarioId,
  Value<DateTime> creatoIl,
  Value<int> rowid,
});

class $$DocumentiTableFilterComposer
    extends Composer<_$DatabaseLocale, $DocumentiTable> {
  $$DocumentiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get giornoId => $composableBuilder(
    column: $table.giornoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ora => $composableBuilder(
    column: $table.ora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get percorsoLocale => $composableBuilder(
    column: $table.percorsoLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formato => $composableBuilder(
    column: $table.formato,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagine => $composableBuilder(
    column: $table.pagine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sorgente => $composableBuilder(
    column: $table.sorgente,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proprietarioId => $composableBuilder(
    column: $table.proprietarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentiTableOrderingComposer
    extends Composer<_$DatabaseLocale, $DocumentiTable> {
  $$DocumentiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viaggioId => $composableBuilder(
    column: $table.viaggioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get giornoId => $composableBuilder(
    column: $table.giornoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ora => $composableBuilder(
    column: $table.ora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get percorsoLocale => $composableBuilder(
    column: $table.percorsoLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formato => $composableBuilder(
    column: $table.formato,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagine => $composableBuilder(
    column: $table.pagine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sorgente => $composableBuilder(
    column: $table.sorgente,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proprietarioId => $composableBuilder(
    column: $table.proprietarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creatoIl => $composableBuilder(
    column: $table.creatoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentiTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $DocumentiTable> {
  $$DocumentiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get viaggioId =>
      $composableBuilder(column: $table.viaggioId, builder: (column) => column);

  GeneratedColumn<String> get giornoId =>
      $composableBuilder(column: $table.giornoId, builder: (column) => column);

  GeneratedColumn<String> get ora =>
      $composableBuilder(column: $table.ora, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get percorsoLocale => $composableBuilder(
    column: $table.percorsoLocale,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formato =>
      $composableBuilder(column: $table.formato, builder: (column) => column);

  GeneratedColumn<int> get pagine =>
      $composableBuilder(column: $table.pagine, builder: (column) => column);

  GeneratedColumn<String> get sorgente =>
      $composableBuilder(column: $table.sorgente, builder: (column) => column);

  GeneratedColumn<String> get proprietarioId => $composableBuilder(
    column: $table.proprietarioId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creatoIl =>
      $composableBuilder(column: $table.creatoIl, builder: (column) => column);
}

class $$DocumentiTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $DocumentiTable,
          Documento,
          $$DocumentiTableFilterComposer,
          $$DocumentiTableOrderingComposer,
          $$DocumentiTableAnnotationComposer,
          $$DocumentiTableCreateCompanionBuilder,
          $$DocumentiTableUpdateCompanionBuilder,
          (
            Documento,
            BaseReferences<_$DatabaseLocale, $DocumentiTable, Documento>,
          ),
          Documento,
          PrefetchHooks Function()
        > {
  $$DocumentiTableTableManager(_$DatabaseLocale db, $DocumentiTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> viaggioId = const Value.absent(),
                Value<String?> giornoId = const Value.absent(),
                Value<String?> ora = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> percorsoLocale = const Value.absent(),
                Value<String> formato = const Value.absent(),
                Value<int?> pagine = const Value.absent(),
                Value<String> sorgente = const Value.absent(),
                Value<String> proprietarioId = const Value.absent(),
                Value<DateTime> creatoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentiCompanion(
                id: id,
                viaggioId: viaggioId,
                giornoId: giornoId,
                ora: ora,
                nome: nome,
                percorsoLocale: percorsoLocale,
                formato: formato,
                pagine: pagine,
                sorgente: sorgente,
                proprietarioId: proprietarioId,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String viaggioId,
                Value<String?> giornoId = const Value.absent(),
                Value<String?> ora = const Value.absent(),
                required String nome,
                required String percorsoLocale,
                required String formato,
                Value<int?> pagine = const Value.absent(),
                required String sorgente,
                required String proprietarioId,
                required DateTime creatoIl,
                Value<int> rowid = const Value.absent(),
              }) => DocumentiCompanion.insert(
                id: id,
                viaggioId: viaggioId,
                giornoId: giornoId,
                ora: ora,
                nome: nome,
                percorsoLocale: percorsoLocale,
                formato: formato,
                pagine: pagine,
                sorgente: sorgente,
                proprietarioId: proprietarioId,
                creatoIl: creatoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentiTable, Documento>(table),
                  BaseReferences<_$DatabaseLocale, $DocumentiTable, Documento>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentiTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $DocumentiTable,
      Documento,
      $$DocumentiTableFilterComposer,
      $$DocumentiTableOrderingComposer,
      $$DocumentiTableAnnotationComposer,
      $$DocumentiTableCreateCompanionBuilder,
      $$DocumentiTableUpdateCompanionBuilder,
      (Documento, BaseReferences<_$DatabaseLocale, $DocumentiTable, Documento>),
      Documento,
      PrefetchHooks Function()
    >;
typedef $$EventiInAttesaTableCreateCompanionBuilder =
    EventiInAttesaCompanion Function({
      required String id,
      required String nome,
      required String proprieta,
      required DateTime avvenutoIl,
      Value<int> rowid,
    });
typedef $$EventiInAttesaTableUpdateCompanionBuilder =
    EventiInAttesaCompanion Function({
      Value<String> id,
      Value<String> nome,
      Value<String> proprieta,
      Value<DateTime> avvenutoIl,
      Value<int> rowid,
    });

class $$EventiInAttesaTableFilterComposer
    extends Composer<_$DatabaseLocale, $EventiInAttesaTable> {
  $$EventiInAttesaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proprieta => $composableBuilder(
    column: $table.proprieta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get avvenutoIl => $composableBuilder(
    column: $table.avvenutoIl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventiInAttesaTableOrderingComposer
    extends Composer<_$DatabaseLocale, $EventiInAttesaTable> {
  $$EventiInAttesaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proprieta => $composableBuilder(
    column: $table.proprieta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get avvenutoIl => $composableBuilder(
    column: $table.avvenutoIl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventiInAttesaTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $EventiInAttesaTable> {
  $$EventiInAttesaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get proprieta =>
      $composableBuilder(column: $table.proprieta, builder: (column) => column);

  GeneratedColumn<DateTime> get avvenutoIl => $composableBuilder(
    column: $table.avvenutoIl,
    builder: (column) => column,
  );
}

class $$EventiInAttesaTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $EventiInAttesaTable,
          EventoInAttesa,
          $$EventiInAttesaTableFilterComposer,
          $$EventiInAttesaTableOrderingComposer,
          $$EventiInAttesaTableAnnotationComposer,
          $$EventiInAttesaTableCreateCompanionBuilder,
          $$EventiInAttesaTableUpdateCompanionBuilder,
          (
            EventoInAttesa,
            BaseReferences<
              _$DatabaseLocale,
              $EventiInAttesaTable,
              EventoInAttesa
            >,
          ),
          EventoInAttesa,
          PrefetchHooks Function()
        > {
  $$EventiInAttesaTableTableManager(
    _$DatabaseLocale db,
    $EventiInAttesaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventiInAttesaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventiInAttesaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventiInAttesaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> proprieta = const Value.absent(),
                Value<DateTime> avvenutoIl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventiInAttesaCompanion(
                id: id,
                nome: nome,
                proprieta: proprieta,
                avvenutoIl: avvenutoIl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nome,
                required String proprieta,
                required DateTime avvenutoIl,
                Value<int> rowid = const Value.absent(),
              }) => EventiInAttesaCompanion.insert(
                id: id,
                nome: nome,
                proprieta: proprieta,
                avvenutoIl: avvenutoIl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventiInAttesaTable, EventoInAttesa>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $EventiInAttesaTable,
                    EventoInAttesa
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventiInAttesaTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $EventiInAttesaTable,
      EventoInAttesa,
      $$EventiInAttesaTableFilterComposer,
      $$EventiInAttesaTableOrderingComposer,
      $$EventiInAttesaTableAnnotationComposer,
      $$EventiInAttesaTableCreateCompanionBuilder,
      $$EventiInAttesaTableUpdateCompanionBuilder,
      (
        EventoInAttesa,
        BaseReferences<_$DatabaseLocale, $EventiInAttesaTable, EventoInAttesa>,
      ),
      EventoInAttesa,
      PrefetchHooks Function()
    >;
typedef $$ImpostazioniTableCreateCompanionBuilder =
    ImpostazioniCompanion Function({
      required String chiave,
      required String valore,
      Value<int> rowid,
    });
typedef $$ImpostazioniTableUpdateCompanionBuilder =
    ImpostazioniCompanion Function({
      Value<String> chiave,
      Value<String> valore,
      Value<int> rowid,
    });

class $$ImpostazioniTableFilterComposer
    extends Composer<_$DatabaseLocale, $ImpostazioniTable> {
  $$ImpostazioniTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chiave => $composableBuilder(
    column: $table.chiave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImpostazioniTableOrderingComposer
    extends Composer<_$DatabaseLocale, $ImpostazioniTable> {
  $$ImpostazioniTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chiave => $composableBuilder(
    column: $table.chiave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valore => $composableBuilder(
    column: $table.valore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImpostazioniTableAnnotationComposer
    extends Composer<_$DatabaseLocale, $ImpostazioniTable> {
  $$ImpostazioniTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chiave =>
      $composableBuilder(column: $table.chiave, builder: (column) => column);

  GeneratedColumn<String> get valore =>
      $composableBuilder(column: $table.valore, builder: (column) => column);
}

class $$ImpostazioniTableTableManager
    extends
        RootTableManager<
          _$DatabaseLocale,
          $ImpostazioniTable,
          Impostazione,
          $$ImpostazioniTableFilterComposer,
          $$ImpostazioniTableOrderingComposer,
          $$ImpostazioniTableAnnotationComposer,
          $$ImpostazioniTableCreateCompanionBuilder,
          $$ImpostazioniTableUpdateCompanionBuilder,
          (
            Impostazione,
            BaseReferences<_$DatabaseLocale, $ImpostazioniTable, Impostazione>,
          ),
          Impostazione,
          PrefetchHooks Function()
        > {
  $$ImpostazioniTableTableManager(_$DatabaseLocale db, $ImpostazioniTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImpostazioniTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImpostazioniTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImpostazioniTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chiave = const Value.absent(),
                Value<String> valore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImpostazioniCompanion(
                chiave: chiave,
                valore: valore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chiave,
                required String valore,
                Value<int> rowid = const Value.absent(),
              }) => ImpostazioniCompanion.insert(
                chiave: chiave,
                valore: valore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImpostazioniTable, Impostazione>(table),
                  BaseReferences<
                    _$DatabaseLocale,
                    $ImpostazioniTable,
                    Impostazione
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImpostazioniTableProcessedTableManager =
    ProcessedTableManager<
      _$DatabaseLocale,
      $ImpostazioniTable,
      Impostazione,
      $$ImpostazioniTableFilterComposer,
      $$ImpostazioniTableOrderingComposer,
      $$ImpostazioniTableAnnotationComposer,
      $$ImpostazioniTableCreateCompanionBuilder,
      $$ImpostazioniTableUpdateCompanionBuilder,
      (
        Impostazione,
        BaseReferences<_$DatabaseLocale, $ImpostazioniTable, Impostazione>,
      ),
      Impostazione,
      PrefetchHooks Function()
    >;

class $DatabaseLocaleManager {
  final _$DatabaseLocale _db;
  $DatabaseLocaleManager(this._db);
  $$UtentiTableTableManager get utenti =>
      $$UtentiTableTableManager(_db, _db.utenti);
  $$ViaggiTableTableManager get viaggi =>
      $$ViaggiTableTableManager(_db, _db.viaggi);
  $$PartecipazioniTableTableManager get partecipazioni =>
      $$PartecipazioniTableTableManager(_db, _db.partecipazioni);
  $$GiorniTableTableManager get giorni =>
      $$GiorniTableTableManager(_db, _db.giorni);
  $$TappeTableTableManager get tappe =>
      $$TappeTableTableManager(_db, _db.tappe);
  $$SpeseTableTableManager get spese =>
      $$SpeseTableTableManager(_db, _db.spese);
  $$SpeseQuoteTableTableManager get speseQuote =>
      $$SpeseQuoteTableTableManager(_db, _db.speseQuote);
  $$VociListaTableTableManager get vociLista =>
      $$VociListaTableTableManager(_db, _db.vociLista);
  $$NoteTableTableManager get note => $$NoteTableTableManager(_db, _db.note);
  $$TassiCambioTableTableManager get tassiCambio =>
      $$TassiCambioTableTableManager(_db, _db.tassiCambio);
  $$ConfigurazioniTableTableManager get configurazioni =>
      $$ConfigurazioniTableTableManager(_db, _db.configurazioni);
  $$CodaScritturaTableTableManager get codaScrittura =>
      $$CodaScritturaTableTableManager(_db, _db.codaScrittura);
  $$DocumentiTableTableManager get documenti =>
      $$DocumentiTableTableManager(_db, _db.documenti);
  $$EventiInAttesaTableTableManager get eventiInAttesa =>
      $$EventiInAttesaTableTableManager(_db, _db.eventiInAttesa);
  $$ImpostazioniTableTableManager get impostazioni =>
      $$ImpostazioniTableTableManager(_db, _db.impostazioni);
}
