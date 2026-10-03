import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/acquisizione.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/documenti.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/file_del_telefono.dart';

import '../aiuti.dart';

void main() {
  late DatabaseLocale db;
  late Directory cartella;
  late Directory app;
  late TelefonoFinto telefono;
  late CartellaDocumenti documenti;
  var io = 'giulia';

  CartellaDocumenti conCartella(Directory base) => CartellaDocumenti(
    db,
    telefono: telefono,
    cartellaApp: () async => base,
    io: () => io,
  );

  setUp(() {
    db = DatabaseLocale(NativeDatabase.memory());
    cartella = Directory.systemTemp.createTempSync('trolley-documenti');
    app = Directory('${cartella.path}/app')..createSync();
    telefono = TelefonoFinto();
    io = 'giulia';
    documenti = conCartella(app);
  });

  tearDown(() async {
    await db.close();
    cartella.deleteSync(recursive: true);
  });

  /// Un file appena arrivato da una sorgente, nella cartella temporanea.
  FileAcquisito arrivato(String nome, {Sorgente sorgente = Sorgente.file}) {
    final file = File('${cartella.path}/$nome')
      ..writeAsStringSync('il contenuto di $nome');
    return FileAcquisito(percorso: file.path, sorgente: sorgente, nome: nome);
  }

  Future<Documento> aggiungi(
    String nome, {
    String viaggio = 'v1',
    String? giorno,
    Duration? ora,
    FileAcquisito? sorgente,
  }) => documenti.aggiungi(
    viaggioId: viaggio,
    giornoId: giorno,
    ora: ora,
    nome: nome,
    sorgente: sorgente ?? arrivato('$nome.pdf'),
  );

  /// Tutti i file sotto la cartella dei documenti.
  List<String> fileDentro(Directory base) {
    final radice = Directory('${base.path}/${CartellaDocumenti.cartella}');
    if (!radice.existsSync()) return const [];
    return [
      for (final f in radice.listSync(recursive: true))
        if (f is File) f.path.substring(base.path.length + 1),
    ]..sort();
  }

  group('aggiungere', () {
    test('un PDF si copia nella cartella del viaggio, protetto, con un '
        'percorso relativo', () async {
      final doc = await aggiungi(
        'Carta d\'imbarco',
        giorno: 'g10',
        ora: const Duration(hours: 7, minutes: 5),
      );

      expect(doc.percorsoLocale, 'documenti/v1/${doc.id}.pdf');
      expect(fileDentro(app), ['documenti/v1/${doc.id}.pdf']);
      final f = await documenti.file(doc);
      expect(f.readAsStringSync(), 'il contenuto di Carta d\'imbarco.pdf');
      expect(telefono.protetti, [f.path]);
      expect(doc.formato, 'pdf');
      expect(doc.pagine, 2);
      expect(doc.sorgente, 'file');
      expect(doc.giornoId, 'g10');
      expect(doc.ora, '07:05:00');
      expect(doc.proprietarioId, 'giulia');
    });

    test('il file d\'origine resta dov\'era: è una copia', () async {
      final sorgente = arrivato('biglietto.pdf');
      await aggiungi('Biglietto', sorgente: sorgente);
      expect(File(sorgente.percorso).existsSync(), isTrue);
    });

    test('un\'immagine si comprime in JPEG', () async {
      final sorgente = arrivato('IMG_0042.HEIC', sorgente: Sorgente.foto);
      final doc = await aggiungi('Carta d\'identità', sorgente: sorgente);
      expect(telefono.compressi, [sorgente.percorso]);
      expect(doc.percorsoLocale, endsWith('.jpg'));
      expect(doc.formato, 'immagine');
      expect(doc.pagine, isNull);
      expect(doc.sorgente, 'foto');
    });

    test('un file che non è né un PDF né un\'immagine non entra', () async {
      await expectLater(
        aggiungi('Contratto', sorgente: arrivato('contratto.docx')),
        throwsA(isA<ErroreTrolley>()),
      );
      expect(fileDentro(app), isEmpty);
      expect(await db.select(db.documenti).get(), isEmpty);
    });

    test('un PDF con la password non entra, e non lascia niente', () async {
      telefono.erroreDelPdf = const ErroreTrolley('protetto da una password');
      await expectLater(aggiungi('Estratto conto'), throwsA(isA<ErroreTrolley>()));
      expect(fileDentro(app), isEmpty);
      expect(await db.select(db.documenti).get(), isEmpty);
    });

    test('se il telefono non lo protegge come deve, non si salva', () async {
      telefono.stato = const StatoFile(
        protezione: 'dopo_il_primo_sblocco',
        nelBackup: true,
      );
      await expectLater(aggiungi('Passaporto'), throwsA(isA<ErroreTrolley>()));
      expect(fileDentro(app), isEmpty);
      expect(await db.select(db.documenti).get(), isEmpty);

      telefono.stato = const StatoFile(protezione: 'completa', nelBackup: false);
      await expectLater(aggiungi('Passaporto'), throwsA(isA<ErroreTrolley>()));
      expect(fileDentro(app), isEmpty);
    });

    test('con il disco pieno lo dice in chiaro, e non resta un mezzo '
        'documento', () async {
      telefono.discoPieno = true;
      await expectLater(
        aggiungi(
          'Foto',
          sorgente: arrivato('IMG_0001.jpg', sorgente: Sorgente.foto),
        ),
        throwsA(
          isA<ErroreTrolley>().having(
            (e) => e.messaggio,
            'messaggio',
            messaggioSpazioFinito,
          ),
        ),
      );
      expect(fileDentro(app), isEmpty);
      expect(await db.select(db.documenti).get(), isEmpty);
    });

    test('senza accesso non si aggiunge', () async {
      final senza = CartellaDocumenti(
        db,
        telefono: telefono,
        cartellaApp: () async => app,
        io: () => null,
      );
      await expectLater(
        senza.aggiungi(
          viaggioId: 'v1',
          giornoId: null,
          ora: null,
          nome: 'Passaporto',
          sorgente: arrivato('passaporto.pdf'),
        ),
        throwsA(isA<ErroreTrolley>()),
      );
    });
  });

  test('ripristinati su un telefono nuovo, con il contenitore altrove, i '
      'documenti si ritrovano', () async {
    final doc = await aggiungi('Assicurazione');
    // Il backup riporta la cartella dell'app sotto un percorso diverso.
    final nuovo = Directory('${cartella.path}/telefono-nuovo')..createSync();
    await app.rename('${nuovo.path}/app');
    final dopo = conCartella(Directory('${nuovo.path}/app'));

    final f = await dopo.file(doc);
    expect(f.existsSync(), isTrue);
    expect(f.readAsStringSync(), 'il contenuto di Assicurazione.pdf');
    expect(doc.percorsoLocale.startsWith('/'), isFalse);
  });

  test('ognuno vede i suoi, del viaggio che guarda', () async {
    await aggiungi('Di Giulia');
    await aggiungi('Altro viaggio', viaggio: 'v2');
    io = 'marco';
    await aggiungi('Di Marco');

    expect(
      (await documenti.osserva('v1').first).map((d) => d.nome),
      ['Di Marco'],
    );
    io = 'giulia';
    expect(
      (await documenti.osserva('v1').first).map((d) => d.nome),
      ['Di Giulia'],
    );
    expect(await documenti.osservaQuanti().first, 2);
  });

  test('cambiare nome, giorno e ora tocca solo la riga', () async {
    final doc = await aggiungi('Biglietto', giorno: 'g10');
    await documenti.modifica(
      doc,
      nome: '  Biglietto del museo ',
      giornoId: null,
      ora: const Duration(hours: 10),
    );
    final dopo = (await documenti.osserva('v1').first).single;
    expect(dopo.nome, 'Biglietto del museo');
    expect(dopo.giornoId, isNull);
    expect(dopo.ora, '10:00:00');
    expect(dopo.percorsoLocale, doc.percorsoLocale);
    expect((await documenti.file(dopo)).existsSync(), isTrue);
  });

  group('eliminare', () {
    test('un documento toglie il file e la riga', () async {
      final doc = await aggiungi('Biglietto');
      final f = await documenti.file(doc);
      await documenti.elimina(doc);
      expect(f.existsSync(), isFalse);
      expect(await db.select(db.documenti).get(), isEmpty);
    });

    test('se il file non c\'è già più, toglie la riga', () async {
      final doc = await aggiungi('Biglietto');
      (await documenti.file(doc)).deleteSync();
      await documenti.elimina(doc);
      expect(await db.select(db.documenti).get(), isEmpty);
    });

    test('un viaggio toglie la sua cartella e le sue righe, non quelle degli '
        'altri', () async {
      await aggiungi('Uno');
      await aggiungi('Due');
      final altro = await aggiungi('Altro', viaggio: 'v2');

      await documenti.eliminaViaggio('v1');

      expect(Directory('${app.path}/documenti/v1').existsSync(), isFalse);
      expect(fileDentro(app), [altro.percorsoLocale]);
      expect(
        (await db.select(db.documenti).get()).map((d) => d.nome),
        ['Altro'],
      );
    });
  });

  test('all\'avvio si buttano i file rimasti a metà, non i documenti', () async {
    final doc = await aggiungi('Biglietto');
    final meta = File('${app.path}/documenti/v1/rimasto.pdf.parziale')
      ..writeAsStringSync('mezzo');

    await documenti.pulisci();

    expect(meta.existsSync(), isFalse);
    expect(fileDentro(app), [doc.percorsoLocale]);
  });

  test('l\'anteprima della prima pagina si disegna una volta e resta in '
      'memoria', () async {
    final doc = await aggiungi('Biglietto');
    final prima = await documenti.anteprima(doc, larghezza: 120);
    final seconda = await documenti.anteprima(doc, larghezza: 120);
    expect(identical(prima, seconda), isTrue);
    // E su disco non si scrive niente oltre al documento.
    expect(fileDentro(app), [doc.percorsoLocale]);
  });
}
