/// La giornata come una striscia, come nella tela: le tappe una dopo
/// l'altra, lunghe quanto durano, e il tempo libero tratteggiato. Se la somma
/// sfora, quello che avanza esce rosso oltre la fine, e la fine è segnata.
///
/// Con [StrisciaGiornata.daOra] le tappe stanno ai loro orari (tela, 127):
/// la striscia è la giornata da quando comincia a quando finisce, e il tempo
/// libero è dov'è davvero. Una tappa fuori posto è rossa.
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
  const PezzoStriscia(
    this.durata,
    this.colore, {
    this.tratteggiato = false,
    this.inizio,
    this.rosso = false,
  });

  final Duration durata;
  final Color colore;
  final bool tratteggiato;

  /// A che ora comincia: conta solo in una striscia con gli orari.
  final Duration? inizio;

  /// Fuori posto: si sovrappone a un'altra, o esce dalla giornata.
  final bool rosso;
}

class StrisciaGiornata extends StatelessWidget {
  const StrisciaGiornata({
    super.key,
    required this.capienza,
    required this.pezzi,
    this.altezza = 10,
    this.daOra,
  });

  final Duration capienza;
  final List<PezzoStriscia> pezzi;
  final double altezza;

  /// L'ora in cui comincia la giornata: con questa, i pezzi stanno ai loro
  /// orari invece che uno dopo l'altro.
  final Duration? daOra;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: altezza,
      width: double.infinity,
      child: CustomPaint(painter: _Pittore(capienza, pezzi, daOra)),
    ),
  );
}

class _Pittore extends CustomPainter {
  const _Pittore(this.capienza, this.pezzi, this.daOra);

  final Duration capienza;
  final List<PezzoStriscia> pezzi;
  final Duration? daOra;

  /// Lo spazio a destra per quello che sfora.
  static const _oltre = 14.0;
  static const _fessura = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final da = daOra;
    if (da != null) return _agliOrari(canvas, size, da);
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

  /// I pezzi ai loro orari, sul tratteggio della giornata.
  void _agliOrari(Canvas canvas, Size size, Duration da) {
    final minuti = max(capienza.inMinutes, 1);
    final scala = size.width / minuti;
    final raggio = Radius.circular(min(size.height / 4, 5));
    _tratteggio(
      canvas,
      RRect.fromRectAndRadius(Offset.zero & size, raggio),
      fondo: const Color(0xFFF4F5F8),
      righe: const Color(0xFFE3E6EE),
    );
    for (final p in pezzi) {
      final inizio = p.inizio;
      if (inizio == null) continue;
      final sinistra = ((inizio - da).inMinutes * scala).clamp(0, size.width);
      final destra = ((inizio + p.durata - da).inMinutes * scala - _fessura)
          .clamp(0, size.width);
      if (destra <= sinistra) continue;
      final r = Rect.fromLTRB(sinistra.toDouble(), 0, destra.toDouble(), size.height);
      if (p.rosso) {
        _rosso(canvas, r, raggio);
      } else {
        _pezzo(canvas, r, raggio, p);
      }
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
      vecchio.capienza != capienza ||
      vecchio.daOra != daOra ||
      !_uguali(vecchio.pezzi, pezzi);

  static bool _uguali(List<PezzoStriscia> a, List<PezzoStriscia> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].durata != b[i].durata ||
          a[i].colore != b[i].colore ||
          a[i].tratteggiato != b[i].tratteggiato ||
          a[i].inizio != b[i].inizio ||
          a[i].rosso != b[i].rosso) {
        return false;
      }
    }
    return true;
  }
}
