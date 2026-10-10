/// Le pagine del sito che l'app apre (U.3, 5.1): l'informativa sulla
/// privacy, che cosa si misura (06, «Diritti delle persone») e le condizioni
/// d'uso della parte pubblica (12, regola 7). Stanno sul sito perché
/// lo store chiede un indirizzo, e perché si leggono anche senza l'app.
/// Dietro un'interfaccia, come ogni cosa che esce dall'app
/// (04-integrazioni.md): le prove la sostituiscono.
library;

import 'package:url_launcher/url_launcher.dart';

import '../dominio/codice_invito.dart';

enum PaginaDelSito {
  /// L'informativa sulla privacy: `sito/privacy.html`.
  privacy,

  /// Che cosa si misura, azione per azione: `sito/misurazione.html`.
  misurazione,

  /// Le condizioni d'uso della parte pubblica: `sito/condizioni.html` (5.1).
  condizioni,
}

/// La versione delle condizioni d'uso che si accettano accendendo il profilo
/// pubblico: la data in cima a `sito/condizioni.html`. Cambiando le
/// condizioni cambia anche questa.
const versioneCondizioni = '2026-10-09';

/// Dove sta una pagina: `https://trolleyapp.vercel.app/privacy`. Il sito è
/// quello dei link d'invito.
Uri indirizzoDi(PaginaDelSito pagina) =>
    Uri.https(dominioInviti, '/${pagina.name}');

abstract interface class PagineDelSito {
  /// Apre [pagina]. `false` se non si è aperta.
  Future<bool> apri(PaginaDelSito pagina);
}

/// Il browser dentro l'app: si legge e si torna a Trolley.
class PagineNelBrowser implements PagineDelSito {
  const PagineNelBrowser();

  @override
  Future<bool> apri(PaginaDelSito pagina) async {
    try {
      return await launchUrl(
        indirizzoDi(pagina),
        mode: LaunchMode.inAppBrowserView,
      );
    } on Object {
      return false;
    }
  }
}
