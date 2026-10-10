/// Bloccare e sbloccare (5.1; 12, regole 3 e 4; tela, 72). Il blocco è
/// reciproco e immediato, non chiede spiegazioni e non avvisa: chi blocca e
/// chi è bloccato spariscono l'uno all'altro nella parte pubblica. Si blocca
/// da un profilo (5.3) o da una conversazione (5.4), con «…»; dal profilo si
/// vede chi si è bloccato, e si sblocca.
///
/// Richiede la rete. Si misura (07, `persona_bloccata`, `persona_sbloccata`).
library;

import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/parte_pubblica.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';

/// Da dove si blocca, per l'evento.
enum DaDoveSiBlocca { profilo, messaggio }

/// Blocca [nome], la persona [utenteId], dopo il dialogo di sistema. `true`
/// se è bloccata.
Future<bool> blocca(
  BuildContext context, {
  required String utenteId,
  required String nome,
  required DaDoveSiBlocca da,
}) async {
  var conferma = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: 'Bloccare $nome?',
    message:
        'Non vi vedrete più nella parte pubblica: né nella ricerca, né nei '
        'profili, né nei messaggi. $nome non lo saprà.',
    actions: [
      AlertAction(
        title: 'Annulla',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Blocca',
        style: AlertActionStyle.destructive,
        onPressed: () => conferma = true,
      ),
    ],
  );
  if (!conferma || !context.mounted) return false;
  final servizi = Servizi.of(context);
  try {
    await servizi.partePubblica.blocca(utenteId);
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
  await servizi.misurazione.registra(Eventi.personaBloccata, {'da': da.name});
  unawaited(servizi.misurazione.invia());
  return true;
}

/// «Persone bloccate» (tela, 72).
class SchermataPersoneBloccate extends StatefulWidget {
  const SchermataPersoneBloccate({super.key});

  @override
  State<SchermataPersoneBloccate> createState() =>
      _SchermataPersoneBloccateState();
}

class _SchermataPersoneBloccateState extends State<SchermataPersoneBloccate> {
  Future<List<PersonaBloccata>>? _persone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _persone ??= Servizi.of(context).partePubblica.personeBloccate();
  }

  void _ricarica() => setState(() {
    _persone = Servizi.of(context).partePubblica.personeBloccate();
  });

  Future<void> _sblocca(PersonaBloccata p) async {
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Sbloccare ${p.nome}?',
      message:
          'Tornerete a vedervi nella parte pubblica. ${p.nome} non lo saprà.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Sblocca',
          style: AlertActionStyle.primary,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !mounted) return;
    final servizi = Servizi.of(context);
    try {
      await servizi.partePubblica.sblocca(p.id);
      await servizi.misurazione.registra(Eventi.personaSbloccata);
      unawaited(servizi.misurazione.invia());
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
      return;
    }
    if (mounted) _ricarica();
  }

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          const TitoloPagina(
            'Persone bloccate',
            sottotitolo:
                'Non vi vedete a vicenda: né nella ricerca, né nei profili, '
                'né nei messaggi. Non lo sanno.',
          ).entra(context),
          FutureBuilder<List<PersonaBloccata>>(
            future: _persone,
            builder: (context, lette) {
              if (lette.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: IndicatoreAttivita()),
                );
              }
              if (lette.hasError) {
                return Avviso(
                  icona: icona(
                    ios: CupertinoIcons.wifi_slash,
                    android: Icons.wifi_off_rounded,
                  ),
                  errore: true,
                  testo: lette.error is ErroreTrolley
                      ? (lette.error! as ErroreTrolley).messaggio
                      : 'Chi hai bloccato si vede con la connessione.',
                  azioni: [
                    ConLaRete(
                      builder: (context, rete) => PulsantePiccolo(
                        etichetta: 'Riprova',
                        onPressed: rete ? _ricarica : null,
                      ),
                    ),
                  ],
                );
              }
              final persone = lette.data!;
              if (persone.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Non hai bloccato nessuno.',
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                );
              }
              return Column(
                children: [
                  for (final (i, p) in persone.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RigaBloccata(
                        persona: p,
                        onSblocca: () => _sblocca(p),
                      ).entra(context, ritardo: Ritmo.passo * (i + 1)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Avviso(
            icona: icona(ios: CupertinoIcons.nosign, android: Icons.block),
            testo:
                'Si blocca da un profilo o da una conversazione, con «…». Non '
                'serve una spiegazione.',
          ),
        ],
      ),
    ),
  );
}

class _RigaBloccata extends StatelessWidget {
  const _RigaBloccata({required this.persona, required this.onSblocca});

  final PersonaBloccata persona;
  final VoidCallback onSblocca;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Avatar(nome: persona.nome),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                persona.nome,
                style: Testi.evidenza.copyWith(color: Colori.inchiostro),
              ),
              Text(
                'Blocco dal ${dataBreve(persona.dal.toLocal())}',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ],
          ),
        ),
        ConLaRete(
          builder: (context, rete) => PulsantePiccolo(
            etichetta: 'Sblocca',
            onPressed: rete ? onSblocca : null,
          ),
        ),
      ],
    ),
  );
}
