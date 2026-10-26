import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/budget.dart';

void main() {
  final venerdi = DateTime.utc(2026, 10, 10);
  final domenica = DateTime.utc(2026, 10, 12);
  DateTime il(int giorno) => DateTime.utc(2026, 10, giorno);

  test('il budget si legge e si scrive come lo tiene il telefono', () {
    expect(Budget.leggi('90000 EUR'), const Budget(90000, 'EUR'));
    expect(const Budget(90000, 'EUR').scritto, '90000 EUR');
    expect(Budget.leggi(null), isNull);
    expect(Budget.leggi('0 EUR'), isNull);
    expect(Budget.leggi('tanti EUR'), isNull);
  });

  test('a metà viaggio: quanto è speso, la tacca di oggi, quanto resta al '
      'giorno', () {
    // 900 € per tre giorni: 300 al giorno. Il volo, prima, 210.
    final a = andamentoBudget(
      budget: 90000,
      spese: [
        (data: il(1), centesimi: 21000),
        (data: il(10), centesimi: 13200),
        (data: il(11), centesimi: 7080),
      ],
      inizio: venerdi,
      fine: domenica,
      oggi: il(11),
    );
    expect(a.fase, FaseBudget.durante);
    expect(a.speso, 41280);
    expect(a.restano, 48720);
    expect(a.quotaDelGiorno, 30000);
    // Il volo, più due giorni cominciati.
    expect(a.ritmo, 21000 + 60000);
    expect(a.rispettoAlRitmo, 41280 - 81000);
    // Oggi e domani.
    expect(a.giorniRestanti, 2);
    expect(a.alGiorno, 24360);
    expect(a.oltre, isFalse);
    expect([for (final c in a.colonne) c.data], [null, il(10), il(11), il(12)]);
    expect([for (final c in a.colonne) c.speso], [21000, 13200, 7080, 0]);
    expect([for (final c in a.colonne) c.futura], [false, false, false, true]);
  });

  test('prima di partire: la tacca è alle spese già fatte, e restano tutti '
      'i giorni', () {
    final a = andamentoBudget(
      budget: 90000,
      spese: [(data: il(1), centesimi: 21000)],
      inizio: venerdi,
      fine: domenica,
      oggi: il(2),
    );
    expect(a.fase, FaseBudget.prima);
    expect(a.ritmo, 21000);
    expect(a.giorniRestanti, 3);
    expect(a.alGiorno, 23000);
  });

  test('oltre il budget lo si sa, e al giorno non resta niente', () {
    final a = andamentoBudget(
      budget: 10000,
      spese: [(data: il(10), centesimi: 12000)],
      inizio: venerdi,
      fine: domenica,
      oggi: il(10),
    );
    expect(a.oltre, isTrue);
    expect(a.restano, -2000);
    expect(a.alGiorno, isNull);
    expect(a.pieno, 1.2);
    expect(a.tacca, closeTo(1 / 3, 0.01));
  });

  test('finito il viaggio: tutti i giorni contano, e una spesa del giorno '
      'dopo va con l\'ultimo', () {
    final a = andamentoBudget(
      budget: 90000,
      spese: [(data: il(13), centesimi: 5000)],
      inizio: venerdi,
      fine: domenica,
      oggi: il(20),
    );
    expect(a.fase, FaseBudget.dopo);
    expect(a.ritmo, 90000);
    expect(a.giorniRestanti, 0);
    expect(a.alGiorno, isNull);
    expect(a.colonne.last.speso, 5000);
  });
}
