import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/pagine.dart';
import 'package:trolley/schermate/impostazioni.dart';

import '../aiuti.dart';

/// L'informativa e che cosa si misura (U.3; tela, 99): dal profilo si aprono
/// le pagine del sito; senza rete i rimandi si spengono e dicono perché.
void main() {
  late Ambiente ambiente;

  setUp(() => ambiente = Ambiente());
  tearDown(() => ambiente.chiudi());

  /// Tocca le parole [rimando] dentro una frase.
  Future<void> tocca(WidgetTester tester, String rimando) async {
    final frase = find.textContaining(rimando, findRichText: true).last;
    await tester.scrollUntilVisible(frase, 200);
    final testo = tester.widget<RichText>(frase).text;
    TapGestureRecognizer? tocco;
    testo.visitChildren((span) {
      if (span is TextSpan && span.text == rimando) {
        tocco = span.recognizer as TapGestureRecognizer?;
        return false;
      }
      return true;
    });
    expect(tocco, isNotNull, reason: '«$rimando» non si tocca');
    tocco!.onTap!();
    await tester.pumpAndSettle();
  }

  Future<void> profilo(WidgetTester tester) async {
    await ambiente.accedi(tester: tester);
    await ambiente.monta(tester, const SchermataImpostazioni());
    await tester.pumpAndSettle();
  }

  testWidgets('sotto la misurazione, «Cosa misuriamo» apre la pagina del '
      'sito', (tester) async {
    await profilo(tester);
    await tocca(tester, 'Cosa misuriamo');
    expect(ambiente.pagine.aperte, [PaginaDelSito.misurazione]);
  });

  testWidgets('«Informativa sulla privacy» apre l\'informativa', (
    tester,
  ) async {
    await profilo(tester);
    await tester.scrollUntilVisible(
      find.text('Informativa sulla privacy'),
      200,
    );
    expect(find.text('Che cosa trattiamo, e perché'), findsOneWidget);
    await tester.ensureVisible(find.text('Informativa sulla privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informativa sulla privacy'));
    await tester.pumpAndSettle();
    expect(ambiente.pagine.aperte, [PaginaDelSito.privacy]);
  });

  testWidgets('senza rete i rimandi si spengono e dicono perché', (
    tester,
  ) async {
    await profilo(tester);
    ambiente.rete.disponibile = false;
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Informativa sulla privacy'),
      200,
    );
    expect(
      find.textContaining(
        'Cosa misuriamo · $motivoSenzaRete',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Informativa sulla privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informativa sulla privacy'));
    await tester.pumpAndSettle();
    expect(ambiente.pagine.aperte, isEmpty);
  });

  test('le pagine stanno sul sito dei link d\'invito', () {
    expect(
      indirizzoDi(PaginaDelSito.privacy).toString(),
      'https://trolleyapp.vercel.app/privacy',
    );
    expect(
      indirizzoDi(PaginaDelSito.misurazione).toString(),
      'https://trolleyapp.vercel.app/misurazione',
    );
  });
}
