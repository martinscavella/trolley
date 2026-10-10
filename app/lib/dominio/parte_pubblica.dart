/// La parte pubblica vista dalla persona (5.1; 11-community, 12-sicurezza;
/// tela, 68–72 e 103–107): a che punto è il suo profilo pubblico, il numero di
/// telefono come lo si scrive, che cosa si segnala e perché.
///
/// Chi può accendere il profilo lo decide il server (sicurezza.sql): qui si
/// legge quello che dice, per mostrare il passo giusto prima di chiedere.
library;

/// Com'è la parte pubblica per chi guarda, come la dice il server
/// (`la_mia_parte_pubblica`).
class StatoPartePubblica {
  const StatoPartePubblica({
    required this.visibile,
    required this.accoglie,
    required this.maggiorenne,
    required this.attivo,
    this.telefono,
    this.sospesoIl,
    this.motivoSospensione,
    this.condizioni,
  });

  factory StatoPartePubblica.daServer(Map<String, dynamic> r) =>
      StatoPartePubblica(
        visibile: r['visibile'] == true,
        accoglie: r['accoglie'] == true,
        maggiorenne: r['maggiorenne'] == true,
        attivo: r['attivo'] == true,
        telefono: r['telefono'] as String?,
        sospesoIl: DateTime.tryParse(r['sospeso_il'] as String? ?? ''),
        motivoSospensione: r['sospensione_motivo'] as String?,
        condizioni: r['condizioni'] as String?,
      );

  /// Se nel profilo c'è la parte pubblica: aperta, o chiusa ai nuovi. Per il
  /// team sempre.
  final bool visibile;

  /// Se adesso si può accendere il profilo pubblico.
  final bool accoglie;

  /// 18 anni compiuti.
  final bool maggiorenne;

  /// Il profilo pubblico è acceso.
  final bool attivo;

  /// Il numero verificato, `+393471234567`; `null` se non c'è.
  final String? telefono;

  /// Da quando chi modera l'ha sospeso, e perché (12, regola 9).
  final DateTime? sospesoIl;
  final String? motivoSospensione;

  /// Quali condizioni d'uso ha accettato accendendolo.
  final String? condizioni;
}

/// Che cosa mostra «Il tuo profilo pubblico».
enum PassoProfiloPubblico {
  /// Chi modera l'ha sospeso (tela, 107).
  sospeso,

  /// È acceso: si spegne (tela, 106).
  acceso,

  /// Meno di 18 anni: la parte pubblica non c'è.
  minorenne,

  /// La parte pubblica non accoglie profili nuovi, per ora (12, casi limite).
  chiusa,

  /// Prima il numero (tela, 68).
  serveIlTelefono,

  /// Il numero c'è: si accende, accettando le condizioni d'uso (tela, 105).
  daAccendere,
}

PassoProfiloPubblico passoDi(StatoPartePubblica s) {
  if (s.sospesoIl != null) return PassoProfiloPubblico.sospeso;
  if (s.attivo) return PassoProfiloPubblico.acceso;
  if (!s.maggiorenne) return PassoProfiloPubblico.minorenne;
  if (!s.accoglie) return PassoProfiloPubblico.chiusa;
  if (s.telefono == null) return PassoProfiloPubblico.serveIlTelefono;
  return PassoProfiloPubblico.daAccendere;
}

// ─── Il numero di telefono ─────────────────────────────────────────────────

final _internazionale = RegExp(r'^\+[1-9][0-9]{7,14}$');

/// Il numero com'è scritto, nella forma che il server vuole: `347 123 4567`
/// diventa `+393471234567`. Senza prefisso è italiano; `00` vale `+`. `null`
/// se non è un numero.
String? numeroInternazionale(String scritto) {
  var n = scritto.replaceAll(RegExp(r'[\s\-().\/]'), '');
  if (n.startsWith('00')) n = '+${n.substring(2)}';
  if (!n.startsWith('+')) n = '+39$n';
  return _internazionale.hasMatch(n) ? n : null;
}

/// Il numero detto senza mostrarlo tutto: `+39 347 ••• 4567`.
String numeroNascosto(String numero) {
  if (numero.length < 8) return numero;
  final fine = numero.substring(numero.length - 4);
  if (numero.startsWith('+39') && numero.length >= 12) {
    return '+39 ${numero.substring(3, 6)} ••• $fine';
  }
  return '${numero.substring(0, 3)} ••• $fine';
}

/// Le cifre del codice SMS (Twilio Verify ne manda sei).
const cifreDelCodice = 6;

/// Il codice com'è scritto, solo le cifre; `null` finché non sono tutte.
String? codiceCompleto(String scritto) {
  final cifre = scritto.replaceAll(RegExp(r'[^0-9]'), '');
  return cifre.length == cifreDelCodice ? cifre : null;
}

/// Quanto si aspetta prima di chiedere un altro codice (tela, 69).
const attesaNuovoCodice = Duration(seconds: 45);

// ─── Segnalare ─────────────────────────────────────────────────────────────

/// Che cosa si segnala: un profilo (5.3), un messaggio (5.4).
enum TipoSegnalato { profilo, messaggio }

/// I motivi fissi (tela, 70), nell'ordine in cui si mostrano. Sono quelli
/// che le condizioni d'uso vietano (12, regola 7); il nome è quello del
/// server.
enum MotivoSegnalazione { molestie, falso, inappropriato, minore, altro }

/// Come la si è chiusa, quando è gestita.
enum EsitoSegnalazione { nessunaAzione, contenutoRimosso, profiloSospeso }

/// Una propria segnalazione, con il suo stato (tela, 71).
class Segnalazione {
  const Segnalazione({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.motivo,
    required this.creataIl,
    this.esito,
    this.gestitaIl,
  });

  factory Segnalazione.daServer(Map<String, dynamic> r) => Segnalazione(
    id: r['id'] as String,
    tipo: TipoSegnalato.values.byName(r['tipo_oggetto'] as String),
    nome: r['nome'] as String? ?? '',
    motivo: MotivoSegnalazione.values.byName(r['motivo'] as String),
    creataIl: DateTime.parse(r['creata_il'] as String),
    esito: switch (r['esito']) {
      'nessuna_azione' => EsitoSegnalazione.nessunaAzione,
      'contenuto_rimosso' => EsitoSegnalazione.contenutoRimosso,
      'profilo_sospeso' => EsitoSegnalazione.profiloSospeso,
      _ => null,
    },
    gestitaIl: DateTime.tryParse(r['gestita_il'] as String? ?? ''),
  );

  final String id;
  final TipoSegnalato tipo;

  /// Il nome di chi è segnalato, com'era quando la si è fatta.
  final String nome;
  final MotivoSegnalazione motivo;
  final DateTime creataIl;
  final EsitoSegnalazione? esito;
  final DateTime? gestitaIl;

  bool get gestita => esito != null;
}

/// Una persona bloccata (tela, 72).
typedef PersonaBloccata = ({String id, String nome, DateTime dal});
