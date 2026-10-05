/// «Sul posto» (fase 3.4; 02-il-viaggio.md, regola 7): mentre il viaggio è
/// in corso, il telefono guarda una volta dov'è, lo confronta con la meta e,
/// se coincide, lo ricorda. Basta una volta per viaggio.
///
/// La posizione resta qui: il confronto lo fa il telefono con l'elenco delle
/// destinazioni che ha dentro (ADR-005), a livello di città o paese, e al
/// server va solo l'esito (06-privacy-e-conformita.md). Il permesso non si
/// chiede qui: lo chiede chi mostra prima a cosa serve (tela, 58).
library;

import '../dominio/mappa.dart';
import '../dominio/verifica.dart';
import 'archivio.dart';
import 'database.dart';
import 'destinazioni.dart';
import 'lettura.dart';
import 'posizione.dart';

/// Guarda se la persona è sul posto nel [viaggio], e se lo è lo ricorda e lo
/// manda. `true` se l'ha trovata sul posto adesso.
Future<bool> controllaSulPosto({
  required Viaggio viaggio,
  required Archivio archivio,
  required Posizione posizione,
  required Future<ElencoDestinazioni> Function() elenco,
  DateTime Function() orologio = DateTime.now,
}) async {
  if (!siGuardaIlPosto(
    stato: viaggio.statoA(orologio()),
    importato: viaggio.importato,
    giaSulPosto: await archivio.sulPosto(viaggio.id),
  )) {
    return false;
  }
  if (await posizione.permesso() != PermessoPosizione.concesso) return false;
  final qui = await posizione.qui();
  if (qui == null) return false;
  final ElencoDestinazioni destinazioni;
  try {
    destinazioni = await elenco();
  } on Object {
    return false;
  }
  final meta = destinazioni.trova(
    citta: viaggio.destinazioneCitta,
    paese: viaggio.destinazionePaese,
  );
  final sulPosto = sulPostoDellaMeta(
    qui: qui,
    citta: meta?.tipo == TipoDestinazione.citta
        ? coordinate(meta?.lat, meta?.lon)
        : null,
    paeseMeta: viaggio.destinazionePaese ?? meta?.paese,
    paeseQui: destinazioni.paeseDi(qui),
  );
  if (!sulPosto) return false;
  await archivio.ricordaSulPosto(viaggio.id);
  return true;
}
