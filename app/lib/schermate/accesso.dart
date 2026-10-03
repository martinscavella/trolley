import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../configurazione.dart';
import '../dati/errori.dart';
import '../servizi.dart';
import 'avviso_invito.dart';
import 'benvenuto.dart';
import 'con_la_rete.dart';

/// Accesso con email e password (01-account-e-profilo.md).
///
/// Google e Apple devono esserci tutti e tre dalla prima release: Apple richiede
/// il programma sviluppatori a pagamento, Google la configurazione OAuth.
class SchermataAccesso extends StatefulWidget {
  const SchermataAccesso({super.key, required this.invitoInAttesa});

  final bool invitoInAttesa;

  @override
  State<SchermataAccesso> createState() => _SchermataAccessoState();
}

class _SchermataAccessoState extends State<SchermataAccesso> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _inCorso = false;
  String? _messaggio;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _esegui({required bool nuovoAccount}) async {
    final servizi = Servizi.of(context);
    final auth = servizi.supabase.auth;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _messaggio = 'Servono email e password.');
      return;
    }
    setState(() {
      _inCorso = true;
      _messaggio = null;
    });
    try {
      if (nuovoAccount) {
        final risposta = await alServer(
          () => auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: redirectAccesso,
          ),
          rete: servizi.rete,
        );
        if (risposta.session == null && mounted) {
          setState(
            () => _messaggio =
                'Ti abbiamo mandato un\'email. Apri il link da questo telefono '
                'per confermare l\'account.',
          );
        }
      } else {
        await alServer(
          () => auth.signInWithPassword(email: email, password: password),
          rete: servizi.rete,
        );
      }
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _messaggio = e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBenvenuto(
      // Con un invito già in attesa la nota non serve: lo dice la scheda.
      nota: widget.invitoInAttesa
          ? null
          : 'Hai un invito? Aprilo dal link che ti hanno mandato, oppure '
                'inserisci il codice dopo l\'accesso.',
      scheda: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.invitoInAttesa) ...[
              const AvvisoInvito(
                testo:
                    'Hai un invito. Entra o crea un account e il viaggio '
                    'si aprirà da solo.',
              ),
              const SizedBox(height: 20),
            ],
            Campo(
              controller: _email,
              etichetta: 'Email',
              segnaposto: 'nome@esempio.it',
              tastiera: TextInputType.emailAddress,
              correzione: false,
              suggerimenti: const [AutofillHints.email],
              azione: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            Campo(
              controller: _password,
              etichetta: 'Password',
              segnaposto: '••••••••',
              oscura: true,
              suggerimenti: const [AutofillHints.password],
              azione: TextInputAction.done,
              onInvio: (_) => _esegui(nuovoAccount: false),
            ),
            const SizedBox(height: 20),
            // Entrare richiede la rete: senza, i pulsanti si spengono e
            // lo dicono, invece di provare e fallire.
            ConLaRete(
              builder: (context, rete) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PulsanteGrande(
                    etichetta: 'Accedi',
                    inCorso: _inCorso,
                    motivo: rete ? null : motivoSenzaRete,
                    onPressed: () => _esegui(nuovoAccount: false),
                  ),
                  const SizedBox(height: 10),
                  PulsanteGrande(
                    etichetta: 'Crea un account',
                    secondario: true,
                    onPressed: _inCorso || !rete
                        ? null
                        : () => _esegui(nuovoAccount: true),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: Ritmo.medio,
              curve: Ritmo.curva,
              child: _messaggio == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _messaggio!,
                        textAlign: TextAlign.center,
                        style: Testi.secondario.copyWith(color: Colori.ardesia),
                      ).entra(context, da: 6),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
