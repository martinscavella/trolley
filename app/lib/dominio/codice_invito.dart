/// Il codice d'invito e i link che lo portano (ADR-004).
///
/// Il codice è lo stesso che genera il server (`privato.genera_codice_invito`):
/// otto caratteri senza quelli che si confondono, perché si deve poter digitare.
library;

const alfabetoInvito = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const lunghezzaCodice = 8;

/// Dominio dei link d'invito. Temporaneo: il definitivo sarà un dominio neutro proprio.
const dominioInviti = 'trolleyapp.vercel.app';

/// Schema dell'app. Con l'account Apple gratuito i link universali non esistono:
/// la pagina d'invito apre l'app con questo schema.
const schemaApp = 'trolley';

/// Il codice come lo conserva il server, oppure `null` se non è un codice valido.
/// Accetta minuscole, spazi e trattini: è quello che succede quando lo si digita.
String? normalizzaCodice(String grezzo) {
  final codice = grezzo.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (codice.length != lunghezzaCodice) return null;
  for (final carattere in codice.split('')) {
    if (!alfabetoInvito.contains(carattere)) return null;
  }
  return codice;
}

/// `ABCD2345` → `ABCD-2345`.
String codiceLeggibile(String codice) =>
    '${codice.substring(0, 4)}-${codice.substring(4)}';

/// Il link da condividere. È una pagina web, così funziona anche senza l'app.
Uri linkInvito(String codice) => Uri.https(dominioInviti, '/i/$codice');

/// Il codice contenuto in un link che ha aperto l'app, oppure `null`.
///
/// Riconosce `trolley://invito/CODICE` (quello che usa oggi la pagina d'invito)
/// e `https://trolleyapp.vercel.app/i/CODICE` (quando ci saranno i link universali).
String? codiceDaLink(Uri link) {
  final segmenti = link.pathSegments.where((s) => s.isNotEmpty).toList();

  if (link.scheme == schemaApp &&
      link.host == 'invito' &&
      segmenti.length == 1) {
    return normalizzaCodice(segmenti.single);
  }
  if (link.scheme == 'https' &&
      link.host == dominioInviti &&
      segmenti.length == 2 &&
      segmenti.first == 'i') {
    return normalizzaCodice(segmenti.last);
  }
  return null;
}

/// Il messaggio che accompagna il link. Contiene l'istruzione per chi non ha l'app,
/// perché la riuscita non può dipendere da quanto è sveglia la persona (ADR-004).
String messaggioInvito(String codice) => [
  'Ti aggiungo al nostro viaggio su Trolley: ${linkInvito(codice)}',
  '',
  'Se non hai ancora l\'app, installala e poi riapri questo link. '
      'Oppure inserisci il codice ${codiceLeggibile(codice)}.',
].join('\n');
