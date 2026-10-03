/// La giornata come una striscia, come nella tela: le tappe una dopo
/// l'altra, lunghe quanto durano, e il tempo libero tratteggiato. Se la somma
/// sfora, quello che avanza esce rosso oltre la fine, e la fine è segnata.
///
/// È un disegno: quello che dice lo dice anche il testo accanto, quindi
/// VoiceOver non lo legge.
library;

import 'dart:math';

import 'package:flutter/widgets.dart';

import 'tavolozza.dart';

/// Un pezzo della striscia: una tappa, lunga quanto dura. Tratteggiato, è una
/// tappa che ancora non c'è: quella che si sta aggiungendo.
class PezzoStriscia {
  const PezzoStriscia(this.durata, this.colore, {this.tratteggiato = false});

  final Duration durata;
  final Color colore;
  final bool tratteggiato;
}

class StrisciaGiornata extends StatelessWidget {
  const StrisciaGiornata({
    super.key,
    required this.capienza,
    required this.pezzi,
    this.altezza = 10,
  });

  final Duration capienza;
  final List<PezzoStriscia> pezzi;
  final double altezza;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: altezza,
      width: double.infinity,
      child: CustomPaint(painter: _Pittore(capienza, pezzi)),
    ),
  );
}

class _Pittore extends CustomPainter {
  const _Pittore(this.capienza, this.pezzi);

  final Duration capienza;
  final List<PezzoStriscia> pezzi;

  /// Lo spazio a destra per quello che sfora.
  static const _oltre = 14.0;
  static const _fessura = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final totale = pezzi.fold<int>(0, (s, p) => s + p.durata.inMinutes);
    final minuti = max(capienza.inMinutes, 1);
    final sfora = totale > minuti;
    final fine = sfora ? size.width - _oltre : size.width;
    final scala = fine / minuti;
    final raggio = Radius.circular(min(size.height / 4, 5));

    var x = 0.0;
    for (final p in pezzi) {
      final largo = p.durata.inMinutes * scala;
      final da = x;
      final a = x + largo - _fessura;
      x += largo;
      if (a <= da) continue;
      if (!sfora || a <= fine) {
        _pezzo(canvas, Rect.fromLTRB(da, 0, a, size.height), raggio, p);
      } else if (da >= fine) {
        _rosso(canvas, Rect.fromLTRB(da, 0, a, size.height), raggio);
      } else {
        _pezzo(canvas, Rect.fromLTRB(da, 0, fine, size.height), raggio, p);
        _rosso(canvas, Rect.fromLTRB(fine, 0, a, size.height), raggio);
      }
    }
    if (!sfora && x < fine) {
      _tratteggio(
        canvas,
        RRect.fromRectAndRadius(Rect.fromLTRB(x, 0, fine, size.height), raggio),
        fondo: const Color(0xFFF4F5F8),
        righe: const Color(0xFFE3E6EE),
      );
    }
    if (sfora) {
      canvas.drawRect(
        Rect.fromLTWH(fine - 1, -4, 2, size.height + 8),
        Paint()..color = Colori.inchiostro,
      );
    }
  }

  void _pezzo(Canvas canvas, Rect r, Radius raggio, PezzoStriscia p) {
    final forma = RRect.fromRectAndRadius(r, raggio);
    if (p.tratteggiato) {
      _tratteggio(
        canvas,
        forma,
        fondo: Color.lerp(p.colore, Colori.bianco, 0.55)!,
        righe: p.colore,
      );
    } else {
      canvas.drawRRect(forma, Paint()..color = p.colore);
    }
  }

  void _rosso(Canvas canvas, Rect r, Radius raggio) => _tratteggio(
    canvas,
    RRect.fromRectAndRadius(r, raggio),
    fondo: const Color(0xFFE9A39B),
    righe: Colori.pericolo,
  );

  void _tratteggio(
    Canvas canvas,
    RRect forma, {
    required Color fondo,
    required Color righe,
  }) {
    canvas
      ..save()
      ..clipRRect(forma)
      ..drawRRect(forma, Paint()..color = fondo);
    final pennello = Paint()
      ..color = righe
      ..strokeWidth = 3;
    final r = forma.outerRect;
    for (var d = r.left - r.height; d < r.right; d += 8) {
      canvas.drawLine(
        Offset(d, r.bottom),
        Offset(d + r.height, r.top),
        pennello,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Pittore vecchio) =>
      vecchio.capienza != capienza || !_uguali(vecchio.pezzi, pezzi);

  static bool _uguali(List<PezzoStriscia> a, List<PezzoStriscia> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].durata != b[i].durata ||
          a[i].colore != b[i].colore ||
          a[i].tratteggiato != b[i].tratteggiato) {
        return false;
      }
    }
    return true;
  }
}
