/// I collegamenti e i messaggi (5.4; 11-community, regole 3–5; tela, 76–78 e
/// 111–116): a che punto si è con una persona, le richieste, le
/// conversazioni.
///
/// Chi si vede, chi può scrivere a chi e che cosa resta dopo un collegamento
/// tolto lo decide il server (collegamenti_e_messaggi.sql): qui si legge
/// quello che manda e si prepara quanto serve a mostrarlo.
library;

import 'calendario.dart';
import 'profilo_pubblico.dart';

/// La richiesta porta al più tanti caratteri (11, regola 4).
const lunghezzaRichiesta = 200;

/// Un messaggio porta al più tanti caratteri.
const lunghezzaMessaggio = 1000;

/// Ogni quanto una conversazione aperta chiede se ci sono messaggi nuovi:
/// senza notifiche, arrivano così mentre la si guarda.
const intervalloConversazione = Duration(seconds: 5);

/// Il nome di chi ha chiuso l'account non c'è più (P6).
String nomeOAccountChiuso(String? nome) => nome ?? 'Account chiuso';

// ─── Con una persona ──────────────────────────────────────────────────────

/// A che punto si è con chi si guarda (tela, 73, 112 e 113). Nessuno stato —
/// `null` — vuol dire che non c'è niente fra voi: anche quando la sua
/// richiesta l'ha rifiutata chi guarda, che può chiedere a sua volta.
enum StatoCollegamento {
  /// Collegati: vi scrivete.
  collegati,

  /// Chi guarda ha chiesto, e aspetta.
  inviata,

  /// L'altro ha chiesto a chi guarda.
  ricevuta,

  /// Chi guarda ha chiesto, e l'altro non ha accettato. Si può chiedere di
  /// nuovo (M9 non adottata).
  nonAccettata,
}

/// Lo stato con l'altro, come lo dice profilo_pubblico.
class Collegamento {
  const Collegamento({required this.stato, this.dal, this.messaggio});

  static Collegamento? daServer(Object? valore) {
    if (valore is! Map) return null;
    final stato = switch (valore['stato']) {
      'collegati' => StatoCollegamento.collegati,
      'inviata' => StatoCollegamento.inviata,
      'ricevuta' => StatoCollegamento.ricevuta,
      'non_accettata' => StatoCollegamento.nonAccettata,
      _ => null,
    };
    if (stato == null) return null;
    return Collegamento(
      stato: stato,
      dal: DateTime.tryParse(valore['dal'] as String? ?? ''),
      messaggio: valore['messaggio'] as String?,
    );
  }

  final StatoCollegamento stato;

  /// Da quando: collegati, o la richiesta.
  final DateTime? dal;

  /// Il messaggio di una richiesta ricevuta.
  final String? messaggio;
}

/// Com'è andata una richiesta: mandata, o un sì perché l'altro aveva già
/// chiesto, o niente di nuovo (c'era già: una risposta persa).
enum EsitoRichiesta { richiesto, accettato, nessunCambio }

EsitoRichiesta esitoRichiesta(Object? valore) => switch (valore) {
  'richiesto' => EsitoRichiesta.richiesto,
  'accettato' => EsitoRichiesta.accettato,
  _ => EsitoRichiesta.nessunCambio,
};

// ─── I collegamenti ───────────────────────────────────────────────────────

/// Una richiesta ricevuta (tela, 77): chi, quando, che cosa scrive, e il suo
/// profilo, per dire che cosa avete in comune.
class RichiestaRicevuta {
  const RichiestaRicevuta({
    required this.utenteId,
    required this.nome,
    required this.chiestaIl,
    this.messaggio,
    this.profilo,
  });

  factory RichiestaRicevuta.daServer(Map<String, dynamic> r) =>
      RichiestaRicevuta(
        utenteId: r['utente_id'] as String,
        nome: r['nome'] as String? ?? '',
        chiestaIl: DateTime.parse(r['chiesto_il'] as String),
        messaggio: r['messaggio'] as String?,
        profilo: r['profilo'] is Map<String, dynamic>
            ? ProfiloPubblico.daServer(r['profilo'] as Map<String, dynamic>)
            : null,
      );

  final String utenteId;
  final String nome;
  final DateTime chiestaIl;
  final String? messaggio;
  final ProfiloPubblico? profilo;
}

/// Una richiesta mandata: in attesa, o non accettata.
class RichiestaInviata {
  const RichiestaInviata({
    required this.utenteId,
    required this.nome,
    required this.chiestaIl,
    required this.accettata,
  });

  factory RichiestaInviata.daServer(Map<String, dynamic> r) => RichiestaInviata(
    utenteId: r['utente_id'] as String,
    nome: r['nome'] as String? ?? '',
    chiestaIl: DateTime.parse(r['chiesto_il'] as String),
    accettata: r['stato'] == 'rifiutato' ? false : null,
  );

  final String utenteId;
  final String nome;
  final DateTime chiestaIl;

  /// `null` in attesa, `false` non accettata. Accettata non è più qui.
  final bool? accettata;
}

/// Una persona collegata.
typedef Collegato = ({String utenteId, String nome, DateTime? dal});

/// I collegamenti di chi guarda (tela, 77), solo con chi si vede.
class Collegamenti {
  const Collegamenti({
    this.ricevute = const [],
    this.inviate = const [],
    this.collegati = const [],
  });

  factory Collegamenti.daServer(Map<String, dynamic> r) => Collegamenti(
    ricevute: [
      for (final x in (r['ricevute'] as List? ?? const []))
        RichiestaRicevuta.daServer(x as Map<String, dynamic>),
    ],
    inviate: [
      for (final x in (r['inviate'] as List? ?? const []))
        RichiestaInviata.daServer(x as Map<String, dynamic>),
    ],
    collegati: [
      for (final x in (r['collegati'] as List? ?? const []))
        (
          utenteId: (x as Map<String, dynamic>)['utente_id'] as String,
          nome: x['nome'] as String? ?? '',
          dal: DateTime.tryParse(x['dal'] as String? ?? ''),
        ),
    ],
  );

  final List<RichiestaRicevuta> ricevute;
  final List<RichiestaInviata> inviate;
  final List<Collegato> collegati;

  bool get vuoti => ricevute.isEmpty && inviate.isEmpty && collegati.isEmpty;
}

/// Sotto il nome di un collegato: «collegati da ottobre», o «da ottobre
/// 2025» se non è quest'anno.
String collegatiDa(DateTime? dal, DateTime oggi) {
  if (dal == null) return 'collegati';
  final d = dal.toLocal();
  final mese = nomiDeiMesi[d.month - 1];
  return d.year == oggi.year
      ? 'collegati da $mese'
      : 'collegati da $mese ${d.year}';
}

/// Sotto il nome di una richiesta mandata: «in attesa, da oggi», «in
/// attesa, da 2 giorni», «non accettata».
String statoInviata(RichiestaInviata r, DateTime oggi) {
  if (r.accettata == false) return 'non accettata';
  final giorni = soloData(oggi)
      .difference(soloData(r.chiestaIl.toLocal()))
      .inDays;
  return switch (giorni) {
    <= 0 => 'in attesa, da oggi',
    1 => 'in attesa, da ieri',
    _ => 'in attesa, da $giorni giorni',
  };
}

// ─── I messaggi ───────────────────────────────────────────────────────────

/// Un messaggio come lo vede chi guarda.
class Messaggio {
  const Messaggio({
    required this.id,
    required this.mio,
    required this.scrittoIl,
    this.testo,
    this.tolto = false,
    this.inViaggio = false,
    this.nonInviato = false,
  });

  factory Messaggio.daServer(Map<String, dynamic> r) => Messaggio(
    id: r['id'] as String,
    mio: r['mio'] == true,
    testo: r['testo'] as String?,
    scrittoIl: DateTime.parse(r['scritto_il'] as String),
    tolto: r['tolto'] == true,
  );

  final String id;
  final bool mio;

  /// `null` quando chi modera l'ha tolto.
  final String? testo;
  final DateTime scrittoIl;
  final bool tolto;

  /// Solo sul telefono: scritto, e non ancora arrivato al server.
  final bool inViaggio;

  /// Solo sul telefono: non è partito. Si riprova con lo stesso id.
  final bool nonInviato;

  Messaggio nonPartito() => Messaggio(
    id: id,
    mio: mio,
    testo: testo,
    scrittoIl: scrittoIl,
    nonInviato: true,
  );
}

/// [nuovi] dentro [esistenti]: uno per id — vince quello del server, che
/// sostituisce il proprio ancora in viaggio —, dal più vecchio.
List<Messaggio> unisci(List<Messaggio> esistenti, List<Messaggio> nuovi) {
  final perId = {for (final m in esistenti) m.id: m};
  for (final m in nuovi) {
    perId[m.id] = m;
  }
  return perId.values.toList()..sort((a, b) {
    // Quelli non ancora arrivati restano in fondo, dove li si è scritti.
    final (x, y) = (a.inViaggio || a.nonInviato, b.inViaggio || b.nonInviato);
    if (x != y) return x ? 1 : -1;
    return a.scrittoIl.compareTo(b.scrittoIl);
  });
}

/// L'ultimo messaggio arrivato dal server: da lì si chiede se ce ne sono di
/// nuovi.
DateTime? ultimoArrivato(List<Messaggio> messaggi) {
  DateTime? ultimo;
  for (final m in messaggi) {
    if (m.inViaggio || m.nonInviato) continue;
    if (ultimo == null || m.scrittoIl.isAfter(ultimo)) ultimo = m.scrittoIl;
  }
  return ultimo;
}

/// Da quando chiedere i messaggi nuovi: un minuto prima dell'ultimo arrivato.
/// Un messaggio scritto un attimo prima di quello può essere salvato dopo, e
/// chiedendo dall'ultimo si perderebbe; quelli che si hanno già si
/// riconoscono dall'id ([unisci]).
DateTime? daQuandoChiedere(List<Messaggio> messaggi) =>
    ultimoArrivato(messaggi)?.subtract(const Duration(minutes: 1));

/// La conversazione con una persona (tela, 78 e 116).
class Conversazione {
  const Conversazione({
    required this.utenteId,
    required this.collegati,
    required this.messaggi,
    this.nome,
    this.dal,
  });

  factory Conversazione.daServer(Map<String, dynamic> r) => Conversazione(
    utenteId: r['utente_id'] as String,
    nome: r['nome'] as String?,
    collegati: r['collegati'] == true,
    dal: DateTime.tryParse(r['dal'] as String? ?? ''),
    messaggi: [
      for (final m in (r['messaggi'] as List? ?? const []))
        Messaggio.daServer(m as Map<String, dynamic>),
    ],
  );

  final String utenteId;

  /// `null` se ha chiuso l'account.
  final String? nome;

  /// Se vi potete scrivere; altrimenti è una conversazione finita, che resta
  /// a chi guarda (P6).
  final bool collegati;
  final DateTime? dal;
  final List<Messaggio> messaggi;
}

/// Una conversazione nell'elenco (tela, 111).
class RigaConversazione {
  const RigaConversazione({
    required this.utenteId,
    required this.collegati,
    required this.daLeggere,
    this.nome,
    this.dal,
    this.ultimo,
  });

  factory RigaConversazione.daServer(Map<String, dynamic> r) =>
      RigaConversazione(
        utenteId: r['utente_id'] as String,
        nome: r['nome'] as String?,
        collegati: r['collegati'] == true,
        dal: DateTime.tryParse(r['dal'] as String? ?? ''),
        ultimo: r['ultimo'] is Map<String, dynamic>
            ? Messaggio.daServer(r['ultimo'] as Map<String, dynamic>)
            : null,
        daLeggere: (r['da_leggere'] as num?)?.toInt() ?? 0,
      );

  final String utenteId;
  final String? nome;
  final bool collegati;
  final DateTime? dal;
  final Messaggio? ultimo;
  final int daLeggere;

  /// Quando è successo qualcosa l'ultima volta: per metterle in ordine.
  DateTime? get quando => ultimo?.scrittoIl ?? dal;
}

/// La riga sotto il nome (tela, 111): l'ultimo messaggio, «Tu: …» se è tuo;
/// per una conversazione finita, che non siete più collegati; per un
/// collegamento nuovo, di scrivere.
String anteprima(RigaConversazione r) {
  if (!r.collegati) return 'Non siete più collegati';
  final u = r.ultimo;
  if (u == null) return 'Siete collegati: scrivi tu per primo';
  final testo = u.tolto ? 'Messaggio tolto da chi modera' : (u.testo ?? '');
  final riga = testo.replaceAll(RegExp(r'\s+'), ' ').trim();
  return u.mio ? 'Tu: $riga' : riga;
}

/// Quante conversazioni hanno qualcosa da leggere: il numero su «Messaggi».
int conversazioniDaLeggere(List<RigaConversazione> righe) =>
    righe.where((r) => r.daLeggere > 0).length;

/// Quando, nell'elenco: l'ora se è oggi, «ieri», poi il giorno.
String quandoInElenco(DateTime quando, DateTime adesso) {
  final q = quando.toLocal();
  final giorni = soloData(adesso).difference(soloData(q)).inDays;
  if (giorni <= 0) {
    return '${q.hour.toString().padLeft(2, '0')}:'
        '${q.minute.toString().padLeft(2, '0')}';
  }
  if (giorni == 1) return 'ieri';
  final mese = nomiDeiMesi[q.month - 1].substring(0, 3);
  return q.year == adesso.year ? '${q.day} $mese' : '${q.day} $mese ${q.year}';
}

/// L'etichetta di un giorno nella conversazione: «OGGI», «IERI», «29
/// SETTEMBRE».
String giornoDellaConversazione(DateTime quando, DateTime adesso) {
  final q = quando.toLocal();
  final giorni = soloData(adesso).difference(soloData(q)).inDays;
  if (giorni <= 0) return 'OGGI';
  if (giorni == 1) return 'IERI';
  final giorno = '${q.day} ${nomiDeiMesi[q.month - 1]}';
  return (q.year == adesso.year ? giorno : '$giorno ${q.year}').toUpperCase();
}
