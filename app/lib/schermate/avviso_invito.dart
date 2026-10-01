import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';

/// Ricorda a chi arriva da un invito che il viaggio lo sta aspettando. Entra
/// con un riflesso, per farsi notare una volta sola.
class AvvisoInvito extends StatelessWidget {
  const AvvisoInvito({super.key, required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final avviso = Avviso(
      icona: icona(
        ios: CupertinoIcons.envelope_open_fill,
        android: Icons.mark_email_unread,
      ),
      testo: testo,
    );
    if (movimentoRidotto(context)) return avviso;
    return avviso
        .animate()
        .fadeIn(duration: Ritmo.medio)
        .slideY(begin: -0.2, end: 0, curve: Ritmo.curva)
        .then(delay: 200.ms)
        .shimmer(duration: 1200.ms, color: const Color(0x33FFFFFF));
  }
}
