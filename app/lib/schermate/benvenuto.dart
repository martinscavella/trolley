import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/sfondo_vivo.dart';
import '../aspetto/testi.dart';

/// L'impaginazione delle schermate d'ingresso: lo sfondo vivo, il marchio, un
/// titolo e un pannello che sale dal basso con i campi.
class LayoutBenvenuto extends StatelessWidget {
  const LayoutBenvenuto({
    super.key,
    this.titolo,
    this.sottotitolo,
    this.pannello,
    this.inAlto,
  });

  final String? titolo;
  final String? sottotitolo;
  final Widget? pannello;

  /// Un'azione discreta in alto a destra (per esempio "Esci").
  final Widget? inAlto;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AdaptiveScaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: SfondoVivo()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, vincoli) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: vincoli.maxHeight - 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(height: 44, child: inAlto),
                        ),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Marchio(),
                        ).entra(context, da: 10),
                        if (titolo != null) ...[
                          const SizedBox(height: 36),
                          Text(
                            titolo!,
                            style: Testi.titoloGrande.copyWith(
                              color: Colors.white,
                            ),
                          ).entra(context, ritardo: Ritmo.passo),
                        ],
                        if (sottotitolo != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            sottotitolo!,
                            style: Testi.corpo.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ).entra(context, ritardo: Ritmo.passo * 2),
                        ],
                        const SizedBox(height: 32),
                        if (pannello != null)
                          pannello!.entra(
                            context,
                            ritardo: Ritmo.passo * 3,
                            da: 40,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il primo istante: si sta capendo se c'è già un accesso.
class SchermataAvvio extends StatelessWidget {
  const SchermataAvvio({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: AdaptiveScaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SfondoVivo()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Marchio().sboccia(context),
                const SizedBox(height: 32),
                const IndicatoreAttivita(colore: Colors.white),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Primo ingresso su questo telefono, e manca la rete per sapere chi sei.
class SchermataSenzaRete extends StatelessWidget {
  const SchermataSenzaRete({super.key, required this.onRiprova});

  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) => LayoutBenvenuto(
    titolo: 'Serve la connessione',
    sottotitolo:
        'È la prima volta che entri da questo telefono: per scaricare i tuoi '
        'viaggi serve la rete. Dopo, li potrai leggere anche offline.',
    pannello: Pannello(
      child: Column(
        children: [
          Avviso(
            icona: icona(
              ios: CupertinoIcons.wifi_slash,
              android: Icons.wifi_off,
            ),
            testo: 'Controlla il Wi-Fi o i dati, poi riprova.',
          ),
          const SizedBox(height: 16),
          PulsanteGrande(etichetta: 'Riprova', onPressed: onRiprova),
        ],
      ),
    ),
  );
}
