import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../dati/database.dart';
import '../dati/errori.dart';
import '../dominio/codice_invito.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'viaggi.dart';

/// Un viaggio: per ora chi c'è e l'invito. Tappe, spese e liste arrivano con la
/// fase 1.
class SchermataViaggio extends StatefulWidget {
  const SchermataViaggio({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataViaggio> createState() => _SchermataViaggioState();
}

class _SchermataViaggioState extends State<SchermataViaggio> {
  bool _invitoInCorso = false;

  Future<void> _invita(BuildContext origine) async {
    final servizi = Servizi.of(context);
    // Il foglio di condivisione su iPad vuole sapere da dove parte.
    final box = origine.findRenderObject() as RenderBox?;
    setState(() => _invitoInCorso = true);
    try {
      final codice = await servizi.archivio.creaInvito(widget.viaggioId);
      await servizi.misurazione.registra(Eventi.invitoCreato);
      await SharePlus.instance.share(
        ShareParams(
          text: messaggioInvito(codice),
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on ErroreTrolley catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.messaggio)));
      }
    } finally {
      if (mounted) setState(() => _invitoInCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivio = Servizi.of(context).archivio;
    return StreamBuilder<Viaggio?>(
      stream: archivio.osservaViaggio(widget.viaggioId),
      builder: (context, snapshot) {
        final viaggio = snapshot.data;
        if (viaggio == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : const Text('Questo viaggio non è sul telefono.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(titoloViaggio(viaggio))),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(descrizioneStato(viaggio.stato)),
                subtitle: viaggio.stato == 'idea'
                    ? const Text('Senza date: si possono aggiungere dopo.')
                    : Text('${viaggio.dataInizio} → ${viaggio.dataFine}'),
              ),
              const Divider(),
              const _Titolo('Chi c\'è'),
              StreamBuilder<List<(Partecipazione, Utente?)>>(
                stream: archivio.osservaPartecipanti(widget.viaggioId),
                builder: (context, snapshot) => Column(
                  children: [
                    for (final (partecipazione, utente)
                        in snapshot.data ?? const <(Partecipazione, Utente?)>[])
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(utente?.nome ?? '…'),
                        subtitle: partecipazione.ruolo == 'creatore'
                            ? const Text('Ha creato il viaggio')
                            : null,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (origine) => FilledButton.icon(
                    onPressed: _invitoInCorso ? null : () => _invita(origine),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Invita qualcuno'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(testo, style: Theme.of(context).textTheme.titleSmall),
  );
}
