import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dominio/liste.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'due_versioni.dart';

/// Una voce da cambiare (05-cose-da-portare.md, "Voce"; tela, 21): che cosa,
/// quante, ed eliminarla. Cambiare il testo è un gesto da tavolo, non da
/// valigia: richiede la rete, e senza lo dice prima (regola 5).
///
/// Chi la porta arriva con la lista del viaggio (2.4): questa è la propria, e
/// in un viaggio con altri il foglio lo ricorda.
class FoglioVoce extends StatelessWidget {
  const FoglioVoce({super.key, required this.voce, this.conAltri = false});

  final VoceLista voce;
  final bool conAltri;

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) =>
        _Foglio(voce: voce, conAltri: conAltri, rete: rete),
  );
}

class _Foglio extends StatefulWidget {
  const _Foglio({
    required this.voce,
    required this.conAltri,
    required this.rete,
  });

  final VoceLista voce;
  final bool conAltri;
  final bool rete;

  @override
  State<_Foglio> createState() => _FoglioState();
}

class _FoglioState extends State<_Foglio> {
  late final _testo = TextEditingController(text: widget.voce.testo);
  late int _quante = widget.voce.quantita;
  bool _inCorso = false;

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  Map<String, Object?> get _cambiamenti {
    final testo = testoVoce(_testo.text);
    return {
      if (testo != null && testo != widget.voce.testo) 'testo': testo,
      if (_quante != widget.voce.quantita) 'quantita': _quante,
    };
  }

  /// Perché non si può ancora salvare; `null` se si può.
  String? get _motivo {
    if (testoVoce(_testo.text) == null) return 'Scrivi che cosa portare';
    if (!widget.rete) return motivoSenzaRete;
    if (_cambiamenti.isEmpty) return 'Niente da salvare';
    return null;
  }

  Future<void> _salva() async {
    final archivio = Servizi.of(context).archivio;
    final cambiamenti = _cambiamenti;
    setState(() => _inCorso = true);
    try {
      // Se qualcuno l'ha riscritta intanto, si sceglie fra le due versioni.
      // Tornando indietro senza scegliere, il testo che si stava scrivendo
      // resta nel campo: non si perde e non si fonde con l'altro (02 §3).
      final scelta = await salvaOScegli(
        context,
        () => archivio.modificaVoce(widget.voce, cambiamenti),
      );
      if (scelta == null) return;
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _togli() async {
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Eliminare «${widget.voce.testo}»?',
      message: 'Esce dalla lista.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Elimina',
          style: AlertActionStyle.destructive,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !mounted) return;
    final archivio = Servizi.of(context).archivio;
    setState(() => _inCorso = true);
    try {
      final scelta = await salvaOScegli(
        context,
        () => archivio.togliVoce(widget.voce),
      );
      if (scelta != null && mounted) Navigator.of(context).pop();
    } on ErroreTrolley catch (e) {
      if (mounted) mostraMessaggio(context, e.messaggio, errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _motivo;
    return Foglio(
      titolo: 'La voce',
      inBasso: AzioniFoglio(
        motivo: motivo,
        azione: PulsanteGrande(
          etichetta: 'Salva',
          inCorso: _inCorso,
          onPressed: motivo == null ? _salva : null,
        ),
      ),
      children: [
        Campo(
          controller: _testo,
          etichetta: 'Cosa?',
          segnaposto: 'Passaporto, adattatore, ombrello…',
          maiuscole: TextCapitalization.sentences,
          onCambia: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Quante?',
            style: Testi.etichetta.copyWith(color: Colori.ardesia),
          ),
        ),
        _Quante(
          valore: _quante,
          onCambia: (n) => setState(() => _quante = quantitaValida(n)),
        ),
        if (widget.conAltri) ...[
          const SizedBox(height: 16),
          Avviso(
            fondo: Colori.foschia,
            icona: icona(
              ios: CupertinoIcons.lock,
              android: Icons.lock_outline_rounded,
            ),
            testo: 'La vedi solo tu: gli altri del viaggio non la vedono.',
          ),
        ],
        const SizedBox(height: 20),
        PulsanteGrande(
          etichetta: 'Elimina la voce',
          secondario: true,
          pericolo: true,
          motivo: widget.rete ? null : motivoSenzaRete,
          onPressed: _inCorso || !widget.rete ? null : _togli,
        ),
      ],
    );
  }
}

/// Quante, con meno e più ai lati (tela, 21).
class _Quante extends StatelessWidget {
  const _Quante({required this.valore, required this.onCambia});

  final int valore;
  final ValueChanged<int> onCambia;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Quante',
    value: '$valore',
    increasedValue: '${quantitaValida(valore + 1)}',
    decreasedValue: '${quantitaValida(valore - 1)}',
    onIncrease: valore < quantitaMassima ? () => onCambia(valore + 1) : null,
    onDecrease: valore > quantitaMinima ? () => onCambia(valore - 1) : null,
    child: ExcludeSemantics(
      child: Row(
        children: [
          _Passo(
            icona: Icons.remove_rounded,
            onTap: valore > quantitaMinima ? () => onCambia(valore - 1) : null,
          ),
          SizedBox(
            width: 72,
            child: AnimatedSwitcher(
              duration: movimentoRidotto(context) ? Duration.zero : Ritmo.breve,
              child: Text(
                '$valore',
                key: ValueKey(valore),
                textAlign: TextAlign.center,
                style: Testi.titoli(
                  28,
                  spaziatura: 0,
                ).copyWith(color: Colori.inchiostro),
              ),
            ),
          ),
          _Passo(
            icona: Icons.add_rounded,
            onTap: valore < quantitaMassima ? () => onCambia(valore + 1) : null,
          ),
        ],
      ),
    ),
  );
}

class _Passo extends StatelessWidget {
  const _Passo({required this.icona, required this.onTap});

  final IconData icona;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.92,
    child: Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colori.cenere, width: 2),
        ),
        child: Icon(icona, size: 22, color: Colori.inchiostro),
      ),
    ),
  );
}
