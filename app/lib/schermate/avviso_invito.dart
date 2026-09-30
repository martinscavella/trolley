import 'package:flutter/material.dart';

/// Ricorda a chi arriva da un invito che il viaggio lo sta aspettando.
class AvvisoInvito extends StatelessWidget {
  const AvvisoInvito({super.key, required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colori.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, color: colori.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              testo,
              style: TextStyle(color: colori.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
