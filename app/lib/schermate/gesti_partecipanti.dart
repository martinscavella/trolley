/// I gesti su chi partecipa che contano per la misurazione, in un posto solo:
/// le schermate li chiamano da qui così che nessuno dimentichi l'evento.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../dati/errori.dart';
import '../dominio/codice_invito.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Crea un link d'invito e lo consegna al foglio di condivisione del telefono
/// (03, regola 1), con il suo evento (07: `invito_creato`, per H3). Richiede
/// la rete: chi chiama spegne il controllo prima, e qui lo si ricontrolla.
/// [origine] è il pulsante da cui parte, che il foglio su iPad vuole sapere.
Future<void> invitaQualcuno(
  BuildContext context,
  String viaggioId, {
  Rect? origine,
}) async {
  final servizi = Servizi.of(context);
  if (!servizi.rete.disponibile) {
    throw const ErroreTrolley(
      'Per invitare qualcuno serve la connessione.',
      serveLaRete: true,
    );
  }
  final codice = await servizi.archivio.creaInvito(viaggioId);
  await servizi.misurazione.registra(Eventi.invitoCreato, {
    'viaggio_id': viaggioId,
  });
  HapticFeedback.lightImpact();
  await SharePlus.instance.share(
    ShareParams(text: messaggioInvito(codice), sharePositionOrigin: origine),
  );
}

/// Dove sta un pulsante sullo schermo, per [invitaQualcuno].
Rect? posizioneDi(GlobalKey chiave) {
  final box = chiave.currentContext?.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}
