import 'package:flutter/widgets.dart';

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
