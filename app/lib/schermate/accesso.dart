import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../configurazione.dart';
import '../dati/errori.dart';
import '../servizi.dart';
import 'avviso_invito.dart';
import 'benvenuto.dart';

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
    final auth = Servizi.of(context).supabase.auth;
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
    final t = Tavolozza.of(context);
    return LayoutBenvenuto(
      titolo: 'Il viaggio, in un posto solo',
      sottotitolo:
          'Dall\'idea al ritorno: tappe, spese, cose da portare e chi viene '
          'con te.',
      pannello: Pannello(
        padding: const EdgeInsets.all(20),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.invitoInAttesa) ...[
                const AvvisoInvito(
                  testo:
                      'Hai un invito. Entra o crea un account e il viaggio '
                      'si aprirà da solo.',
                ),
                const SizedBox(height: 16),
              ],
              Campo(
                controller: _email,
                segnaposto: 'Email',
                icona: icona(
                  ios: CupertinoIcons.mail,
                  android: Icons.mail_outline,
                ),
                tastiera: TextInputType.emailAddress,
                correzione: false,
                suggerimenti: const [AutofillHints.email],
                azione: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              Campo(
                controller: _password,
                segnaposto: 'Password',
                icona: icona(
                  ios: CupertinoIcons.lock,
                  android: Icons.lock_outline,
                ),
                oscura: true,
                suggerimenti: const [AutofillHints.password],
                azione: TextInputAction.done,
                onInvio: (_) => _esegui(nuovoAccount: false),
              ),
              const SizedBox(height: 20),
              PulsanteGrande(
                etichetta: 'Accedi',
                inCorso: _inCorso,
                onPressed: () => _esegui(nuovoAccount: false),
              ),
              const SizedBox(height: 6),
              PulsanteGrande(
                etichetta: 'Crea un account',
                secondario: true,
                onPressed: _inCorso ? null : () => _esegui(nuovoAccount: true),
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
                          style: Testi.secondario.copyWith(
                            color: t.testoSecondario,
                          ),
                        ).entra(context, da: 6),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
