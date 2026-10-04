import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/conflitti.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/calendario.dart';
import '../dominio/divisione.dart';
import '../dominio/giornate.dart';
import '../dominio/periodo.dart';
import '../dominio/tappe.dart';
import '../dominio/valute.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'spese.dart' show elenco;

/// Che cosa ha scelto la persona davanti a due versioni. Il nome è quello
/// dell'evento (07-misurazione.md): `conflitto_risolto.scelta`.
enum SceltaVersione {
  /// La propria: la cosa diventa com'era la sua versione.
  tua,

  /// Quella già salvata, che resta com'è.
  loro,

  /// Tutte e due, come due cose distinte: solo per le voci.
  entrambe,
}

/// Prova una scrittura che porta la versione. Se trova due versioni le mostra
/// e fa scegliere (02 §3). Restituisce la scelta — [SceltaVersione.tua] anche
/// quando non c'era niente da scegliere —, oppure `null` se la persona è
/// tornata indietro senza scegliere: allora quello che aveva scritto è ancora
/// dov'era, nel foglio da cui ha salvato.
Future<SceltaVersione?> salvaOScegli(
  BuildContext context,
  Future<void> Function() scrittura,
) async {
  final misurazione = Servizi.of(context).misurazione;
  try {
    await scrittura();
    return SceltaVersione.tua;
  } on Conflitto catch (c) {
    await misurazione.registra(Eventi.conflittoMostrato, {'tipo': c.cosa.name});
    if (!context.mounted) return null;
    return apriAPienoSchermo<SceltaVersione>(
      context,
      SchermataDueVersioni(conflitto: c),
    );
  }
}

/// Due versioni della stessa cosa (tela, 34–36): sopra la propria, non ancora
/// salvata, con il bordo cobalto; sotto quella già salvata, con chi e quando.
/// Quello che cambia è evidenziato. Si sceglie con un tocco, e non si mescola
/// niente: due testi non diventano un terzo. «Tienile tutte e due» solo dove
/// possono convivere, cioè per le voci.
///
/// Chiudendo senza scegliere si torna al foglio, con quello che si era scritto.
class SchermataDueVersioni extends StatefulWidget {
  const SchermataDueVersioni({super.key, required this.conflitto});

  final Conflitto conflitto;

  @override
  State<SchermataDueVersioni> createState() => _SchermataDueVersioniState();
}

class _SchermataDueVersioniState extends State<SchermataDueVersioni> {
  late Conflitto _conflitto = widget.conflitto;

  /// Quello che serve per dire le cose con il loro nome: chi è chi, quali
  /// sono i giorni, se la tappa entra ancora.
  _Contesto? _contesto;
  SceltaVersione? _inCorso;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contesto == null) _carica();
  }

  Future<void> _carica() async {
    final contesto = await _Contesto.di(Servizi.of(context), _conflitto);
    if (mounted) setState(() => _contesto = contesto);
  }

  Future<void> _scegli(SceltaVersione scelta) async {
    final servizi = Servizi.of(context);
    final archivio = servizi.archivio;
    setState(() => _inCorso = scelta);
    try {
      switch (scelta) {
        case SceltaVersione.tua:
          await archivio.tieniLaTua(_conflitto);
        case SceltaVersione.entrambe:
          await archivio.tieniTutteEDue(_conflitto);
        case SceltaVersione.loro:
          // È già quella sul telefono: non c'è niente da scrivere.
          break;
      }
      await servizi.misurazione.registra(Eventi.conflittoRisolto, {
        'tipo': _conflitto.cosa.name,
        'scelta': scelta.name,
      });
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(scelta);
    } on Conflitto catch (nuovo) {
      // È cambiata ancora mentre si sceglieva: le due versioni di adesso.
      await servizi.misurazione.registra(Eventi.conflittoMostrato, {
        'tipo': nuovo.cosa.name,
      });
      if (!mounted) return;
      setState(() {
        _conflitto = nuovo;
        _contesto = null;
      });
      await _carica();
      if (mounted) {
        mostraMessaggio(
          context,
          'Intanto è cambiata ancora: ora vedi com\'è adesso.',
        );
      }
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contesto = _contesto;
    return Pagina(
      corpo: Builder(
        // La copia risponde subito: niente rotella per un istante.
        builder: (context) => contesto == null
            ? const SizedBox.shrink()
            : ConLaRete(
                builder: (context, rete) => _contenuto(context, contesto, rete),
              ),
      ),
    );
  }

  Widget _contenuto(BuildContext context, _Contesto contesto, bool rete) {
    final c = _conflitto;
    final mq = MediaQuery.paddingOf(context);
    final parole = _Parole(c, contesto);
    final righe = _righe(c, contesto);
    final scrive = rete ? null : motivoSenzaRete;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, mq.top, 20, mq.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Semantics(
              header: true,
              child: Text(
                'Due versioni',
                style: Testi.titolo.copyWith(color: Colori.inchiostro),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              parole.spiegazione,
              style: Testi.secondario.copyWith(color: Colori.grafite),
            ),
          ),
          const SizedBox(height: 12),
          _Versione(
            mia: true,
            chi: 'LA TUA',
            quando: 'non ancora salvata',
            tolta: c.laTogli ? 'La togli' : null,
            righe: [for (final r in righe) (r.etichetta, r.tua, r.diversa)],
          ).entra(context),
          const SizedBox(height: 12),
          _Versione(
            mia: false,
            chi: parole.diChi,
            quando: parole.quando,
            tolta: c.tolta ? 'Tolta' : null,
            righe: [for (final r in righe) (r.etichetta, r.loro, r.diversa)],
          ).entra(context, ritardo: Ritmo.passo),
          const SizedBox(height: 20),
          PulsanteGrande(
            etichetta: parole.tieniLaTua,
            pericolo: c.laTogli,
            inCorso: _inCorso == SceltaVersione.tua,
            motivo: scrive ?? contesto.nonEntra,
            onPressed: _inCorso == null
                ? () => _scegli(SceltaVersione.tua)
                : null,
          ),
          const SizedBox(height: 10),
          PulsanteGrande(
            etichetta: parole.tieniLaLoro,
            secondario: true,
            inCorso: _inCorso == SceltaVersione.loro,
            onPressed: _inCorso == null
                ? () => _scegli(SceltaVersione.loro)
                : null,
          ),
          if (c.possonoConvivere) ...[
            const SizedBox(height: 10),
            PulsanteGrande(
              etichetta: 'Tienile tutte e due',
              secondario: true,
              icona: icona(
                ios: CupertinoIcons.list_bullet,
                android: Icons.format_list_bulleted_rounded,
              ),
              inCorso: _inCorso == SceltaVersione.entrambe,
              motivo: scrive,
              onPressed: _inCorso == null
                  ? () => _scegli(SceltaVersione.entrambe)
                  : null,
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Text(
              parole.nota,
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una delle due versioni: una scheda bianca con chi e quando, e i campi.
class _Versione extends StatelessWidget {
  const _Versione({
    required this.mia,
    required this.chi,
    required this.quando,
    required this.tolta,
    required this.righe,
  });

  /// La propria: il bordo cobalto.
  final bool mia;
  final String chi;
  final String quando;

  /// Al posto dei campi, se la versione toglie la cosa.
  final String? tolta;

  /// Etichetta, valore, se è diverso nell'altra versione.
  final List<(String, String?, bool)> righe;

  @override
  Widget build(BuildContext context) {
    final tolta = this.tolta;
    return Semantics(
      container: true,
      label: mia ? 'La tua versione' : 'L\'altra versione',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(20),
          border: mia ? Border.all(color: Colori.cobalto, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chi,
                      style: Testi.sezione.copyWith(
                        color: mia ? Colori.cobalto : Colori.grafite,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      quando,
                      textAlign: TextAlign.right,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ),
                ],
              ),
            ),
            if (tolta != null)
              _Riga(etichetta: '', valore: tolta, diversa: true, tolta: true)
            else
              for (final (etichetta, valore, diversa) in righe)
                _Riga(etichetta: etichetta, valore: valore, diversa: diversa),
          ],
        ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({
    required this.etichetta,
    required this.valore,
    required this.diversa,
    this.tolta = false,
  });

  final String etichetta;
  final String? valore;
  final bool diversa;
  final bool tolta;

  @override
  Widget build(BuildContext context) {
    final testo = valore ?? '—';
    final stile = Testi.evidenza.copyWith(
      color: tolta
          ? Colori.pericolo
          : diversa
          ? Colori.cobaltoScuro
          : Colori.inchiostro,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colori.foschia, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            etichetta,
            style: Testi.secondario.copyWith(color: Colori.grafite),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: tolta ? Alignment.centerLeft : Alignment.centerRight,
              child: diversa
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tolta ? Colori.rosa : Colori.cobaltoChiaro,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        testo,
                        textAlign: TextAlign.right,
                        style: stile,
                      ),
                    )
                  : Text(testo, textAlign: TextAlign.right, style: stile),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le persone, i giorni e la capienza: letti dalla copia una volta.
class _Contesto {
  const _Contesto({
    required this.io,
    required this.nomi,
    required this.giorni,
    required this.nonEntra,
  });

  final String? io;
  final Map<String, String> nomi;
  final Map<String, DateTime> giorni;

  /// «Tu», «Marco».
  String? chi(String? id) => id == null
      ? null
      : id == io
      ? 'Tu'
      : nomi[id] ?? '?';

  /// Perché la propria tappa non si può tenere: non entra più nel giorno.
  final String? nonEntra;

  static Future<_Contesto> di(Servizi servizi, Conflitto c) async {
    final archivio = servizi.archivio;
    final nomi = await archivio.osservaNomi(c.viaggioId).first;
    final giorni = c.cosa == CosaInConflitto.tappa
        ? await archivio.osservaGiorni(c.viaggioId).first
        : const <Giorno>[];
    return _Contesto(
      io: archivio.io,
      nomi: nomi,
      giorni: {for (final g in giorni) g.id: g.finestra.data},
      nonEntra: c.cosa == CosaInConflitto.tappa
          ? _nonEntra(c, giorni, await archivio.osservaTappe(c.viaggioId).first)
          : null,
    );
  }

  /// La capienza è l'unica regola che rifiuta (04, regola 4): la propria
  /// versione era stata provata sul giorno com'era, e intanto può essersi
  /// riempito. Come nel foglio della tappa, una tappa che resta dov'è e non
  /// si allunga non si rifiuta.
  static String? _nonEntra(
    Conflitto c,
    List<Giorno> giorni,
    List<Tappa> tappe,
  ) {
    if (c.laTogli) return null;
    final giornoId = c.mia['giorno_id'];
    final durata = c.mia['durata_stimata_min']! as int;
    if (!c.tolta &&
        giornoId == c.loro['giorno_id'] &&
        durata <= (c.loro['durata_stimata_min']! as int)) {
      return null;
    }
    final giorno = giorni.where((g) => g.id == giornoId).firstOrNull;
    if (giorno == null) return 'Quel giorno non è più nel viaggio';
    final entra = entraNellaGiornata(
      capienza: giorno.finestra.capienza,
      durateMinuti: [
        for (final t in tappe)
          if (t.giornoId == giornoId && t.id != c.id) t.durataStimataMin,
      ],
      nuovaMinuti: durata,
    );
    return entra
        ? null
        : 'Non entra più in ${giornoBreve(giorno.finestra.data).toLowerCase()}';
  }
}

/// Una riga del confronto: lo stesso campo nelle due versioni.
typedef _RigaConfronto = ({
  String etichetta,
  String? tua,
  String? loro,
  bool diversa,
});

/// I campi da mostrare, in ordine: quelli che hanno un valore in almeno una
/// delle due versioni. Evidenziati quelli che cambiano.
List<_RigaConfronto> _righe(Conflitto c, _Contesto contesto) {
  final diversi = c.diversi;
  _RigaConfronto riga(
    String etichetta,
    Iterable<String> campi,
    String? Function(Map<String, Object?> v) valore,
  ) => (
    etichetta: etichetta,
    tua: valore(c.mia),
    loro: valore(c.loro),
    diversa: campi.any(diversi.contains),
  );
  final righe = switch (c.cosa) {
    CosaInConflitto.tappa => [
      riga('Titolo', ['titolo'], (v) => v['titolo'] as String?),
      riga('Tipo', ['tipo'], (v) {
        final tipo = TipoTappa.leggi(v['tipo'] as String?);
        return tipo == null ? null : nomeTipo(tipo);
      }),
      riga(
        'Durata',
        ['durata_stimata_min'],
        (v) => durataBreve(Duration(minutes: v['durata_stimata_min']! as int)),
      ),
      riga('Ora', ['ora_inizio'], (v) {
        final o = leggiOra(v['ora_inizio'] as String?);
        return o == null ? null : ora(o);
      }),
      riga('Dove', ['luogo_nome'], (v) => v['luogo_nome'] as String?),
      riga('Giorno', ['giorno_id'], (v) {
        final data = contesto.giorni[v['giorno_id']];
        return data == null ? null : giornoCorto(data);
      }),
    ],
    CosaInConflitto.spesa => [
      riga('Importo', [
        'importo',
        'valuta',
      ], (v) => scriviImporto(v['importo']! as int, v['valuta']! as String)),
      riga('Cosa', ['descrizione'], (v) => v['descrizione'] as String?),
      riga('Quando', ['data'], (v) {
        final data = leggiData(v['data'] as String?);
        return data == null ? null : dataBreve(data);
      }),
      riga('Ha pagato', [
        'pagante_id',
      ], (v) => contesto.chi(v['pagante_id'] as String?)),
      riga('Per chi', ['quote'], (v) {
        final quote = leggiQuote(v['quote']);
        if (quote.isEmpty) return null;
        final persone = quote.keys.toList();
        final totale = v['importo']! as int;
        return inPartiUguali(totale, quote)
            ? elenco([for (final p in persone) contesto.chi(p) ?? '?'])
            : [
                for (final p in persone)
                  '${contesto.chi(p)} '
                      '${scriviImporto(quote[p]!, v['valuta']! as String)}',
              ].join(' · ');
      }),
    ],
    CosaInConflitto.voce => [
      riga('Cosa', ['testo'], (v) => v['testo'] as String?),
      riga('Quante', ['quantita'], (v) => '${v['quantita']}'),
    ],
    CosaInConflitto.viaggio => [
      riga('Quando', [
        'stato',
        'periodo_approssimativo',
        'data_inizio',
        'data_fine',
      ], _quando),
      riga('Arrivo', ['ora_arrivo'], (v) {
        final o = leggiOra(v['ora_arrivo'] as String?);
        return o == null ? null : ora(o);
      }),
      riga('Partenza', ['ora_partenza'], (v) {
        final o = leggiOra(v['ora_partenza'] as String?);
        return o == null ? null : ora(o);
      }),
    ],
  };
  return [
    for (final r in righe)
      if (r.tua != null || r.loro != null) r,
  ];
}

/// Quando si parte, in una riga: le date, o l'idea con il suo periodo.
String _quando(Map<String, Object?> v) {
  final inizio = leggiData(v['data_inizio'] as String?);
  final fine = leggiData(v['data_fine'] as String?);
  if (inizio != null && fine != null) return intervalloDate(inizio, fine);
  if (v['stato'] == 'archiviato') return 'Idea in archivio';
  final periodo = Periodo.leggi(v['periodo_approssimativo'] as String?);
  return periodo == null
      ? 'Idea, senza periodo'
      : 'Idea · ${etichettaPeriodo(periodo, DateTime.now())}';
}

/// Le parole della schermata, che cambiano con la cosa, con chi ha scritto
/// l'altra versione e con quello che è successo.
class _Parole {
  _Parole(this.c, this.contesto);

  final Conflitto c;
  final _Contesto contesto;

  /// L'altra versione l'ha scritta la persona stessa, da un altro telefono.
  bool get _daMe => c.autoreId != null && c.autoreId == contesto.io;
  String? get _nome => _daMe ? null : contesto.nomi[c.autoreId];

  String get _questa => switch (c.cosa) {
    CosaInConflitto.viaggio => 'le date',
    CosaInConflitto.tappa => 'questa tappa',
    CosaInConflitto.spesa => 'questa spesa',
    CosaInConflitto.voce => 'questa voce',
  };

  /// «Marco ha cambiato questa tappa», «Hai cambiato questa tappa da un altro
  /// telefono», «Qualcuno ha cambiato questa tappa».
  String _chiHa(String fatto) {
    if (_daMe) return 'Hai $fatto da un altro telefono';
    return '${_nome ?? 'Qualcuno'} ha $fatto';
  }

  String get spiegazione {
    final mentre = _daMe ? 'qui' : 'tu';
    // Tappa, spesa e voce sono femminili; un viaggio non si toglie da qui.
    if (c.tolta) {
      return '${_chiHa('tolto $_questa')} mentre la cambiavi $mentre. Puoi '
          'rimetterla con la tua versione, o lasciarla tolta.';
    }
    if (c.laTogli) {
      return '${_chiHa('cambiato $_questa')} mentre la toglievi. Guarda com\'è '
          'adesso prima di toglierla.';
    }
    return switch (c.cosa) {
      CosaInConflitto.viaggio =>
        '${_chiHa('cambiato le date')} mentre le cambiavi $mentre. Scegli '
            'quali tenere: non le mescoliamo.',
      CosaInConflitto.tappa =>
        '${_chiHa('cambiato questa tappa')} mentre la cambiavi $mentre. '
            'Scegli quale tenere: non le mescoliamo.',
      CosaInConflitto.spesa =>
        '${_chiHa('cambiato questa spesa')} un attimo prima di te. Sui soldi '
            'non si indovina: scegli tu.',
      CosaInConflitto.voce =>
        '${_chiHa('riscritto questa voce')} mentre la riscrivevi $mentre. Due '
            'testi non si uniscono mai: scegline uno, o tienili come due voci.',
    };
  }

  /// L'intestazione dell'altra versione: «DI MARCO».
  String get diChi {
    if (_daMe) return 'DALL\'ALTRO TELEFONO';
    final nome = _nome;
    return nome == null ? 'GIÀ SALVATA' : 'DI ${nome.toUpperCase()}';
  }

  /// «salvata alle 18:42», «tolta il 3 ott, 18:42».
  String get quando {
    final fatto = c.tolta ? 'tolta' : 'salvata';
    final il = c.salvataIl?.toLocal();
    if (il == null) return 'già $fatto';
    final oggi = soloData(DateTime.now());
    final alle = ora(Duration(hours: il.hour, minutes: il.minute));
    return soloData(il) == oggi
        ? '$fatto alle $alle'
        : '$fatto il ${dataBreve(il)}, $alle';
  }

  String get tieniLaTua {
    if (c.tolta) return 'Rimettila con la tua';
    if (c.laTogli) return 'Toglila lo stesso';
    return 'Tieni la tua';
  }

  String get tieniLaLoro {
    if (c.tolta) return 'Lasciala tolta';
    if (_daMe) return 'Tieni l\'altra';
    final nome = _nome;
    return nome == null ? 'Tieni quella salvata' : 'Tieni quella di $nome';
  }

  String get nota {
    if (c.possonoConvivere) {
      return 'Con «tutte e due» la tua diventa una voce in più.';
    }
    if (c.cosa == CosaInConflitto.spesa) {
      return 'I conti del viaggio si rifanno con quella che scegli.';
    }
    return 'Finché non scegli, quello che hai scritto resta qui: non si perde '
        'niente.';
  }
}
