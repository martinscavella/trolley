import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

/// Il posto scelto per una tappa: quello che si scrive come «Dove», e dove
/// sta se lo si è trovato.
class SceltaLuogo {
  const SceltaLuogo({required this.testo, this.posto, this.nome});

  /// Cosa va in `luogo_nome`.
  final String testo;

  /// `null` se si è usato il testo com'è: la tappa resta senza posto, e lo si
  /// cerca dopo (ADR-005).
  final Coordinate? posto;

  /// Il nome del posto trovato: diventa il titolo di una tappa che non ne ha.
  final String? nome;
}

/// «Dove?» (tela, 56): il posto di una tappa, cercato vicino alla meta del
/// viaggio o alle sue tappe. La ricerca è del fornitore di mappe (ADR-005,
/// ADR-006) e ha bisogno della rete; senza, il posto si scrive com'è e si
/// cerca quando torna. Una tappa non si rifiuta mai perché manca un posto.
///
/// Chiudendo restituisce una [SceltaLuogo], o `null` se la persona ci ripensa.
class FoglioLuogo extends StatefulWidget {
  const FoglioLuogo({
    super.key,
    required this.viaggioId,
    this.iniziale,
    this.titolo,
    this.vicinoA,
    this.dalleTappe = false,
    this.cercaSubito = false,
  });

  final String viaggioId;

  /// Quello che c'era già scritto.
  final String? iniziale;

  /// Il titolo della tappa: se il posto ha lo stesso nome, come «Dove» basta
  /// l'indirizzo.
  final String? titolo;

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
        vicinoA: widget.vicinoA,
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

  void _scegli(Luogo l) {
    final nome = l.tipo == TipoLuogo.posto ? l.nome : null;
    // Una tappa ancora senza titolo prende il nome del posto: allora come
    // «Dove» basta l'indirizzo.
    final titolo = (widget.titolo?.trim().isEmpty ?? true)
        ? nome
        : widget.titolo;
    Navigator.of(context).pop(
      SceltaLuogo(
        testo: l.dove(titolo: titolo),
        posto: l.posto,
        nome: nome,
      ),
    );
  }

  void _comE() =>
      Navigator.of(context).pop(SceltaLuogo(testo: _testo.text.trim()));

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
        inBasso: mappe
            ? Text(
                _servizi.mappe.attribuzione,
                textAlign: TextAlign.center,
                style: Testi.didascalia.copyWith(
                  color: Colori.grafite.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              )
            : null,
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
              onTap: () => _scegli(l),
            ).entra(context, ritardo: Ritmo.passo * i, da: 8),
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
  });

  final IconData icona;
  final String titolo;
  final String? sotto;
  final VoidCallback onTap;

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
              child: Icon(
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
