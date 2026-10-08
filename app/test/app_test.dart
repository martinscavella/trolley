import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;
import 'package:trolley/app.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/documenti.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/pagine.dart';
import 'package:trolley/invito/ingresso_da_invito.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/servizi.dart';

import 'aiuti.dart';

/// Un ingresso da invito che si comanda dal test, al posto dei link veri.
class _IngressoFinto implements IngressoDaInvito {
  final controllo = StreamController<String>.broadcast();

  @override
  Stream<String> get codici => controllo.stream;
}

void main() {
  late DatabaseLocale db;
  late SupabaseClient supabase;
  late _IngressoFinto ingresso;
  late PagineFinte pagine;

  setUp(() {
    pagine = PagineFinte();
    db = DatabaseLocale(NativeDatabase.memory());
    // Nessuna sessione e nessun server: la persona non ha ancora un accesso.
    supabase = SupabaseClient(
      'http://localhost',
      'chiave-finta',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    ingresso = _IngressoFinto();
  });

  tearDown(() async {
    await ingresso.controllo.close();
    await db.close();
  });

  Future<void> avvia(WidgetTester tester, {bool conRete = true}) async {
    // Con "Riduci movimento" lo sfondo resta fermo e l'app si assesta: è anche
    // la prova che le schermate funzionano senza animazioni.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      Servizi(
        db: db,
        supabase: supabase,
        archivio: Archivio(db, supabase),
        misurazione: Misurazione(db, supabase, versioneApp: 'prova'),
        ingresso: ingresso,
        rete: ReteFinta(disponibile: conRete),
        documenti: CartellaDocumenti(
          db,
          telefono: TelefonoFinto(),
          cartellaApp: () async => Directory.systemTemp,
          io: () => null,
        ),
        acquisizione: AcquisizioneFinta(Directory.systemTemp),
        mappe: MappeFinte(),
        posizione: PosizioneFinta(),
        mappeDelTelefono: MappeDelTelefonoFinte(),
        pagine: pagine,
        child: const TrolleyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('senza accesso si parte dalla schermata d\'accesso', (
    tester,
  ) async {
    await avvia(tester);
    expect(find.text('Accedi'), findsOneWidget);
    expect(find.textContaining('Hai un invito.'), findsNothing);
  });

  testWidgets('senza rete l\'accesso lo dice prima di provare', (tester) async {
    await avvia(tester, conRete: false);
    expect(find.text(motivoSenzaRete), findsOneWidget);
  });

  testWidgets('prima di creare un account si dice dove si legge come si '
      'trattano i dati (U.3; tela, 1)', (tester) async {
    await avvia(tester);
    final frase = find.textContaining(
      'informativa sulla privacy',
      findRichText: true,
    );
    expect(frase, findsOneWidget);
    TapGestureRecognizer? tocco;
    tester.widget<RichText>(frase).text.visitChildren((span) {
      if (span is TextSpan && span.text == 'informativa sulla privacy') {
        tocco = span.recognizer as TapGestureRecognizer?;
      }
      return tocco == null;
    });
    tocco!.onTap!();
    await tester.pumpAndSettle();
    expect(pagine.aperte, [PaginaDelSito.privacy]);
  });

  testWidgets(
    'un invito arrivato prima dell\'accesso resta in attesa, e conta come '
    'installazione da invito',
    (tester) async {
      await avvia(tester);

      ingresso.controllo.add('ABCD2345');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hai un invito.'), findsOneWidget);
      final eventi = await tester.runAsync(
        () => db.select(db.eventiInAttesa).get(),
      );
      expect(eventi!.map((e) => e.nome), ['installazione_da_invito']);
      expect(eventi.single.proprieta, '{"via":"link"}');
    },
  );
}
