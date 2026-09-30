import 'package:flutter/material.dart';

import '../dati/errori.dart';
import '../dominio/eta.dart';
import '../servizi.dart';
import 'avviso_invito.dart';

/// Nome e data di nascita, la prima volta (01-account-e-profilo.md).
///
/// La data di nascita dopo non si cambia da soli: lo si dice prima di salvarla.
class SchermataNuovoProfilo extends StatefulWidget {
  const SchermataNuovoProfilo({
    super.key,
    required this.invitoInAttesa,
    required this.onCreato,
  });

  final bool invitoInAttesa;
  final Future<void> Function() onCreato;

  @override
  State<SchermataNuovoProfilo> createState() => _SchermataNuovoProfiloState();
}

class _SchermataNuovoProfiloState extends State<SchermataNuovoProfilo> {
  final _nome = TextEditingController();
  DateTime? _nascita;
  bool _inCorso = false;
  String? _messaggio;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _scegliData() async {
    final oggi = DateTime.now();
    final scelta = await showDatePicker(
      context: context,
      initialDate: _nascita ?? DateTime(oggi.year - 30, oggi.month, oggi.day),
      firstDate: DateTime(1900),
      lastDate: oggi,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Data di nascita',
    );
    if (scelta != null) setState(() => _nascita = scelta);
  }

  Future<void> _salva() async {
    final nome = _nome.text.trim();
    final nascita = _nascita;
    if (nome.isEmpty || nascita == null) {
      setState(() => _messaggio = 'Servono il nome e la data di nascita.');
      return;
    }
    if (!puoCreareAccount(nascita, DateTime.now())) {
      setState(
        () => _messaggio =
            'Per usare Trolley servono $etaMinimaAccount anni compiuti.',
      );
      return;
    }
    setState(() {
      _inCorso = true;
      _messaggio = null;
    });
    try {
      await Servizi.of(context).archivio
          .creaProfilo(nome: nome, dataNascita: nascita);
      await widget.onCreato();
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _messaggio = e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final nascita = _nascita;
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => Servizi.of(context).supabase.auth.signOut(),
            child: const Text('Esci'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Come ti chiami?', style: testo.headlineSmall),
            const SizedBox(height: 8),
            const Text('Il nome lo vedono i compagni dei tuoi viaggi.'),
            const SizedBox(height: 24),
            if (widget.invitoInAttesa) ...[
              const AvvisoInvito(
                testo:
                    'Ancora un passo e il viaggio a cui ti hanno invitato '
                    'si apre.',
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _scegliData,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                nascita == null
                    ? 'Data di nascita'
                    : MaterialLocalizations.of(context)
                          .formatMediumDate(nascita),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Servono $etaMinimaAccount anni compiuti. Dopo averla salvata, '
              'la data di nascita si può cambiare solo tramite l\'assistenza.',
              style: testo.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _inCorso ? null : _salva,
              child: const Text('Continua'),
            ),
            if (_messaggio != null) ...[
              const SizedBox(height: 16),
              Text(_messaggio!),
            ],
          ],
        ),
      ),
    );
  }
}
