import 'package:flutter/material.dart';

import '../dati/database.dart';
import '../dati/errori.dart';
import '../dominio/codice_invito.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'viaggio.dart';

/// I propri viaggi. Si legge dalla copia locale: funziona anche senza rete.
class SchermataViaggi extends StatefulWidget {
  const SchermataViaggi({super.key, required this.onCodice});

  /// Un codice d'invito digitato a mano: lo gestisce l'app come quelli dei link.
  final ValueChanged<String> onCodice;

  @override
  State<SchermataViaggi> createState() => _SchermataViaggiState();
}

class _SchermataViaggiState extends State<SchermataViaggi> {
  bool _offline = false;

  Future<void> _aggiorna() async {
    try {
      await Servizi.of(context).archivio.aggiornaCopia();
      if (mounted) setState(() => _offline = false);
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _offline = e.serveLaRete);
    }
  }

  Future<void> _nuovaIdea() async {
    final servizi = Servizi.of(context);
    final citta = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoNuovaIdea(),
    );
    if (citta == null || !mounted) return;
    try {
      final id = await servizi.archivio.creaIdea(citta: citta);
      await servizi.misurazione.registra(Eventi.viaggioCreato, {
        'stato_iniziale': 'idea',
        'durata_prevista_giorni': null,
      });
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SchermataViaggio(viaggioId: id),
        ),
      );
    } on ErroreTrolley catch (e) {
      _avvisa(e.messaggio);
    }
  }

  Future<void> _inserisciCodice() async {
    final codice = await showDialog<String>(
      context: context,
      builder: (_) => const DialogoCodiceInvito(),
    );
    if (codice != null) widget.onCodice(codice);
  }

  Future<void> _misurazione() async {
    final misurazione = Servizi.of(context).misurazione;
    final attiva = await misurazione.attiva;
    if (!mounted) return;
    final scelta = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoMisurazione(attiva: attiva),
    );
    if (scelta != null) await misurazione.imposta(attiva: scelta);
  }

  void _avvisa(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('I tuoi viaggi'),
        actions: [
          IconButton(
            tooltip: 'Ho un codice d\'invito',
            onPressed: _inserisciCodice,
            icon: const Icon(Icons.vpn_key_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (voce) => switch (voce) {
              'misurazione' => _misurazione(),
              'esci' => servizi.supabase.auth.signOut(),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'misurazione', child: Text('Misurazione')),
              PopupMenuItem(value: 'esci', child: Text('Esci')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuovaIdea,
        icon: const Icon(Icons.add),
        label: const Text('Nuova idea'),
      ),
      body: RefreshIndicator(
        onRefresh: _aggiorna,
        child: StreamBuilder<List<Viaggio>>(
          stream: servizi.archivio.osservaViaggi(),
          builder: (context, snapshot) {
            final viaggi = snapshot.data ?? const [];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (_offline)
                  const ListTile(
                    leading: Icon(Icons.cloud_off),
                    title: Text('Sei offline'),
                    subtitle: Text('Stai vedendo la copia sul telefono.'),
                  ),
                if (snapshot.hasData && viaggi.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nessun viaggio ancora. Comincia da un\'idea, anche '
                      'senza date, oppure entra in un viaggio con il codice '
                      'che ti hanno mandato.',
                    ),
                  ),
                for (final v in viaggi)
                  ListTile(
                    title: Text(titoloViaggio(v)),
                    subtitle: Text(descrizioneStato(v.stato)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SchermataViaggio(viaggioId: v.id),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String titoloViaggio(Viaggio v) => v.destinazioneCitta ?? 'Viaggio senza meta';

String descrizioneStato(String stato) => switch (stato) {
  'idea' => 'Idea',
  'definito' => 'Definito',
  'in_corso' => 'In corso',
  'chiuso' => 'Chiuso',
  'archiviato' => 'Archiviato',
  _ => stato,
};

class _DialogoNuovaIdea extends StatefulWidget {
  const _DialogoNuovaIdea();

  @override
  State<_DialogoNuovaIdea> createState() => _DialogoNuovaIdeaState();
}

class _DialogoNuovaIdeaState extends State<_DialogoNuovaIdea> {
  final _citta = TextEditingController();

  @override
  void dispose() {
    _citta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuova idea'),
    content: TextField(
      controller: _citta,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Dove? (anche vago)',
        helperText: 'Le date si aggiungono dopo.',
      ),
      onSubmitted: (testo) => Navigator.of(context).pop(testo),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_citta.text),
        child: const Text('Crea'),
      ),
    ],
  );
}

/// Inserimento a mano del codice d'invito: l'appoggio per chi il link non ce
/// l'ha più sottomano (ADR-004).
class DialogoCodiceInvito extends StatefulWidget {
  const DialogoCodiceInvito({super.key});

  @override
  State<DialogoCodiceInvito> createState() => _DialogoCodiceInvitoState();
}

class _DialogoCodiceInvitoState extends State<DialogoCodiceInvito> {
  final _codice = TextEditingController();
  String? _errore;

  @override
  void dispose() {
    _codice.dispose();
    super.dispose();
  }

  void _conferma() {
    final codice = normalizzaCodice(_codice.text);
    if (codice == null) {
      setState(
        () => _errore =
            'Il codice ha $lunghezzaCodice caratteri, come ABCD-2345.',
      );
      return;
    }
    Navigator.of(context).pop(codice);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Codice d\'invito'),
    content: TextField(
      controller: _codice,
      autofocus: true,
      autocorrect: false,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(hintText: 'ABCD-2345', errorText: _errore),
      onSubmitted: (_) => _conferma(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annulla'),
      ),
      FilledButton(onPressed: _conferma, child: const Text('Entra')),
    ],
  );
}

/// La persona deve poter sapere cosa si misura e rifiutarlo senza perdere
/// funzioni (15-misurazione.md).
class _DialogoMisurazione extends StatefulWidget {
  const _DialogoMisurazione({required this.attiva});

  final bool attiva;

  @override
  State<_DialogoMisurazione> createState() => _DialogoMisurazioneState();
}

class _DialogoMisurazioneState extends State<_DialogoMisurazione> {
  late bool _attiva = widget.attiva;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Misurazione'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trolley registra le azioni che fai — "creato un viaggio", '
          '"aperto un invito" — per capire quali funzioni servono davvero. '
          'Mai i contenuti: né testi, né documenti, né dove ti trovi.\n\n'
          'Se la spegni non perdi nessuna funzione.',
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Misurazione attiva'),
          value: _attiva,
          onChanged: (valore) => setState(() => _attiva = valore),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_attiva),
        child: const Text('Salva'),
      ),
    ],
  );
}
