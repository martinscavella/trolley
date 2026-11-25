import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/aspetto/mappamondo.dart';
import 'package:trolley/dati/confini.dart';

/// Il globo del mappamondo (tela, 66): la proiezione e i gesti.
void main() {
  void vicino((double, double, double) punto, (double, double, double) atteso) {
    expect(punto.$1, closeTo(atteso.$1, 1e-6));
    expect(punto.$2, closeTo(atteso.$2, 1e-6));
    expect(punto.$3, closeTo(atteso.$3, 1e-6));
  }

  test('il centro sta davanti, l\'est a destra, il nord in alto, gli '
      'antipodi dietro', () {
    final o = Ortografica((lat: 0, lon: 0));
    vicino(o.coordinata((lat: 0, lon: 0)), (0, 0, 1));
    vicino(o.coordinata((lat: 0, lon: 90)), (1, 0, 0));
    vicino(o.coordinata((lat: 90, lon: 0)), (0, 1, 0));
    vicino(o.coordinata((lat: 0, lon: 180)), (0, 0, -1));
  });

  test('girato verso una meta, la meta è al centro', () {
    for (final meta in [
      (lat: 41.15, lon: -8.61),
      (lat: 35.0, lon: 135.77),
      (lat: -33.9, lon: 151.2),
    ]) {
      vicino(Ortografica(meta).coordinata(meta), (0, 0, 1));
    }
  });

  test('dal disco si torna al punto della Terra che si vede', () {
    for (final centro in [(lat: 41.15, lon: -8.61), (lat: -33.9, lon: 151.2)]) {
      final o = Ortografica(centro);
      final c = o.inverso(0, 0)!;
      expect(c.lat, closeTo(centro.lat, 1e-4));
      expect(c.lon, closeTo(centro.lon, 1e-4));
      final (x, y, _) = o.coordinata((lat: 30, lon: centro.lon + 20));
      final indietro = o.inverso(x, y)!;
      expect(indietro.lat, closeTo(30, 1e-4));
      expect(indietro.lon, closeTo(centro.lon + 20, 1e-4));
    }
    expect(Ortografica((lat: 0, lon: 0)).inverso(0.9, 0.9), isNull);
  });

  test('il volo verso un paese va per la strada più corta, sul cerchio '
      'massimo', () {
    const roma = (lat: 41.9, lon: 12.5);
    const tokyo = (lat: 35.7, lon: 139.7);
    expect(sullaStrada(roma, tokyo, 0).lat, closeTo(roma.lat, 1e-4));
    expect(sullaStrada(roma, tokyo, 1).lon, closeTo(tokyo.lon, 1e-4));
    // A metà strada si passa sopra la Siberia, non sopra l'India.
    final meta = sullaStrada(roma, tokyo, 0.5);
    expect(meta.lat, greaterThan(50));
    expect(
      distanzaSulGlobo(roma, meta),
      closeTo(distanzaSulGlobo(meta, tokyo), 1e-3),
    );
    // Attraverso i 180 gradi, non dall'altra parte del mondo.
    final fiji = sullaStrada(
      (lat: -17.0, lon: 178.0),
      (lat: -14.0, lon: -172.0),
      0.5,
    );
    expect(fiji.lon.abs(), greaterThan(170));
  });

  testWidgets('la bandiera si legge dall\'immagine: senza il margine, a '
      'sinistra il primo colore e a destra l\'ultimo; una sola tinta non è '
      'una bandiera', (tester) async {
    Future<ui.Image> disegna(List<Color> strisce) async {
      final registro = ui.PictureRecorder();
      final tela = Canvas(registro);
      // Un margine trasparente attorno, come nelle emoji.
      for (final (i, colore) in strisce.indexed) {
        tela.drawRect(
          Rect.fromLTWH(10 + i * 20.0, 10, 20, 40),
          Paint()..color = colore,
        );
      }
      return registro.endRecording().toImage(20 + strisce.length * 20, 60);
    }

    await tester.runAsync(() async {
      const verde = Color(0xFF009246);
      const bianco = Color(0xFFFFFFFF);
      const rosso = Color(0xFFCE2B37);
      final italia = await Bandiera.daImmagine(
        await disegna([verde, bianco, rosso]),
      );
      expect(italia, isNotNull);
      expect(italia!.colore(0, 0.5), verde);
      expect(italia.colore(0.5, 0.5), bianco);
      expect(italia.colore(1, 0.5), rosso);
      // Le due lettere senza le emoji: un colore solo.
      expect(await Bandiera.daImmagine(await disegna([rosso])), isNull);
    });
  });

  testWidgets('si disegna, si trascina e si gira verso un altro paese', (
    tester,
  ) async {
    Confini.usa(
      Confini.daByte(
        ByteData.sublistView(File('assets/confini.bin').readAsBytesSync()),
      ),
    );
    Widget globo(({double lat, double lon}) centro) => MaterialApp(
      home: Center(
        child: Mappamondo(
          grattati: const {'PT', 'JP', 'VA'},
          centro: centro,
          punti: const {'VA': (lat: 41.9, lon: 12.45)},
          etichetta: 'Mappamondo: 3 paesi visitati',
        ),
      ),
    );
    await tester.pumpWidget(globo((lat: 41.15, lon: -8.61)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Mappamondo: 3 paesi visitati'), findsOne);

    await tester.fling(find.byType(Mappamondo), const Offset(-200, 40), 800);
    await tester.pumpAndSettle();
    await tester.pumpWidget(globo((lat: 35.0, lon: 135.77)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
