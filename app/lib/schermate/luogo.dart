import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dati/mappe.dart';
import '../dominio/mappa.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'gesti_mappa.dart';

/// Come dire dove sta una tappa senza rete: quello che la persona ha
/// scritto; per un posto di Google, che è sulla mappa. Il nome e
/// l'indirizzo di Google non si tengono, e si chiedono con la rete
/// (ADR-014).
String? doveDellaTappa(String? luogoNome, String? placeId) {
  final scritto = luogoNome?.trim();
  if (scritto != null && scritto.isNotEmpty) return scritto;
  return placeId == null ? null : postoSullaMappa;
}

/// Un posto di Google, senza il suo nome.
const postoSullaMappa = 'Sulla mappa';

/// Il posto scelto per una tappa: scritto a mano, o trovato con Google.
class SceltaLuogo {
  const SceltaLuogo({
    required this.testo,
    this.posto,
    this.google,
    this.etichetta,
  });

  /// Un posto scritto a mano: il testo com'è.
  const SceltaLuogo.aMano(this.testo)
    : posto = null,
      google = null,
      etichetta = null;

  /// Cosa va in `luogo_nome`: quello che la persona ha scritto. Per un posto
  /// di Google è vuoto: il nome e l'indirizzo di Google non si tengono
  /// (ADR-014).
  final String testo;

  /// Dove sta. `null` se si è usato il testo com'è: la tappa resta senza
  /// posto, e lo si cerca dopo (ADR-005).
  final Coordinate? posto;

  /// Il `place_id` di Google: si tiene per sempre, le coordinate 30 giorni.
  final String? google;

  /// Il nome e l'indirizzo di Google, da mostrare finché il foglio della
  /// tappa è aperto. Non si salva.
  final String? etichetta;

  /// Se è un posto di Google: allora va salvato con la data delle coordinate.
  bool get daGoogle => google != null && posto != null;
}

/// «Dove?» (tela, 56 e 165): il posto di una tappa, cercato con Google vicino
/// alla meta del viaggio o alle sue tappe (ADR-014). È un elenco, senza
/// mappa: il nome e l'indirizzo di Google non stanno su una mappa, e non si
/// tengono. La ricerca ha bisogno della rete; senza, il posto si scrive com'è
/// e si cerca quando torna. Una tappa non si rifiuta mai perché manca un
/// posto.
///
/// Chiudendo restituisce una [SceltaLuogo], o `null` se la persona ci ripensa.
class FoglioLuogo extends StatefulWidget {
  const FoglioLuogo({
    super.key,
    required this.viaggioId,
    this.iniziale,
    this.vicinoA,
    this.dalleTappe = false,
    this.cercaSubito = false,
  });

  final String viaggioId;

  /// Quello che c'era già scritto.
  final String? iniziale;

  /// Dove cercare prima.
  final Coordinate? vicinoA;

  /// [vicinoA] è il centro delle tappe del viaggio, non la sua meta.
  final bool dalleTappe;

  /// Cerca [iniziale] appena si apre: un posto scritto a mano, o arrivato
  /// da un itinerario incollato, che non è ancora sulla mappa.
  final bool cercaSubito;

  /// Quanti caratteri prima di cercare: ogni ricerca si paga (ADR-006).
  static const caratteriMinimi = 3;

  /// Quanto aspettare dopo l'ultimo tasto: si cerca quando si smette di
  /// scrivere, non a ogni lettera.
  static const attesa = Duration(milliseconds: 400);

  @override
  State<FoglioLuogo> createState() => _FoglioLuogoState();
}

class _FoglioLuogoState extends State<FoglioLuogo> {
  late final _testo = TextEditingController(text: widget.iniziale);
  Timer? _attesa;
  List<Luogo>? _trovati;
  String? _errore;
  bool _cerca = false;

  /// Il posto scelto, mentre si chiede a Google dove sta.
  String? _scelto;

  /// Una sessione di Google per foglio: i suggerimenti e il posto scelto
  /// sono una ricerca sola. Dopo la scelta se ne comincia un'altra.
  String _sessione = const Uuid().v4();

  /// Le risposte arrivano in disordine: vale solo l'ultima chiesta.
  int _ultima = 0;

  late Servizi _servizi;

  /// Quanto si era chiesto al fornitore quando il foglio si è aperto.
  late ConsumoMappe _prima;
  bool _avviato = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    _servizi = Servizi.of(context);
    _prima = _servizi.mappe.consumo;
    if (widget.cercaSubito &&
        _testo.text.trim().length >= FoglioLuogo.caratteriMinimi) {
      unawaited(_cercaAdesso());
    }
  }

  @override
  void dispose() {
    _attesa?.cancel();
    _testo.dispose();
    unawaited(
      registraConsumo(
        _servizi.misurazione,
        _servizi.mappe,
        viaggioId: widget.viaggioId,
        prima: _prima,
      ),
    );
    super.dispose();
  }

  bool get _puoCercare =>
      _servizi.rete.disponibile && _servizi.mappe.disponibili;

  void _cambiato(String _) {
    _attesa?.cancel();
    setState(() => _errore = null);
    if (_testo.text.trim().length < FoglioLuogo.caratteriMinimi) {
      setState(() => _trovati = null);
      return;
    }
    _attesa = Timer(FoglioLuogo.attesa, () => unawaited(_cercaAdesso()));
  }

  Future<void> _cercaAdesso() async {
    if (!_puoCercare) return;
    final cercato = _testo.text.trim();
    final questa = ++_ultima;
    setState(() => _cerca = true);
    try {
      final trovati = await _servizi.mappe.cerca(
        cercato,
        viaggioId: widget.viaggioId,
        vicinoA: widget.vicinoA,
        sessione: _sessione,
      );
      if (!mounted || questa != _ultima) return;
      setState(() {
        _trovati = trovati;
        _errore = null;
      });
    } on ErroreTrolley catch (e) {
      if (!mounted || questa != _ultima) return;
      setState(() => _errore = e.messaggio);
    } finally {
      if (mounted && questa == _ultima) setState(() => _cerca = false);
    }
  }

  /// Scelto un posto, si chiede a Google dove sta: è la fine della sessione,
  /// e la sola chiamata che si paga.
  Future<void> _scegli(Luogo l) async {
    if (_scelto != null) return;
    setState(() {
      _scelto = l.id;
      _errore = null;
    });
    try {
      final trovato = await _servizi.mappe.posto(
        l.id,
        viaggioId: widget.viaggioId,
        sessione: _sessione,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        SceltaLuogo(
          testo: '',
          posto: trovato.posto,
          google: trovato.id,
          etichetta: [l.nome, ?l.indirizzo].join(', '),
        ),
      );
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _scelto = null;
        _sessione = const Uuid().v4();
      });
    }
  }

  void _comE() =>
      Navigator.of(context).pop(SceltaLuogo.aMano(_testo.text.trim()));

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) {
      final scritto = _testo.text.trim();
      final mappe = _servizi.mappe.disponibili;
      final sotto = !mappe
          ? 'La ricerca dei posti non c\'è in questa versione: scrivi il '
                'posto com\'è.'
          : !rete
          ? 'Senza rete scrivi il posto: lo cerchi sulla mappa quando torna '
                'la rete.'
          : widget.vicinoA == null
          ? null
          : widget.dalleTappe
          ? 'Vicino alle altre tappe del viaggio.'
          : 'Vicino alla meta del viaggio.';
      final trovati = rete && mappe ? _trovati : null;
      return Foglio(
        titolo: 'Dove?',
        children: [
          Campo(
            controller: _testo,
            segnaposto: 'Un museo, un ristorante, un indirizzo',
            icona: icona(
              ios: CupertinoIcons.search,
              android: Icons.search_rounded,
            ),
            maiuscole: TextCapitalization.words,
            correzione: false,
            fuoco: true,
            azione: TextInputAction.search,
            onInvio: (_) => scritto.isEmpty ? null : unawaited(_cercaAdesso()),
            onCambia: _cambiato,
          ),
          if (sotto != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                sotto,
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
          const SizedBox(height: 8),
          if (_cerca && trovati == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: IndicatoreAttivita()),
            ),
          if (_errore != null && rete)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Avviso(
                errore: true,
                icona: icona(
                  ios: CupertinoIcons.exclamationmark_circle,
                  android: Icons.error_outline_rounded,
                ),
                testo: _errore!,
              ),
            ),
          if (trovati != null && trovati.isEmpty && !_cerca)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(
                'Nessun posto con questo nome qui vicino.',
                style: Testi.secondario.copyWith(color: Colori.grafite),
              ),
            ),
          for (final (i, l) in (trovati ?? const <Luogo>[]).indexed)
            _Riga(
              icona: switch (l.tipo) {
                TipoLuogo.posto => Icons.place_outlined,
                TipoLuogo.indirizzo => Icons.signpost_outlined,
                TipoLuogo.zona => Icons.location_city_rounded,
              },
              primo: i == 0,
              titolo: l.nome,
              sotto: l.indirizzo,
              inAttesa: _scelto == l.id,
              onTap: () => unawaited(_scegli(l)),
            ).entra(context, ritardo: Ritmo.passo * i, da: 8),
          if (trovati != null && trovati.isNotEmpty) const AttribuzioneGoogle(),
          if (scritto.isNotEmpty)
            _Riga(
              icona: Icons.edit_outlined,
              titolo: 'Usa «$scritto» com\'è',
              sotto:
                  'Senza un posto: resta nell\'itinerario, non sulla mappa. '
                  'Lo cerchi dopo.',
              ultimo: true,
              onTap: _comE,
            ),
        ],
      );
    },
  );
}

/// Una riga della ricerca: l'icona nel cerchio, il nome, l'indirizzo.
class _Riga extends StatelessWidget {
  const _Riga({
    required this.icona,
    required this.titolo,
    required this.onTap,
    this.sotto,
    this.primo = false,
    this.ultimo = false,
    this.inAttesa = false,
  });

  final IconData icona;
  final String titolo;
  final String? sotto;
  final VoidCallback onTap;

  /// Si sta chiedendo dove sta: al posto dell'icona, l'attesa.
  final bool inAttesa;

  /// Il più probabile: il cerchio è cobalto.
  final bool primo;
  final bool ultimo;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: [titolo, ?sotto].join(', '),
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: ultimo
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFEEF0F4), width: 1.5),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primo ? Colori.cobaltoChiaro : Colori.foschia,
              ),
              child: inAttesa
                  ? const Center(child: IndicatoreAttivita())
                  : Icon(
                      icona,
                      size: 20,
                      color: primo ? Colori.cobalto : Colori.ardesia,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                  ),
                  if (sotto != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sotto!,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// «Google Maps» sotto quello che viene da Google: com'è, su una riga, mai
/// tradotto, grigio e di peso normale (condizioni di Google Places, ADR-014).
class AttribuzioneGoogle extends StatelessWidget {
  const AttribuzioneGoogle({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
    child: Text(
      Servizi.of(context).mappe.attribuzioneRicerca,
      textAlign: TextAlign.right,
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontFamilyFallback: ['sans-serif'],
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: Color(0xFF5E5E5E),
      ),
    ),
  );
}
