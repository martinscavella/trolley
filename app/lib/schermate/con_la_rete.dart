import 'package:flutter/widgets.dart';

import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Ricostruisce quando la rete va e viene. Serve ai controlli che la
/// richiedono: senza, si spengono e dicono perché, invece di fallire dopo
/// (00-architettura.md, regola 3).
class ConLaRete extends StatelessWidget {
  const ConLaRete({super.key, required this.builder});

  final Widget Function(BuildContext context, bool disponibile) builder;

  @override
  Widget build(BuildContext context) {
    final rete = Servizi.of(context).rete;
    return StreamBuilder<bool>(
      stream: rete.cambi,
      initialData: rete.disponibile,
      builder: (context, _) => builder(context, rete.disponibile),
    );
  }
}

/// Una schermata aperta senza rete, e il contenuto che mancava se mancava
/// (07: `apertura_senza_rete`, per H4). Con la rete non si registra niente.
/// Azioni, mai contenuti: il nome della schermata, non quello che mostra.
Future<void> segnaAperturaSenzaRete(
  BuildContext context,
  String schermata, {
  String? mancante,
}) async {
  final servizi = Servizi.of(context);
  if (servizi.rete.disponibile) return;
  await servizi.misurazione.registra(Eventi.aperturaSenzaRete, {
    'schermata': schermata,
    'mancante': mancante,
  });
}
