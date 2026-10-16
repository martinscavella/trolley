/// Le notifiche (14-notifiche.md; tela, 82–84, 119, 120). Per ora sono i
/// promemoria che il telefono si programma da solo, dalla copia: prima di
/// partire, le tappe da segnare, le idee che scadono, un anno fa. Quando
/// partono, che cosa dicono e dove portano stanno qui, in un posto solo: una
/// notifica non ha una schermata sua dove mettere le parole.
library;

import 'calendario.dart';
import 'partenza.dart';
import 'stato_viaggio.dart';

enum TipoNotifica {
  primaDiPartire('prima_di_partire', Duration(hours: 18)),
  tappeDaSegnare('tappe_da_segnare', Duration(hours: 21)),
  ideaCheScade('idea_che_scade', Duration(hours: 10)),
  unAnnoFa('un_anno_fa', Duration(hours: 10));

  const TipoNotifica(this.codice, this.ora);

  /// Come si scrive negli eventi e nelle impostazioni.
  final String codice;

  /// L'ora del giorno a cui parte: fra le 10 e le 21, mai di notte (14,
  /// regola 6).
  final Duration ora;

  /// Mentre un viaggio è in corso arrivano solo le notifiche di quel viaggio:
  /// le idee e gli anni fa aspettano che finisca (14, casi limite). Prima di
  /// partire e le tappe no: sono di un viaggio che comincia, o che c'è.
  bool get aspettaIlViaggio => this == ideaCheScade || this == unAnnoFa;

  static TipoNotifica? leggi(String? codice) =>
      values.where((t) => t.codice == codice).firstOrNull;
}

/// Un viaggio di chi guarda, con quello che serve per i suoi promemoria.
class ViaggioPerLeNotifiche {
  const ViaggioPerLeNotifiche({
    required this.id,
    required this.stato,
    this.citta,
    this.inizio,
    this.fine,
    this.scadenza,
    this.importato = false,
    this.mancano = 0,
    this.diNessuno = 0,
    this.documenti = 0,
    this.traguardi = 0,
    this.giorni = const [],
  });

  final String id;
  final StatoViaggio stato;

  /// La città della meta: senza, i testi non nominano il posto.
  final String? citta;
  final DateTime? inizio;
  final DateTime? fine;

  /// Per un'idea, l'ultimo giorno in cui è viva (dominio/stato_viaggio.dart).
  final DateTime? scadenza;
  final bool importato;

  /// Le cose della propria valigia ancora da mettere, e quelle del viaggio
  /// che non porta nessuno (dominio/partenza.dart).
  final int mancano;
  final int diNessuno;

  /// I documenti del viaggio su questo telefono.
  final int documenti;

  /// I traguardi presi con questo viaggio.
  final int traguardi;

  /// I giorni del viaggio, con quante tappe restano da segnare.
  final List<({String id, DateTime data, int daSegnare})> giorni;
}

/// Dove porta una notifica toccata: sempre un posto preciso, mai l'elenco
/// (14, regola 7). La giornata per le tappe; per gli altri il viaggio, che
/// apre Prima di partire, l'idea o il riepilogo secondo il [tipo].
typedef DovePorta = ({TipoNotifica tipo, String viaggioId, String? giornoId});

/// Come viaggia [DovePorta] dentro la notifica, e torna indietro quando la
/// si tocca.
String scriviDovePorta(DovePorta d) =>
    [d.tipo.codice, d.viaggioId, ?d.giornoId].join('|');

DovePorta? leggiDovePorta(String? testo) {
  final parti = testo?.split('|');
  if (parti == null || parti.length < 2 || parti.length > 3) return null;
  final tipo = TipoNotifica.leggi(parti[0]);
  if (tipo == null || parti[1].isEmpty) return null;
  return (
    tipo: tipo,
    viaggioId: parti[1],
    giornoId: parti.length == 3 ? parti[2] : null,
  );
}

/// Una notifica da programmare.
class Notifica {
  const Notifica({
    required this.chiave,
    required this.tipo,
    required this.quando,
    required this.titolo,
    required this.testo,
    required this.dovePorta,
  });

  /// Chi è, fra una programmazione e l'altra: una notifica arrivata non
  /// riparte (una volta sola, 14), ma un periodo o una partenza che cambiano
  /// ne fanno una nuova.
  final String chiave;
  final TipoNotifica tipo;

  /// Quando parte, nell'ora del telefono.
  final DateTime quando;
  final String titolo;
  final String testo;
  final DovePorta dovePorta;

  @override
  String toString() => '$chiave @ $quando: $titolo — $testo';
}

/// Dopo «Non ora», quanto prima che il foglio del permesso si riproponga da
/// solo, con il prossimo viaggio che prende le date (tela, 82). Dal profilo
/// le notifiche si accendono quando si vuole (tela, 119).
const riproponiDopo = Duration(days: 30);

/// Se il foglio del permesso si propone da solo [oggi]: il telefono non l'ha
/// mai chiesto, e un «Non ora» non c'è o è di più di un mese fa. Nessuna
/// insistenza dopo un no del telefono (14, casi limite).
bool permessoDaProporre({
  required bool mai,
  required DateTime? nonOraIl,
  required DateTime oggi,
}) =>
    mai &&
    (nonOraIl == null ||
        !soloData(oggi).isBefore(soloData(nonOraIl).add(riproponiDopo)));

/// iOS ne tiene in attesa 64 al massimo: si programmano le più vicine, e le
/// altre arrivano con le programmazioni dopo.
const massimoNotifiche = 60;

/// Da quanto dopo il suo giorno un «un anno fa» arriva ancora, se il
/// telefono non ha potuto programmarlo prima.
const unAnnoFaFinoA = Duration(days: 7);

/// Le notifiche da programmare [adesso] (ora del telefono), dalla prima.
/// [spente]: i tipi spenti dalla persona (14, regola 2). [arrivate]: le
/// chiavi già arrivate su questo telefono.
List<Notifica> notificheDa(
  Iterable<ViaggioPerLeNotifiche> viaggi, {
  required DateTime adesso,
  Set<TipoNotifica> spente = const {},
  Set<String> arrivate = const {},
}) {
  final tutti = [...viaggi]..sort((a, b) => a.id.compareTo(b.id));
  final inViaggio = <DateTime>{
    for (final v in tutti)
      if ((v.stato == StatoViaggio.definito ||
              v.stato == StatoViaggio.inCorso) &&
          v.inizio != null &&
          v.fine != null)
        for (
          var g = soloData(v.inizio!);
          !g.isAfter(soloData(v.fine!));
          g = g.add(const Duration(days: 1))
        )
          g,
  };
  final notifiche = <Notifica>[];

  void aggiungi({
    required TipoNotifica tipo,
    required String chiave,
    required DateTime dal,
    required DateTime al,
    required ViaggioPerLeNotifiche viaggio,
    String? giornoId,
    Set<DateTime> occupati = const {},
    required (String, String) Function(DateTime giorno) parole,
  }) {
    if (spente.contains(tipo) || arrivate.contains(chiave)) return;
    final quando = _primoMomento(
      dal: dal,
      al: al,
      ora: tipo.ora,
      adesso: adesso,
      aspetta: tipo.aspettaIlViaggio ? inViaggio : const {},
      occupati: occupati,
    );
    if (quando == null) return;
    final (titolo, testo) = parole(soloData(quando));
    notifiche.add(
      Notifica(
        chiave: chiave,
        tipo: tipo,
        quando: quando,
        titolo: titolo,
        testo: testo,
        dovePorta: (tipo: tipo, viaggioId: viaggio.id, giornoId: giornoId),
      ),
    );
  }

  for (final v in tutti) {
    final citta = v.citta;
    switch (v.stato) {
      case StatoViaggio.definito || StatoViaggio.inCorso:
        final inizio = v.inizio;
        if (v.stato == StatoViaggio.definito &&
            inizio != null &&
            (v.mancano > 0 || v.diNessuno > 0 || v.documenti == 0)) {
          aggiungi(
            tipo: TipoNotifica.primaDiPartire,
            chiave: 'prima_di_partire:${v.id}:${scriviData(inizio)}',
            dal: inizio.subtract(const Duration(days: giorniPrimaDiPartire)),
            al: inizio.subtract(const Duration(days: 1)),
            viaggio: v,
            parole: (giorno) => (
              _siParte(inizio, giorno, citta),
              _cosaManca(v.mancano, v.diNessuno, v.documenti),
            ),
          );
        }
        for (final g in v.giorni) {
          if (g.daSegnare <= 0) continue;
          aggiungi(
            tipo: TipoNotifica.tappeDaSegnare,
            chiave: 'tappe_da_segnare:${g.id}:${scriviData(g.data)}',
            dal: g.data,
            al: g.data,
            viaggio: v,
            giornoId: g.id,
            parole: (_) => (
              citta == null
                  ? "Com'è andata oggi?"
                  : "Com'è andata oggi a $citta?",
              g.daSegnare == 1
                  ? 'Resta una tappa da segnare: fatta o saltata, basta un '
                        'tocco.'
                  : 'Restano ${g.daSegnare} tappe da segnare: fatta o saltata, '
                        'un tocco ciascuna.',
            ),
          );
        }
      case StatoViaggio.chiuso:
        // Un viaggio aggiunto a mano è finito chissà quando: niente
        // anniversario (fase 4.3).
        final (inizio, fine) = (v.inizio, v.fine);
        if (v.importato || inizio == null || fine == null) break;
        final anniversario = aggiungiMesi(soloData(fine), 12);
        final giorni = giorniDiCalendario(inizio, fine);
        aggiungi(
          tipo: TipoNotifica.unAnnoFa,
          chiave: 'un_anno_fa:${v.id}',
          dal: anniversario,
          al: anniversario.add(unAnnoFaFinoA),
          viaggio: v,
          parole: (_) => (
            citta == null
                ? 'Un anno fa eri in viaggio'
                : 'Un anno fa eri a $citta',
            '${[giorni == 1 ? 'Un giorno' : '$giorni giorni', if (v.traguardi == 1) 'un traguardo', if (v.traguardi > 1) '${v.traguardi} traguardi'].join(', ')}.',
          ),
        );
      case StatoViaggio.idea || StatoViaggio.archiviato:
        break;
    }
  }

  // Le idee per ultime, dalla prima a scadere: al massimo una al giorno in
  // tutto, anche con quindici idee (14, casi limite).
  final idee = [
    for (final v in tutti)
      if (v.stato == StatoViaggio.idea && v.scadenza != null) v,
  ]..sort((a, b) => a.scadenza!.compareTo(b.scadenza!));
  final giorniConUnIdea = <DateTime>{};
  for (final v in idee) {
    final scadenza = soloData(v.scadenza!);
    final prima = notifiche.length;
    aggiungi(
      tipo: TipoNotifica.ideaCheScade,
      chiave: 'idea_che_scade:${v.id}:${scriviData(scadenza)}',
      dal: scadenza.subtract(preavvisoArchivio),
      al: scadenza,
      viaggio: v,
      occupati: giorniConUnIdea,
      parole: (_) => (
        v.citta == null
            ? "Questo viaggio è ancora un'idea?"
            : "${v.citta} è ancora un'idea?",
        'Completa le date per sbloccare il resto.',
      ),
    );
    if (notifiche.length > prima) {
      giorniConUnIdea.add(soloData(notifiche.last.quando));
    }
  }

  notifiche.sort((a, b) => a.quando.compareTo(b.quando));
  return notifiche.take(massimoNotifiche).toList();
}

/// Il primo momento all'[ora] di un giorno fra [dal] e [al] che viene dopo
/// [adesso]. I giorni in [aspetta] non contano e spostano la fine in avanti:
/// la notifica aspetta che passino. Quelli in [occupati] si saltano e basta.
DateTime? _primoMomento({
  required DateTime dal,
  required DateTime al,
  required Duration ora,
  required DateTime adesso,
  Set<DateTime> aspetta = const {},
  Set<DateTime> occupati = const {},
}) {
  var giorno = soloData(dal);
  var ultimo = soloData(al);
  while (!giorno.isAfter(ultimo)) {
    if (aspetta.contains(giorno)) {
      ultimo = ultimo.add(const Duration(days: 1));
    } else if (!occupati.contains(giorno)) {
      final momento = DateTime(
        giorno.year,
        giorno.month,
        giorno.day,
        ora.inHours,
        ora.inMinutes % 60,
      );
      if (momento.isAfter(adesso)) return momento;
    }
    giorno = giorno.add(const Duration(days: 1));
  }
  return null;
}

/// «Si parte giovedì per Porto», o «Si parte domani».
String _siParte(DateTime inizio, DateTime giorno, String? citta) {
  final mancano = soloData(inizio).difference(giorno).inDays;
  final quando = mancano == 1
      ? 'domani'
      : nomiDeiGiorni[soloData(inizio).weekday - 1];
  return citta == null ? 'Si parte $quando' : 'Si parte $quando per $citta';
}

/// Che cosa manca prima di partire, in una frase.
String _cosaManca(int mancano, int diNessuno, int documenti) {
  final parti = [
    if (mancano == 1) 'manca una cosa da mettere in valigia',
    if (mancano > 1) 'mancano $mancano cose da mettere in valigia',
    if (diNessuno == 1) 'una cosa del viaggio non la porta nessuno',
    if (diNessuno > 1) '$diNessuno cose del viaggio non le porta nessuno',
    if (documenti == 0) 'sul telefono non c\'è ancora nessun documento',
  ];
  final frase = parti.length == 1
      ? parti.single
      : '${parti.sublist(0, parti.length - 1).join(', ')} e ${parti.last}';
  return '${frase[0].toUpperCase()}${frase.substring(1)}.';
}
