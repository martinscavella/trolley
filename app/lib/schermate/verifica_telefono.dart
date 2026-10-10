/// La verifica del numero di telefono (5.1; tela, 104 e 69): il numero, poi
/// il codice arrivato per SMS. Un numero vale per un account, e non compare da
/// nessuna parte (01, regola 4).
///
/// Richiede la rete: senza, i pulsanti si spengono e lo dicono. Le due pagine
/// tornano `true` quando il numero è verificato. Si misura la verifica
/// riuscita (07, `telefono_verificato`).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dati/telefono.dart';
import '../dominio/parte_pubblica.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';

/// «Il tuo numero» (tela, 104).
class SchermataIlTuoNumero extends StatefulWidget {
  const SchermataIlTuoNumero({super.key});

  @override
  State<SchermataIlTuoNumero> createState() => _SchermataIlTuoNumeroState();
}

class _SchermataIlTuoNumeroState extends State<SchermataIlTuoNumero> {
  final _numero = TextEditingController();
  bool _inCorso = false;

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  /// Con un prefisso scritto, la capsula «+39» non c'è.
  bool get _conPrefisso {
    final t = _numero.text.trimLeft();
    return t.startsWith('+') || t.startsWith('00');
  }

  Future<void> _manda() async {
    final numero = numeroInternazionale(_numero.text);
    if (numero == null) return;
    final telefono = Servizi.of(context).telefono;
    setState(() => _inCorso = true);
    try {
      final partito = await telefono.mandaCodice(numero);
      if (!mounted) return;
      setState(() => _inCorso = false);
      // Già verificato, ed è il suo: non serve un codice.
      if (!partito) {
        Navigator.of(context).pop(true);
        return;
      }
      final verificato = await apri<bool>(
        context,
        SchermataIlCodice(numero: numero),
      );
      if (verificato == true && mounted) Navigator.of(context).pop(true);
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valido = numeroInternazionale(_numero.text) != null;
    return Pagina(
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            const TitoloPagina(
              'Il tuo numero',
              sottotitolo:
                  'Ti mandiamo un codice per SMS. Il numero serve solo a '
                  'sapere che dietro il profilo c\'è una persona, con un '
                  'account solo.',
            ).entra(context),
            Campo(
              controller: _numero,
              segnaposto: '347 123 4567',
              prefisso: _conPrefisso ? null : '+39',
              tastiera: TextInputType.phone,
              suggerimenti: const [AutofillHints.telephoneNumber],
              correzione: false,
              fuoco: true,
              azione: TextInputAction.done,
              onCambia: (_) => setState(() {}),
              onInvio: (_) => valido ? _manda() : null,
            ).entra(context, ritardo: Ritmo.passo),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Se non è italiano, scrivilo con il suo prefisso: +44…',
                style: Testi.didascalia.copyWith(color: Colori.grafite),
              ),
            ),
            const SizedBox(height: 20),
            Avviso(
              icona: icona(
                ios: CupertinoIcons.lock,
                android: Icons.lock_outline,
              ),
              testo:
                  'Non compare sul profilo e non lo vede nessuno. Un numero '
                  'vale per un account solo.',
            ).entra(context, ritardo: Ritmo.passo * 2),
            const SizedBox(height: 20),
            ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Mandami il codice',
                icona: icona(
                  ios: CupertinoIcons.device_phone_portrait,
                  android: Icons.smartphone_rounded,
                ),
                inCorso: _inCorso,
                motivo: rete ? null : motivoSenzaRete,
                onPressed: valido ? _manda : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Il codice» (tela, 69): sei cifre, che su iPhone arrivano da sole
/// dall'SMS. Con l'ultima si verifica.
class SchermataIlCodice extends StatefulWidget {
  const SchermataIlCodice({super.key, required this.numero});

  /// `+393471234567`.
  final String numero;

  @override
  State<SchermataIlCodice> createState() => _SchermataIlCodiceState();
}

class _SchermataIlCodiceState extends State<SchermataIlCodice> {
  final _codice = TextEditingController();
  bool _inCorso = false;

  /// Quando si potrà chiedere un altro codice.
  late DateTime _nuovoDalle = DateTime.now().add(attesaNuovoCodice);
  Timer? _orologio;

  @override
  void initState() {
    super.initState();
    _avviaOrologio();
  }

  @override
  void dispose() {
    _orologio?.cancel();
    _codice.dispose();
    super.dispose();
  }

  void _avviaOrologio() {
    _orologio?.cancel();
    _orologio = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {});
      if (!DateTime.now().isBefore(_nuovoDalle)) t.cancel();
    });
  }

  Future<void> _verifica() async {
    final codice = codiceCompleto(_codice.text);
    if (codice == null || _inCorso) return;
    final servizi = Servizi.of(context);
    setState(() => _inCorso = true);
    try {
      await servizi.telefono.verifica(widget.numero, codice);
      await servizi.misurazione.registra(Eventi.telefonoVerificato);
      unawaited(servizi.misurazione.invia());
      if (mounted) Navigator.of(context).pop(true);
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      if (e.codice == CodiciTelefono.sbagliato) _codice.clear();
      mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  Future<void> _unAltro() async {
    final telefono = Servizi.of(context).telefono;
    try {
      await telefono.mandaCodice(widget.numero);
      if (!mounted) return;
      setState(() {
        _nuovoDalle = DateTime.now().add(attesaNuovoCodice);
        _codice.clear();
      });
      _avviaOrologio();
      mostraMessaggio(context, 'Ti abbiamo mandato un altro codice.');
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completo = codiceCompleto(_codice.text) != null;
    final mancano = _nuovoDalle.difference(DateTime.now());
    return Pagina(
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            TitoloPagina(
              'Il codice',
              sottotitolo:
                  'L\'abbiamo mandato per SMS al '
                  '${numeroNascosto(widget.numero)}.',
            ).entra(context),
            _Cifre(
              controller: _codice,
              onCambia: () {
                setState(() {});
                if (codiceCompleto(_codice.text) != null) _verifica();
              },
            ).entra(context, ritardo: Ritmo.passo),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: mancano > Duration.zero
                  ? Text(
                      'Non è arrivato? Puoi chiederne un altro tra '
                      '${_minuti(mancano)}.',
                      style: Testi.secondario.copyWith(color: Colori.grafite),
                    )
                  : ConLaRete(
                      builder: (context, rete) => TestoConRimando(
                        'Non è arrivato? **Chiedine un altro**',
                        onTap: rete ? _unAltro : null,
                        motivo: motivoSenzaRete,
                        stile: Testi.secondario.copyWith(color: Colori.grafite),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Avviso(
              icona: icona(
                ios: CupertinoIcons.lock,
                android: Icons.lock_outline,
              ),
              testo:
                  'Il numero serve solo a sapere che dietro il profilo c\'è '
                  'una persona, con un account solo. Non lo vede nessuno.',
            ).entra(context, ritardo: Ritmo.passo * 2),
            const SizedBox(height: 20),
            ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Verifica',
                inCorso: _inCorso,
                motivo: !rete
                    ? motivoSenzaRete
                    : completo
                    ? null
                    : 'Si accende con tutte e sei le cifre.',
                onPressed: _verifica,
              ),
            ),
            const SizedBox(height: 10),
            PulsanteGrande(
              etichetta: 'Cambia numero',
              secondario: true,
              onPressed: _inCorso ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// `0:42`.
  static String _minuti(Duration d) {
    final secondi = (d.inMilliseconds / 1000).ceil();
    return '${secondi ~/ 60}:${(secondi % 60).toString().padLeft(2, '0')}';
  }
}

/// Le sei caselle del codice (tela, 69). Sotto c'è un campo vero, invisibile:
/// la tastiera numerica, l'SMS che riempie da solo, VoiceOver.
class _Cifre extends StatefulWidget {
  const _Cifre({required this.controller, required this.onCambia});

  final TextEditingController controller;
  final VoidCallback onCambia;

  @override
  State<_Cifre> createState() => _CifreState();
}

class _CifreState extends State<_Cifre> {
  final _fuoco = FocusNode();

  @override
  void initState() {
    super.initState();
    _fuoco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fuoco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cifre = widget.controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _fuoco.requestFocus,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                controller: widget.controller,
                focusNode: _fuoco,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(cifreDelCodice),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Il codice di sei cifre',
                ),
                onChanged: (_) => widget.onCambia(),
              ),
            ),
          ),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < cifreDelCodice; i++)
                  AnimatedContainer(
                    duration: Ritmo.breve,
                    width: 46,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colori.bianco,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        width: 2,
                        color:
                            _fuoco.hasFocus &&
                                i == cifre.length.clamp(0, cifreDelCodice - 1)
                            ? Colori.cobalto
                            : Colori.cenere,
                      ),
                    ),
                    child: Text(
                      i < cifre.length ? cifre[i] : '',
                      style: Testi.titoli(22)
                          .copyWith(color: Colori.inchiostro),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
