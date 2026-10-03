import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'piattaforma.dart';
import 'tavolozza.dart';

/// La miniatura di un documento, come nella tela (10, 11, 14): un foglio
/// bianco con il bordo grigio e gli angoli appena tondi, e dentro la prima
/// pagina. Finché la pagina non c'è, o se non si riesce a disegnarla, il segno
/// di un foglio.
class MiniaturaDocumento extends StatelessWidget {
  const MiniaturaDocumento({
    super.key,
    required this.immagine,
    this.larghezza = 40,
    this.altezza = 52,
  });

  final ImageProvider? immagine;
  final double larghezza;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    final segno = Center(
      child: Icon(
        icona(ios: CupertinoIcons.doc_text, android: Icons.description_outlined),
        size: larghezza * 0.5,
        color: Colori.piombo,
      ),
    );
    return Container(
      width: larghezza,
      height: altezza,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colori.cenere, width: 1.5),
      ),
      child: immagine == null
          ? segno
          : Image(
              image: immagine!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => segno,
            ),
    );
  }
}
