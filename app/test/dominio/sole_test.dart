import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/sole.dart';

/// Dove sta il sole, per il giorno e la notte del mappamondo (tela, 144).
void main() {
  test('al solstizio d\'estate, a mezzogiorno di Greenwich, il sole è a picco '
      'sul tropico del Cancro, vicino a Greenwich', () {
    final s = sottoIlSole(DateTime.utc(2026, 6, 21, 12));
    expect(s.lat, closeTo(23.44, 0.1));
    expect(s.lon, closeTo(0, 1.5));
  });

  test('all\'equinozio di primavera è sull\'equatore', () {
    expect(sottoIlSole(DateTime.utc(2026, 3, 20, 14, 46)).lat, closeTo(0, 0.2));
  });

  test('il 1° novembre alle 18 di Greenwich è a sud, sopra il Messico', () {
    final s = sottoIlSole(DateTime.utc(2026, 11, 1, 18));
    expect(s.lat, closeTo(-14.5, 0.3));
    expect(s.lon, closeTo(-94, 1));
  });

  test('l\'ora del telefono non conta: conta l\'istante', () {
    final utc = DateTime.utc(2026, 11, 1, 18);
    expect(sottoIlSole(utc.toLocal()), sottoIlSole(utc));
  });
}
