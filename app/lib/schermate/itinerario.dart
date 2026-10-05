import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/striscia.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../aspetto/tipi.dart';
import '../dati/archivio.dart';
import '../dati/coda.dart';
import '../dati/database.dart';
import '../dati/destinazioni.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/itinerario.dart';
import '../dominio/tappe.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_itinerario.dart';
import 'gesti_mappa.dart';
import 'gesti_tappa.dart';

/// Il nome del posto come lo legge l'assistente: `Porto, Portogallo`.
String? destinazioneDaChiedere(Viaggio v) {
  final d = v.destinazione;
  if (d == null) return null;
  return [
    d.nome,
    if (d.tipo != TipoDestinazione.paese) ?d.nomePaese,
  ].join(', ');
}

/// Come finisce il giro: quante tappe sono entrate.
typedef EsitoItinerario = int;

/// L'itinerario con un assistente (04-itinerario.md, "Genera itinerario";
/// tela, 24): si scelgono ritmo e gusti, si copia la richiesta, la si porta
/// sull'assistente che si usa già, e si torna a incollare la risposta.
///
/// Trolley non chiama nessun modello (regola 7). Preparare e copiare la
/// richiesta funziona senza rete; salvare la risposta la richiede.
class SchermataItinerario extends StatefulWidget {
  const SchermataItinerario({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  State<SchermataItinerario> createState() => _SchermataItinerarioState();
}

class _SchermataItinerarioState extends State<SchermataItinerario> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;
  late Stream<List<String>> _modelli;
  bool _avviata = false;

  var _ritmo = RitmoDelViaggio.equilibrato;
  final _interessi = <Interesse>{};
  final _altro = TextEditingController();
  final _origineCondividi = GlobalKey();

  /// La richiesta è uscita: il prossimo passo è incollare la risposta.
  bool _copiata = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
    _giorni = archivio.osservaGiorni(widget.viaggioId);
    _tappe = archivio.osservaTappe(widget.viaggioId);
    _modelli = archivio.osservaModelliSuggeriti();
  }

  @override
  void dispose() {
    _altro.dispose();
    super.dispose();
  }

  String _richiesta(Viaggio v, List<Giorno> giorni, List<Tappa> tappe) =>
      scriviRichiesta(
        Richiesta(
          destinazione: destinazioneDaChiedere(v) ?? titoloViaggio(v),
          giorni: [
            for (final g in giorni)
              GiornoDaChiedere(
                g.finestra,
                presenti: [
                  for (final t in tappe)
                    if (t.giornoId == g.id)
                      (titolo: t.titolo, durata: t.durata),
                ],
              ),
          ],
          ritmo: _ritmo,
          interessi: _interessi,
          altro: _altro.text,
        ),
      );

  Future<void> _esporta(
    Viaggio v,
    List<Giorno> giorni,
    List<Tappa> tappe, {
    bool condividi = false,
  }) async {
    final box =
        _origineCondividi.currentContext?.findRenderObject() as RenderBox?;
    final uscita = await esportaLaRichiesta(
      context,
      viaggio: v,
      richiesta: _richiesta(v, giorni, tappe),
      condividi: condividi,
      origine: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    // Lo dicono i passaggi che avanzano e il pulsante: un messaggio in basso
    // coprirebbe proprio «Ho la risposta».
    if (uscita && mounted) setState(() => _copiata = true);
  }

  /// Incolla e legge la risposta; poi l'anteprima, o il «non capito».
  Future<void> _incolla(
    Viaggio v,
    List<Giorno> giorni,
    List<Tappa> tappe,
  ) async {
    final risultato = await apriFoglio<(Nota, ItinerarioLetto)>(
      context,
      FoglioRisposta(viaggio: v),
    );
    if (risultato == null || !mounted) return;
    final (_, letto) = risultato;
    if (letto.vuoto) {
      final scelta = await apri<_DopoNonCapito>(
        context,
        SchermataNonCapito(viaggio: v),
      );
      if (!mounted) return;
      switch (scelta) {
        case _DopoNonCapito.incolla:
          await _incolla(v, giorni, tappe);
        case _DopoNonCapito.copia:
          await _esporta(v, giorni, tappe);
        case null:
          break;
      }
      return;
    }
    final aggiunte = await apri<EsitoItinerario>(
      context,
      SchermataAnteprima(viaggioId: v.id, letto: letto),
    );
    if (aggiunte != null && mounted) Navigator.of(context).pop(aggiunte);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: _tappe,
        builder: (context, tappe) => StreamBuilder<List<String>>(
          stream: _modelli,
          builder: (context, modelli) {
            final (v, g, t) = (viaggio.data, giorni.data, tappe.data);
            if (v == null || g == null || t == null) {
              return const Pagina(corpo: Center(child: IndicatoreAttivita()));
            }
            return _pagina(v, g, t, modelli.data ?? const []);
          },
        ),
      ),
    ),
  );

  Widget _pagina(
    Viaggio v,
    List<Giorno> giorni,
    List<Tappa> tappe,
    List<String> modelli,
  ) {
    final (inizio, fine) = (v.inizio, v.fine);
    final sotto = [
      titoloViaggio(v),
      if (inizio != null && fine != null) intervalloDate(inizio, fine),
      quanti(giorni.length, 'giorno', 'giorni'),
    ].join(' · ');
    return Pagina(
      azioni: [
        PulsanteTondo(
          key: _origineCondividi,
          icona: icona(
            ios: CupertinoIcons.share,
            android: Icons.share_outlined,
          ),
          etichetta: 'Condividi la richiesta',
          onPressed: giorni.isEmpty
              ? null
              : () => _esporta(v, giorni, tappe, condividi: true),
        ),
      ],
      inBasso: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsanteGrande(
            etichetta: _copiata
                ? 'Copiata · copia di nuovo'
                : 'Copia la richiesta',
            icona: icona(
              ios: CupertinoIcons.doc_on_doc,
              android: Icons.copy_rounded,
            ),
            secondario: _copiata,
            onPressed: giorni.isEmpty ? null : () => _esporta(v, giorni, tappe),
          ),
          const SizedBox(height: 10),
          PulsanteGrande(
            etichetta: 'Ho la risposta',
            secondario: !_copiata,
            onPressed: () => _incolla(v, giorni, tappe),
          ),
        ],
      ),
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 160,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'L\'itinerario con il tuo assistente',
                      style: Testi.titoloFoglio.copyWith(
                        color: Colori.inchiostro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sotto,
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            const SizedBox(height: 14),
            _Passi(attivo: _copiata ? 3 : 1)
                .entra(context, ritardo: Ritmo.passo),
            const SizedBox(height: 18),
            _etichetta('Che ritmo?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in RitmoDelViaggio.values)
                  Gettone(
                    etichetta: r.nome,
                    scelto: r == _ritmo,
                    onTap: () => setState(() => _ritmo = r),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _etichetta('Cosa vi piace? · facoltativo'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in Interesse.values)
                  Gettone(
                    etichetta: i.nome,
                    scelto: _interessi.contains(i),
                    onTap: () => setState(
                      () => _interessi.contains(i)
                          ? _interessi.remove(i)
                          : _interessi.add(i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Campo(
              controller: _altro,
              etichetta: 'Altro da dire · facoltativo',
              segnaposto: 'Niente salite, un pomeriggio al mare…',
              maiuscole: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            _ConsigliModelli(modelli: modelli),
          ],
        ),
      ),
    );
  }

  Widget _etichetta(String testo) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(testo, style: Testi.etichetta.copyWith(color: Colori.ardesia)),
  );
}

/// I tre passaggi come un percorso di punti (tela, 24): fatto, adesso, dopo.
class _Passi extends StatelessWidget {
  const _Passi({required this.attivo});

  final int attivo;

  static const _nomi = [
    'Copia la richiesta',
    'Incollala nel tuo assistente',
    'Incolla qui la risposta',
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Passaggio $attivo di 3: ${_nomi[attivo - 1]}',
    container: true,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            for (final (i, nome) in _nomi.indexed) ...[
              if (i > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 13),
                    width: 2,
                    height: 10,
                    color: Colori.piombo,
                  ),
                ),
              Row(
                children: [
                  _Punto(numero: i + 1, attivo: attivo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nome,
                      style: Testi.secondario.copyWith(
                        color: i + 1 < attivo
                            ? Colori.grafite
                            : Colori.inchiostro,
                        fontWeight: i + 1 == attivo
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Punto extends StatelessWidget {
  const _Punto({required this.numero, required this.attivo});

  final int numero;
  final int attivo;

  @override
  Widget build(BuildContext context) {
    final fatto = numero < attivo;
    final adesso = numero == attivo;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fatto
            ? Colori.verde
            : adesso
            ? Colori.cobalto
            : Colori.bianco,
        border: fatto || adesso
            ? null
            : Border.all(color: Colori.inchiostro, width: 2.5),
        boxShadow: adesso
            ? [
                BoxShadow(
                  color: Colori.cobalto.withValues(alpha: 0.16),
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: fatto
          ? const Icon(Icons.check_rounded, size: 16, color: Colori.bianco)
          : Text(
              '$numero',
              style: Testi.titoli(
                12,
                spaziatura: 0,
                altezza: 1,
                peso: 600,
              ).copyWith(color: adesso ? Colori.bianco : Colori.inchiostro),
            ),
    );
  }
}

/// Con quali modelli funziona meglio (regola 12), dalla configurazione del
/// server, e l'avviso che la risposta la scrive un servizio di terzi (regola
/// 13).
class _ConsigliModelli extends StatelessWidget {
  const _ConsigliModelli({required this.modelli});

  final List<String> modelli;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modelli.isNotEmpty) ...[
          Text(
            'Funziona meglio con',
            style: Testi.didascalia.copyWith(
              color: Colori.inchiostro,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            modelli.join(' · '),
            style: Testi.didascalia.copyWith(color: Colori.ardesia),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          'La risposta la scrive un servizio di terzi: Trolley non ne '
          'risponde. Quello che aggiungi si cambia come ogni altra tappa.',
          style: Testi.didascalia.copyWith(color: Colori.grafite),
        ),
      ],
    ),
  );
}

/// Dove si incolla la risposta (tela, 25). Il testo lo incolla la persona: col
/// pulsante o tenendo premuto il campo; l'app non legge gli appunti da sola
/// (regola 9). Leggere salva prima la nota, quindi richiede la rete.
class FoglioRisposta extends StatelessWidget {
  const FoglioRisposta({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) => _Risposta(viaggio: viaggio, rete: rete),
  );
}

class _Risposta extends StatefulWidget {
  const _Risposta({required this.viaggio, required this.rete});

  final Viaggio viaggio;
  final bool rete;

  @override
  State<_Risposta> createState() => _RispostaState();
}

class _RispostaState extends State<_Risposta> {
  final _testo = TextEditingController();
  final _fuoco = FocusNode();
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    _testo.addListener(() => setState(() {}));
    _fuoco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _testo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  String? get _motivo {
    if (_testo.text.trim().isEmpty) {
      return 'Incolla la risposta dell\'assistente';
    }
    if (_testo.text.trim().length > lunghezzaMassimaNota) {
      return 'È troppo lungo: incolla solo l\'itinerario';
    }
    if (!widget.rete) return motivoSenzaRete;
    return null;
  }

  Future<void> _incollaDagliAppunti() async {
    final dati = await Clipboard.getData(Clipboard.kTextPlain);
    final testo = dati?.text;
    if (testo == null || testo.trim().isEmpty) {
      if (mounted) {
        mostraMessaggio(context, 'Negli appunti non c\'è testo da incollare.');
      }
      return;
    }
    _testo.text = testo;
  }

  Future<void> _leggi() async {
    setState(() => _inCorso = true);
    try {
      final risultato = await leggiLaRisposta(
        context,
        viaggio: widget.viaggio,
        testo: _testo.text,
      );
      if (mounted) Navigator.of(context).pop(risultato);
    } on ErroreTrolley catch (e) {
      // Il testo resta nel campo: si riprova senza rifare il giro.
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _motivo;
    final stile = const TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: ['Courier', 'monospace'],
      fontSize: 13,
      height: 1.5,
    ).copyWith(color: Colori.inchiostro);
    final attivo = _fuoco.hasFocus;
    final forma = BoxDecoration(
      color: attivo ? Colori.bianco : Colori.foschia,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: attivo ? Colori.cobalto : Colori.foschia,
        width: 2,
      ),
    );
    final campo = suIOS
        ? CupertinoTextField(
            controller: _testo,
            focusNode: _fuoco,
            minLines: 8,
            maxLines: 12,
            style: stile,
            placeholder: 'Incolla qui la risposta',
            placeholderStyle: Testi.campo.copyWith(
              color: Colori.grafite.withValues(alpha: 0.6),
            ),
            cursorColor: Colori.cobalto,
            padding: const EdgeInsets.all(14),
            decoration: forma,
            keyboardType: TextInputType.multiline,
          )
        : DecoratedBox(
            decoration: forma,
            child: TextField(
              controller: _testo,
              focusNode: _fuoco,
              minLines: 8,
              maxLines: 12,
              style: stile,
              cursorColor: Colori.cobalto,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Incolla qui la risposta',
                hintStyle: Testi.campo.copyWith(
                  color: Colori.grafite.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          );
    return Foglio(
      titolo: 'La risposta',
      inBasso: AzioniFoglio(
        motivo: motivo,
        azione: PulsanteGrande(
          etichetta: 'Leggi',
          inCorso: _inCorso,
          onPressed: motivo == null ? _leggi : null,
        ),
      ),
      children: [
        Text(
          'Nell\'assistente tocca «Copia» sul blocco dell\'itinerario, poi '
          'torna qui.',
          style: Testi.secondario.copyWith(color: Colori.ardesia),
        ),
        const SizedBox(height: 12),
        Semantics(label: 'La risposta dell\'assistente', child: campo),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PulsantePiccolo(
              etichetta: 'Incolla',
              onPressed: _incollaDagliAppunti,
            ),
            if (_testo.text.isNotEmpty)
              PulsantePiccolo(etichetta: 'Svuota', onPressed: _testo.clear),
          ],
        ),
        const SizedBox(height: 14),
        Avviso(
          fondo: Colori.foschia,
          icona: icona(
            ios: CupertinoIcons.doc_text,
            android: Icons.description_outlined,
          ),
          testo:
              'Il testo si salva fra le note del viaggio, anche se non riesco '
              'a leggerlo: non dovrai rifare il giro.',
        ),
      ],
    );
  }
}

/// Che cosa fare dopo una risposta che non si è capita.
enum _DopoNonCapito { incolla, copia }

/// Una risposta senza tappe leggibili (tela, 27): il testo è salvo, si dice
/// cosa si cercava e si propone di riprovare. Mai una schermata d'errore che
/// non lascia niente (04, casi limite).
class SchermataNonCapito extends StatelessWidget {
  const SchermataNonCapito({super.key, required this.viaggio});

  final Viaggio viaggio;

  @override
  Widget build(BuildContext context) {
    final (inizio, fine) = (viaggio.inizio, viaggio.fine);
    final sotto = [
      titoloViaggio(viaggio),
      if (inizio != null && fine != null) intervalloDate(inizio, fine),
    ].join(' · ');
    return Pagina(
      inBasso: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsanteGrande(
            etichetta: 'Incolla un\'altra risposta',
            onPressed: () => Navigator.of(context).pop(_DopoNonCapito.incolla),
          ),
          const SizedBox(height: 10),
          PulsanteGrande(
            etichetta: 'Copia di nuovo la richiesta',
            secondario: true,
            icona: icona(
              ios: CupertinoIcons.doc_on_doc,
              android: Icons.copy_rounded,
            ),
            onPressed: () => Navigator.of(context).pop(_DopoNonCapito.copia),
          ),
        ],
      ),
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 160,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Non ho trovato tappe',
                      style: Testi.titoloFoglio.copyWith(
                        color: Colori.inchiostro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sotto,
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            const SizedBox(height: 16),
            Avviso(
              icona: Icons.check_rounded,
              colore: Colori.verde,
              inizio: 'Il testo è salvo.',
              testo:
                  'L\'ho messo fra le note del viaggio: lo ritrovi lì, e puoi '
                  'riprovare quando vuoi.',
            ).entra(context, ritardo: Ritmo.passo),
            const SizedBox(height: 12),
            Pannello(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cosa cerco',
                    style: Testi.secondario.copyWith(
                      color: Colori.inchiostro,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Un giorno per riga, poi le sue tappe, così:',
                    style: Testi.secondario.copyWith(color: Colori.ardesia),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colori.foschia,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'GIORNO 1 · 2026-10-10\n10:30 | Livraria Lello | visita | 60',
                      style: TextStyle(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: ['Courier', 'monospace'],
                        fontSize: 12,
                        height: 1.5,
                        color: Colori.inchiostro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Succede quando l\'assistente risponde a parole: chiedigli '
                    'di rimettere l\'itinerario nel blocco, come diceva la '
                    'richiesta.',
                    style: Testi.secondario.copyWith(color: Colori.ardesia),
                  ),
                ],
              ),
            ).entra(context, ritardo: Ritmo.passo * 2),
          ],
        ),
      ),
    );
  }
}

/// Quello che si è trovato, giorno per giorno, prima di aggiungerlo (tela,
/// 26). Le tappe entrano come tutte le altre, capienza compresa (regola 14):
/// all'inizio sono scelte nell'ordine finché entrano, le altre restano fuori e
/// lo dicono; si scelgono e si lasciano fuori con un tocco. Una giornata che
/// sfora non si aggiunge.
///
/// Aggiungere tappe è uno dei gesti senza rete: qui la rete non serve.
class SchermataAnteprima extends StatefulWidget {
  const SchermataAnteprima({
    super.key,
    required this.viaggioId,
    required this.letto,
  });

  final String viaggioId;
  final ItinerarioLetto letto;

  @override
  State<SchermataAnteprima> createState() => _SchermataAnteprimaState();
}

class _SchermataAnteprimaState extends State<SchermataAnteprima> {
  late Stream<Viaggio?> _viaggio;
  late Stream<List<Giorno>> _giorni;
  late Stream<List<Tappa>> _tappe;
  bool _avviata = false;
  bool _inCorso = false;

  /// Per giorno del viaggio, le proposte scelte. Si decide la prima volta che
  /// arrivano i giorni, poi lo decide la persona.
  List<Set<int>>? _scelte;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviata) return;
    _avviata = true;
    final archivio = Servizi.of(context).archivio;
    _viaggio = archivio.osservaViaggio(widget.viaggioId);
    _giorni = archivio.osservaGiorni(widget.viaggioId);
    _tappe = archivio.osservaTappe(widget.viaggioId);
  }

  Duration _libero(Giorno g, List<Tappa> tappe) => tempoLibero(
    capienza: g.finestra.capienza,
    durateMinuti: [
      for (final t in tappe)
        if (t.giornoId == g.id) t.durataStimataMin,
    ],
  );

  /// Per giorno del viaggio, le proposte che ci sono già: non si scelgono.
  List<Set<int>> _doppioni(
    ItinerarioAbbinato abbinato,
    List<Giorno> giorni,
    List<Tappa> tappe,
  ) => [
    for (final (i, g) in giorni.indexed)
      giaNelGiorno(abbinato.perGiorno[i], [
        for (final t in tappe)
          if (t.giornoId == g.id) t.titolo,
      ]),
  ];

  List<Set<int>> _sceltePrime(
    ItinerarioAbbinato abbinato,
    List<Giorno> giorni,
    List<Tappa> tappe,
    List<Set<int>> doppioni,
  ) => [
    for (final (i, g) in giorni.indexed)
      sceltePerCapienza(
        libero: _libero(g, tappe),
        durate: [for (final p in abbinato.perGiorno[i]) p.durata],
        escluse: doppioni[i],
      ),
  ];

  Future<void> _aggiungi(
    Viaggio viaggio,
    List<Giorno> giorni,
    List<Tappa> tappe,
    ItinerarioAbbinato abbinato,
    List<Set<int>> scelte,
  ) async {
    setState(() => _inCorso = true);
    // Le coordinate dell'assistente sono una stima: valgono solo vicino al
    // viaggio, se no la tappa entra senza posto e lo si cerca in «Dove?».
    final centro = (await centroDelViaggio(viaggio, tappe))?.centro;
    final doppioni = _doppioni(abbinato, giorni, tappe);
    if (!mounted) return;
    final nuove = <NuovaTappa>[];
    for (final (i, g) in giorni.indexed) {
      var ordine = ordineInFondo([
        for (final t in tappe)
          if (t.giornoId == g.id) t.ordine,
      ]);
      for (final (j, p) in abbinato.perGiorno[i].indexed) {
        if (!scelte[i].contains(j) || doppioni[i].contains(j)) continue;
        final posto = p.posto;
        nuove.add(
          NuovaTappa(
            id: const Uuid().v4(),
            viaggioId: viaggio.id,
            giornoId: g.id,
            ordine: ordine++,
            titolo: p.titolo,
            tipo: p.tipo,
            durata: p.durata,
            ora: p.ora,
            luogo: p.luogo,
            posto: posto != null && postoPlausibile(posto, vicinoA: centro)
                ? posto
                : null,
          ),
        );
      }
    }
    await aggiungiLeTappe(context, viaggio: viaggio, tappe: nuove);
    if (mounted) Navigator.of(context).pop<EsitoItinerario>(nuove.length);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Viaggio?>(
    stream: _viaggio,
    builder: (context, viaggio) => StreamBuilder<List<Giorno>>(
      stream: _giorni,
      builder: (context, giorni) => StreamBuilder<List<Tappa>>(
        stream: _tappe,
        builder: (context, tappe) {
          final (v, g, t) = (viaggio.data, giorni.data, tappe.data);
          if (v == null || g == null || t == null) {
            return const Pagina(corpo: Center(child: IndicatoreAttivita()));
          }
          final abbinato = abbinaAiGiorni(widget.letto, [
            for (final x in g) x.finestra.data,
          ]);
          final doppioni = _doppioni(abbinato, g, t);
          final scelte = _scelte ??= _sceltePrime(abbinato, g, t, doppioni);
          return _pagina(v, g, t, abbinato, scelte, doppioni);
        },
      ),
    ),
  );

  Widget _pagina(
    Viaggio viaggio,
    List<Giorno> giorni,
    List<Tappa> tappe,
    ItinerarioAbbinato abbinato,
    List<Set<int>> scelte,
    List<Set<int>> doppioni,
  ) {
    final letto = widget.letto;
    // Una proposta che intanto è entrata nel viaggio non resta scelta.
    for (final (i, d) in doppioni.indexed) {
      scelte[i].removeAll(d);
    }
    final quanteScelte = scelte.fold(0, (n, s) => n + s.length);
    final giaCi = doppioni.fold(0, (n, d) => n + d.length);
    final conPosto = abbinato.perGiorno
        .expand((p) => p)
        .where((p) => p.posto != null)
        .length;
    final giorniConProposte = abbinato.perGiorno
        .where((p) => p.isNotEmpty)
        .length;
    final trovate = letto.tappe - abbinato.fuoriDalViaggio;
    final sotto = [
      '${quanti(trovate, 'tappa', 'tappe')} in '
          '${quanti(giorniConProposte, 'giorno', 'giorni')}',
      if (letto.righeNonCapite > 0)
        '${quanti(letto.righeNonCapite, 'riga non capita', 'righe non capite')}, '
            'restano nella nota',
      if (abbinato.fuoriDalViaggio > 0)
        '${quanti(abbinato.fuoriDalViaggio, 'tappa', 'tappe')} di giorni che il '
            'viaggio non ha',
      if (giaCi > 0)
        giaCi == 1
            ? '1 c\'è già, non si aggiunge di nuovo'
            : '$giaCi ci sono già, non si aggiungono di nuovo',
      if (conPosto > 0) '$conPosto con il posto sulla mappa',
    ].join(' · ');
    // Il primo giorno che sfora, per dirlo sotto il pulsante.
    String? sfora;
    for (final (i, g) in giorni.indexed) {
      final scelteMinuti = [
        for (final j in scelte[i]) abbinato.perGiorno[i][j].durata.inMinutes,
      ];
      final resta =
          _libero(g, tappe) -
          Duration(minutes: scelteMinuti.fold(0, (a, b) => a + b));
      if (resta.isNegative && scelteMinuti.isNotEmpty) {
        sfora =
            '${conMaiuscola(giornoDellaSettimana(g.finestra.data))} '
            '${g.finestra.data.day} sfora di ${durataBreve(-resta)}: lasciane '
            'fuori qualcuna';
        break;
      }
    }
    final diverso = altraDestinazione(letto.destinazione, [
      viaggio.destinazioneCitta,
      viaggio.destinazione?.nomePaese,
      viaggio.destinazionePaese,
    ]);
    return Pagina(
      inBasso: PulsanteGrande(
        etichetta: quanteScelte == 1
            ? 'Aggiungi 1 tappa'
            : 'Aggiungi $quanteScelte tappe',
        icona: Icons.add_rounded,
        inCorso: _inCorso,
        motivo: quanteScelte == 0 ? 'Scegline almeno una' : sfora,
        onPressed: () => _aggiungi(viaggio, giorni, tappe, abbinato, scelte),
      ),
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 120,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Cosa ho trovato',
                      style: Testi.titoloFoglio.copyWith(
                        color: Colori.inchiostro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sotto,
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            if (diverso) ...[
              const SizedBox(height: 14),
              Avviso(
                errore: true,
                icona: icona(
                  ios: CupertinoIcons.exclamationmark_triangle,
                  android: Icons.warning_amber_rounded,
                ),
                inizio: 'Parla di ${letto.destinazione}.',
                testo:
                    'Il viaggio è a ${titoloViaggio(viaggio)}: forse è la '
                    'risposta a una richiesta vecchia. Controlla prima di '
                    'aggiungere.',
              ),
            ],
            for (final (i, g) in giorni.indexed)
              if (abbinato.perGiorno[i].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _GiornoProposto(
                    giorno: g,
                    esistenti: [
                      for (final t in tappe)
                        if (t.giornoId == g.id) t,
                    ],
                    proposte: abbinato.perGiorno[i],
                    scelte: scelte[i],
                    doppioni: doppioni[i],
                    libero: _libero(g, tappe),
                    onCambia: (j) => setState(
                      () => scelte[i].contains(j)
                          ? scelte[i].remove(j)
                          : scelte[i].add(j),
                    ),
                  ).entra(context, ritardo: Ritmo.passo * (i + 1)),
                ),
          ],
        ),
      ),
    );
  }
}

/// Un giorno dell'anteprima (tela, 26): quando, la striscia con le tappe che
/// ci sono e quelle scelte (tratteggiate, perché non ci sono ancora), e le
/// proposte da scegliere o lasciare fuori.
class _GiornoProposto extends StatelessWidget {
  const _GiornoProposto({
    required this.giorno,
    required this.esistenti,
    required this.proposte,
    required this.scelte,
    required this.doppioni,
    required this.libero,
    required this.onCambia,
  });

  final Giorno giorno;
  final List<Tappa> esistenti;
  final List<TappaProposta> proposte;
  final Set<int> scelte;

  /// Quelle che ci sono già: non si possono scegliere.
  final Set<int> doppioni;
  final Duration libero;
  final ValueChanged<int> onCambia;

  @override
  Widget build(BuildContext context) {
    final f = giorno.finestra;
    final occupato = Duration(
      minutes: [for (final j in scelte) proposte[j].durata.inMinutes]
          .fold(0, (a, b) => a + b),
    );
    final resta = libero - occupato;
    final titolo = '${giornoDellaSettimana(f.data)} ${f.data.day}'
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titolo,
                  style: Testi.sezione.copyWith(color: Colori.cobalto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  finestraDelGiorno(f),
                  textAlign: TextAlign.right,
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StrisciaGiornata(
            capienza: f.capienza,
            pezzi: [
              for (final t in esistenti)
                PezzoStriscia(t.durata, coloreTipo(t.tipoTappa)),
              for (final j in scelte.toList()..sort())
                PezzoStriscia(
                  proposte[j].durata,
                  coloreTipo(proposte[j].tipo),
                  tratteggiato: true,
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final (j, p) in proposte.indexed)
            _Proposta(
              proposta: p,
              scelta: scelte.contains(j),
              giaCe: doppioni.contains(j),
              // Fuori, e senza posto: lo si dice prima che la si tocchi.
              nonEntra:
                  !scelte.contains(j) &&
                      !doppioni.contains(j) &&
                      p.durata > resta
                  ? p.durata - (resta.isNegative ? Duration.zero : resta)
                  : null,
              onTap: doppioni.contains(j) ? null : () => onCambia(j),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              resta.isNegative
                  ? 'Sfora di ${durataBreve(-resta)}: lasciane fuori qualcuna.'
                  : 'Restano ${durataBreve(resta)}.',
              style: Testi.didascalia.copyWith(
                color: resta.isNegative ? Colori.pericolo : Colori.grafite,
                fontWeight: resta.isNegative ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Proposta extends StatelessWidget {
  const _Proposta({
    required this.proposta,
    required this.scelta,
    required this.nonEntra,
    required this.onTap,
    this.giaCe = false,
  });

  final TappaProposta proposta;
  final bool scelta;

  /// C'è già nel giorno: si mostra, ma non si aggiunge di nuovo.
  final bool giaCe;

  /// Quanto manca perché entri, se è fuori e non ci sta.
  final Duration? nonEntra;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = proposta;
    final dettaglio = [
      if (p.tipo != null) nomeTipo(p.tipo!),
      durataBreve(p.durata),
      ?p.luogo,
    ].join(' · ');
    return Semantics(
      checked: scelta,
      child: Premibile(
        onTap: onTap,
        scala: 0.98,
        etichetta: [
          ?(p.ora == null ? null : ora(p.ora!)),
          p.titolo,
          dettaglio,
          giaCe
              ? 'c\'è già in questo giorno'
              : scelta
              ? 'scelta. Tocca per lasciarla fuori'
              : 'lasciata fuori. Tocca per sceglierla',
        ].join(', '),
        child: ExcludeSemantics(
          child: Opacity(
            opacity: giaCe ? 0.5 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: movimentoRidotto(context)
                        ? Duration.zero
                        : Ritmo.breve,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scelta ? Colori.cobalto : Colori.bianco,
                      border: scelta
                          ? null
                          : Border.all(color: Colori.piombo, width: 2.5),
                    ),
                    child: scelta
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colori.bianco,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      p.ora == null ? '' : ora(p.ora!),
                      style: Testi.numero.copyWith(
                        fontSize: 13,
                        color: scelta ? Colori.inchiostro : Colori.piombo,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.titolo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.evidenza.copyWith(
                            fontSize: 15,
                            color: scelta ? Colori.inchiostro : Colori.grafite,
                          ),
                        ),
                        Text(
                          giaCe
                              ? 'C\'è già in questo giorno'
                              : nonEntra == null
                              ? dettaglio
                              : 'Non entra: ne mancano ${durataBreve(nonEntra!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.didascalia.copyWith(
                            color: nonEntra == null
                                ? Colori.grafite
                                : Colori.pericolo,
                            fontWeight: nonEntra == null
                                ? null
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'ingresso nella schermata del viaggio (tela, 28), sotto i giorni.
class IngressoItinerario extends StatelessWidget {
  const IngressoItinerario({super.key, required this.viaggio});

  final Viaggio viaggio;

  Future<void> _apri(BuildContext context) async {
    final aggiunte = await apri<EsitoItinerario>(
      context,
      SchermataItinerario(viaggioId: viaggio.id),
    );
    if (aggiunte != null && context.mounted) {
      mostraMessaggio(
        context,
        aggiunte == 1
            ? 'Aggiunta una tappa: la trovi nella sua giornata.'
            : 'Aggiunte $aggiunte tappe: le trovi nelle loro giornate.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: () => _apri(context),
    scala: 0.98,
    etichetta: 'Un itinerario con il tuo assistente',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colori.cobaltoChiaro,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colori.cobalto,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Colori.bianco,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Un itinerario con il tuo assistente',
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  Text(
                    'Prepari la richiesta qui, la porti dove vuoi, incolli la '
                    'risposta',
                    style: Testi.didascalia.copyWith(color: Colori.ardesia),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icona(
                ios: CupertinoIcons.chevron_right,
                android: Icons.chevron_right,
              ),
              size: 16,
              color: Colori.cobaltoScuro,
            ),
          ],
        ),
      ),
    ),
  );
}
