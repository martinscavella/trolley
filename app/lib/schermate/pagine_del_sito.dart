/// Aprire una pagina del sito da una schermata (U.3): l'informativa dal
/// profilo e dall'accesso, che cosa si misura dal profilo. Richiede la rete:
/// senza, il rimando si spegne e lo dice prima (con_la_rete.dart).
///
/// Nessun evento: nessuna soglia chiede quante volte si legge l'informativa
/// (07, regola 2).
library;

import 'package:flutter/widgets.dart';

import '../aspetto/elementi.dart';
import '../dati/pagine.dart';
import '../servizi.dart';

Future<void> apriLaPagina(BuildContext context, PaginaDelSito pagina) async {
  final aperta = await Servizi.of(context).pagine.apri(pagina);
  if (!aperta && context.mounted) {
    mostraMessaggio(context, 'La pagina non si è aperta.', errore: true);
  }
}
