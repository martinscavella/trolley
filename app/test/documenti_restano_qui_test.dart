/// I documenti non lasciano mai il telefono (CLAUDE.md, regola 3; 03, regole 1
/// e 2). Queste prove rendono la frase verificabile invece che dichiarata: se
/// qualcuno aggiunge un percorso di codice che potrebbe mandarli fuori,
/// falliscono.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/database.dart';

/// I file che toccano i documenti.
const _fileDeiDocumenti = [
  'lib/dati/documenti.dart',
  'lib/dati/file_del_telefono.dart',
  'lib/dati/acquisizione.dart',
  'lib/dominio/documenti.dart',
];

/// Quello che possono importare: il sistema, i file, il database locale,
/// e i selettori del telefono. Niente che parli con un server.
final _importAmmessi = [
  RegExp(r"^dart:(async|collection|io|typed_data)$"),
  RegExp(r'^package:flutter/services\.dart$'),
  RegExp(r'^package:drift/drift\.dart$'),
  RegExp(r'^package:uuid/uuid\.dart$'),
  RegExp(r'^package:file_picker/file_picker\.dart$'),
  RegExp(
    r'^package:cunning_document_scanner/cunning_document_scanner\.dart$',
  ),
  RegExp(
    r'^(\.\./dominio/(calendario|documenti)|acquisizione|database|errori|file_del_telefono)\.dart$',
  ),
  RegExp(r'^calendario\.dart$'),
];

/// I pacchetti che parlano con la rete.
final _rete = RegExp(
  r"^package:(supabase_flutter|supabase|postgrest|gotrue|http|dio|share_plus|url_launcher)/",
);

/// I file dell'app che parlano con il server.
final _versoIlServer = RegExp(r'(^|/)(archivio|coda|rete|misurazione)\.dart$');

List<String> _importDi(String percorso) => [
  for (final m in RegExp(
    r'''^(?:import|export)\s+'([^']+)'(?:\s|;)''',
    multiLine: true,
  ).allMatches(File(percorso).readAsStringSync()))
    m.group(1)!,
];

void main() {
  test('i gesti senza rete sono i quattro, e nessuno è un documento', () {
    expect(GestoOffline.values.map((g) => g.name), [
      'registraSpesa',
      'marcaTappa',
      'spuntaVoce',
      'aggiungiTappa',
    ]);
  });

  test('i file dei documenti importano solo quello che serve, niente che '
      'parli con un server', () {
    for (final file in _fileDeiDocumenti) {
      for (final import in _importDi(file)) {
        expect(
          _importAmmessi.any((r) => r.hasMatch(import)),
          isTrue,
          reason: '$file importa $import',
        );
      }
    }
  });

  test('chi parla con il server non tocca i documenti', () {
    // Lo strato dei dati e la misurazione: le schermate mettono insieme i
    // pezzi, ma a parlare con il server sono solo questi.
    final dati = {for (final f in _fileDeiDocumenti) f.split('/').last};
    for (final cartella in ['lib/dati', 'lib/misurazione', 'lib/invito']) {
      for (final file in Directory(cartella).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final imports = _importDi(file.path);
        final parlaColServer =
            imports.any(_rete.hasMatch) ||
            imports.any(_versoIlServer.hasMatch) ||
            _versoIlServer.hasMatch(file.path);
        if (!parlaColServer) continue;
        final toccaDocumenti = [
          for (final i in imports)
            if (dati.contains(i.split('/').last)) i,
        ];
        expect(
          toccaDocumenti,
          isEmpty,
          reason: '${file.path} parla con il server e importa $toccaDocumenti',
        );
      }
    }
  });

  test('nessuno manda file al server: l\'app non usa il suo archivio di file',
      () {
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final testo = file.readAsStringSync();
      expect(
        RegExp(r'\.storage\b|\.upload(Binary)?\(').hasMatch(testo),
        isFalse,
        reason: '${file.path} carica qualcosa sul server',
      );
    }
  });

  test('il server non ha un posto dove metterli', () {
    for (final migrazione in Directory('../supabase/migrations').listSync()) {
      if (migrazione is! File) continue;
      final sql = migrazione.readAsStringSync().toLowerCase();
      expect(
        RegExp(r'create\s+table\s+(if\s+not\s+exists\s+)?(public\.)?documento')
            .hasMatch(sql),
        isFalse,
        reason: '${migrazione.path} crea una tabella dei documenti',
      );
      expect(
        sql.contains('storage.buckets') || sql.contains('storage.objects'),
        isFalse,
        reason: '${migrazione.path} tocca l\'archivio dei file del server',
      );
    }
  });
}
