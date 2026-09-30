/// Età minime (01-account-e-profilo.md, 06-privacy-e-conformita.md).
///
/// Il server applica le stesse soglie: qui servono per dirlo prima, non dopo.
library;

const etaMinimaAccount = 16;
const etaMinimaPartePubblica = 18;

/// Anni compiuti alla data [oggi]. Conta solo il giorno di calendario, non l'ora.
int etaCompiuta(DateTime nascita, DateTime oggi) {
  var anni = oggi.year - nascita.year;
  final compleannoNonAncoraArrivato =
      oggi.month < nascita.month ||
      (oggi.month == nascita.month && oggi.day < nascita.day);
  if (compleannoNonAncoraArrivato) anni--;
  return anni;
}

bool puoCreareAccount(DateTime nascita, DateTime oggi) =>
    etaCompiuta(nascita, oggi) >= etaMinimaAccount;

bool puoAverePartePubblica(DateTime nascita, DateTime oggi) =>
    etaCompiuta(nascita, oggi) >= etaMinimaPartePubblica;
