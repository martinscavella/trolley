/// La barra principale che galleggia in basso, come nella tela: una pillola
/// d'inchiostro, la voce attiva bianca con il suo nome, le altre solo icona,
/// e in mezzo il "+" giallo, perché da lì nasce un'idea.
library;

import 'package:flutter/material.dart';

import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Una voce della barra in basso.
class VoceBarra {
  const VoceBarra({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.attiva = false,
  });

  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool attiva;
}

class BarraPrincipale extends StatelessWidget {
  const BarraPrincipale({
    super.key,
    required this.prima,
    required this.dopo,
    required this.onAggiungi,
    required this.etichettaAggiungi,
  });

  final List<VoceBarra> prima;
  final List<VoceBarra> dopo;
  final VoidCallback onAggiungi;
  final String etichettaAggiungi;

  /// Quanto spazio lasciare in fondo ai contenuti perché la barra non li copra.
  static const ingombro = 112.0;

  @override
  Widget build(BuildContext context) {
    Widget voce(VoceBarra v) => Semantics(
      selected: v.attiva,
      child: Premibile(
        onTap: v.onTap,
        scala: 0.94,
        etichetta: v.etichetta,
        child: AnimatedContainer(
          duration: Ritmo.breve,
          curve: Ritmo.curva,
          height: 48,
          constraints: const BoxConstraints(minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: v.attiva ? 16 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: v.attiva ? Colori.bianco : Colori.inchiostro,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                v.icona,
                size: 22,
                color: v.attiva
                    ? Colori.inchiostro
                    : Colori.bianco.withValues(alpha: 0.75),
              ),
              if (v.attiva) ...[
                const SizedBox(width: 8),
                Text(
                  v.etichetta,
                  maxLines: 1,
                  style: Testi.voceBarra.copyWith(color: Colori.inchiostro),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Container(
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colori.inchiostro,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colori.inchiostro.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ...prima.map(voce),
          Premibile(
            onTap: onAggiungi,
            scala: 0.9,
            etichetta: etichettaAggiungi,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colori.sole,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 28,
                color: Colori.inchiostro,
              ),
            ),
          ),
          ...dopo.map(voce),
        ],
      ),
    );
  }
}
