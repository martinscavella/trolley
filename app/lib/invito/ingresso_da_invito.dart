/// L'ingresso da invito (ADR-004).
///
/// È l'unico punto dell'app che sa **come** arriva un codice d'invito. Oggi arriva
/// da un link con lo schema dell'app, domani da un link universale o da un servizio
/// dedicato: sostituirlo non deve toccare nient'altro.
library;

import 'package:app_links/app_links.dart';

import '../dominio/codice_invito.dart';

abstract interface class IngressoDaInvito {
  /// I codici che arrivano da fuori, compreso quello che ha aperto l'app.
  Stream<String> get codici;
}

/// I codici portati dai link che aprono l'app.
class IngressoDaLink implements IngressoDaInvito {
  IngressoDaLink([AppLinks? links]) : _links = links ?? AppLinks();

  final AppLinks _links;

  @override
  Stream<String> get codici =>
      _links.uriLinkStream.map(codiceDaLink).where((c) => c != null).cast();
}
