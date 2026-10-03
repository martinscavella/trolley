import 'dart:math';

import 'package:flutter/widgets.dart';

import 'tavolozza.dart';
import 'testi.dart';

/// Il timbro di una tappa segnata, come nella tela: un cerchio a doppio
/// bordo, un po' storto, con «FATTA» o «SALTATA». Dice lo stato a chi
/// guarda; a VoiceOver lo dice il pulsante che lo contiene.
class Timbro extends StatelessWidget {
  const Timbro(this.testo, {super.key, this.sotto, this.colore = Colori.verde});

  final String testo;

  /// Una riga piccola sotto: la data in cui è stata segnata.
  final String? sotto;
  final Color colore;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: -14 * pi / 180,
      child: Container(
        width: 60,
        height: 60,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colore.withValues(alpha: 0.06),
          border: Border.all(color: colore, width: 1.5),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colore, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                testo,
                style: Testi.titoli(
                  testo.length > 5 ? 8 : 10,
                  spaziatura: 0.04,
                  altezza: 1.1,
                ).copyWith(color: colore),
              ),
              if (sotto != null)
                Text(
                  sotto!,
                  style: Testi.sezione.copyWith(
                    color: colore,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
