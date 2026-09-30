import 'package:flutter/material.dart';

import '../configurazione.dart';
import '../dati/errori.dart';
import '../servizi.dart';
import 'avviso_invito.dart';

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
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('Trolley', style: testo.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Il viaggio, dall\'idea al ritorno, in un posto solo.',
              style: testo.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (widget.invitoInAttesa) ...[
              const AvvisoInvito(
                testo:
                    'Hai un invito. Entra o crea un account e il viaggio '
                    'si aprirà da solo.',
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _inCorso ? null : () => _esegui(nuovoAccount: false),
              child: const Text('Accedi'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _inCorso ? null : () => _esegui(nuovoAccount: true),
              child: const Text('Crea un account'),
            ),
            if (_messaggio != null) ...[
              const SizedBox(height: 16),
              Text(_messaggio!, style: testo.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
