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

/// Un timbro scritto, rettangolare e un po' storto: «VERIFICATO» sul
/// biglietto di un viaggio, grande nel riepilogo (tela, 60) e piccolo nel
/// passaporto (65).
class TimbroScritto extends StatelessWidget {
  const TimbroScritto(
    this.testo, {
    super.key,
    this.grande = false,
    this.colore = Colori.bianco,
  });

  final String testo;
  final bool grande;
  final Color colore;

  @override
  Widget build(BuildContext context) => Semantics(
    label: testo[0] + testo.substring(1).toLowerCase(),
    child: ExcludeSemantics(
      child: Transform.rotate(
        angle: (grande ? -12 : -8) * pi / 180,
        child: Container(
          padding: grande
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: colore, width: grande ? 3 : 2),
            borderRadius: BorderRadius.circular(grande ? 10 : 8),
          ),
          child: Text(
            testo,
            style: Testi.titoli(
              grande ? 16 : 10,
              spaziatura: grande ? 0.08 : 0.06,
              altezza: 1,
              peso: grande ? 800 : 700,
            ).copyWith(color: colore),
          ),
        ),
      ),
    ),
  );
}
