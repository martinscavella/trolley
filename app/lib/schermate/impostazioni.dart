import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../configurazione.dart';
import '../dati/database.dart';
import '../servizi.dart';

/// Il profilo, la misurazione, l'uscita.
class SchermataImpostazioni extends StatefulWidget {
  const SchermataImpostazioni({super.key});

  @override
  State<SchermataImpostazioni> createState() => _SchermataImpostazioniState();
}

class _SchermataImpostazioniState extends State<SchermataImpostazioni> {
  bool? _misurazioneAttiva;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_misurazioneAttiva == null) {
      Servizi.of(context).misurazione.attiva.then((attiva) {
        if (mounted) setState(() => _misurazioneAttiva = attiva);
      });
    }
  }

  Future<void> _cambiaMisurazione(bool attiva) async {
    setState(() => _misurazioneAttiva = attiva);
    await Servizi.of(context).misurazione.imposta(attiva: attiva);
  }

  Future<void> _esci() async {
    final auth = Servizi.of(context).supabase.auth;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Vuoi uscire?',
      message:
          'I tuoi viaggi restano salvati: li ritrovi quando rientri, anche da '
          'un altro telefono.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Esci',
          style: AlertActionStyle.destructive,
          onPressed: () => auth.signOut(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final servizi = Servizi.of(context);
    final t = Tavolozza.of(context);
    final email = servizi.supabase.auth.currentUser?.email;
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Impostazioni'),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 12,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          StreamBuilder<Utente?>(
            stream: servizi.archivio.osservaProfilo(),
            builder: (context, snapshot) {
              final nome = snapshot.data?.nome ?? '';
              return Column(
                children: [
                  Avatar(nome: nome, dimensione: 76).sboccia(context),
                  const SizedBox(height: 12),
                  Text(
                    nome,
                    style: Testi.titoloSezione.copyWith(color: t.testo),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Testi.secondario.copyWith(
                        color: t.testoSecondario,
                      ),
                    ),
                  ],
                ],
              ).entra(context, da: 8);
            },
          ),
          const SizedBox(height: 20),
          AdaptiveFormSection.insetGrouped(
            header: const Text('PRIVACY'),
            footer: const Text(
              'Trolley registra le azioni che fai, come "creato un viaggio" o '
              '"aperto un invito", per capire quali funzioni servono davvero. '
              'Mai i contenuti: né testi, né documenti, né dove ti trovi. Se la '
              'spegni non perdi nessuna funzione.',
            ),
            children: [
              AdaptiveListTile(
                title: const Text('Misurazione'),
                trailing: _misurazioneAttiva == null
                    ? const SizedBox.shrink()
                    : AdaptiveSwitch(
                        value: _misurazioneAttiva!,
                        onChanged: _cambiaMisurazione,
                      ),
              ),
            ],
          ).entra(context, ritardo: Ritmo.passo),
          AdaptiveFormSection.insetGrouped(
            children: [
              AdaptiveListTile(
                title: Text('Esci', style: TextStyle(color: t.pericolo)),
                onTap: _esci,
              ),
            ],
          ).entra(context, ritardo: Ritmo.passo * 2),
          const SizedBox(height: 16),
          Text(
            'Trolley $versioneApp · prova privata',
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: t.testoTerziario),
          ),
        ],
      ),
    );
  }
}
