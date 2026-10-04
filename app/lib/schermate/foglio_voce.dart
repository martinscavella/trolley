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
import 'gesti_voce.dart';

/// Una voce da cambiare (05-cose-da-portare.md, "Voce"; tela, 21 e 43): che
/// cosa, quante e, nella lista del viaggio, chi la porta — nessuno, tu, uno
/// dei compagni. Quando le liste sono due, la voce si sposta dall'una
/// all'altra; e si elimina.
///
/// Cambiare, assegnare e spostare sono gesti da tavolo, non da valigia:
/// richiedono la rete, e senza lo dicono prima (regola 5).
class FoglioVoce extends StatelessWidget {
  const FoglioVoce({super.key, required this.voce, this.dueListe = false});

  final VoceLista voce;

  /// Si vedono tutte e due le liste: il foglio dice chi vede la voce, e
  /// propone di spostarla nell'altra.
  final bool dueListe;

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) =>
        _Foglio(voce: voce, dueListe: dueListe, rete: rete),
  );
}

class _Foglio extends StatefulWidget {
  const _Foglio({
    required this.voce,
    required this.dueListe,
    required this.rete,
  });

  final VoceLista voce;
  final bool dueListe;
  final bool rete;

  @override
  State<_Foglio> createState() => _FoglioState();
}

class _FoglioState extends State<_Foglio> {
  late final _testo = TextEditingController(text: widget.voce.testo);
  late int _quante = widget.voce.quantita;
  late Stream<List<(Partecipazione, Utente?)>> _partecipanti;
  late Stream<Map<String, String>> _nomi;
  bool _avviato = false;
  bool _inCorso = false;

  /// Chi la porta, se la persona l'ha scelto in questo foglio.
  ({String? chi})? _scelta;

  bool get _delViaggio => widget.voce.tipo == TipoLista.viaggio.codice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avviato) return;
    _avviato = true;
    final archivio = Servizi.of(context).archivio;
    _partecipanti = archivio.osservaPartecipanti(widget.voce.viaggioId);
    _nomi = archivio.osservaNomi(widget.voce.viaggioId);
  }

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  /// Chi la porta adesso nel foglio: quello che si è scelto, o chi la porta
  /// già — se c'è ancora. Finché non si sa chi c'è, com'è nella copia.
  String? _porta(Set<String>? presenti) {
    if (_scelta case (:final chi)) return chi;
    if (presenti == null) return widget.voce.assegnatoA;
    return chiLaPorta(widget.voce.assegnatoA, presenti);
  }

  Map<String, Object?> _cambiamenti(Set<String>? presenti) {
    final testo = testoVoce(_testo.text);
    final porta = _porta(presenti);
    return {
      if (testo != null && testo != widget.voce.testo) 'testo': testo,
      if (_quante != widget.voce.quantita) 'quantita': _quante,
      if (_delViaggio && presenti != null && porta != widget.voce.assegnatoA)
        'assegnato_a': porta,
    };
  }

  /// Perché non si può ancora salvare; `null` se si può.
  String? _motivo(Set<String>? presenti) {
    if (testoVoce(_testo.text) == null) return 'Scrivi che cosa portare';
    if (!widget.rete) return motivoSenzaRete;
    if (_cambiamenti(presenti).isEmpty) return 'Niente da salvare';
    return null;
  }

  Future<void> _salva(Set<String>? presenti) async {
    final cambiamenti = _cambiamenti(presenti);
    setState(() => _inCorso = true);
    try {
      // Se qualcuno l'ha riscritta intanto, si sceglie fra le due versioni.
      // Tornando indietro senza scegliere, il testo che si stava scrivendo
      // resta nel campo: non si perde e non si fonde con l'altro (02 §3).
      final scelta = await salvaOScegli(
        context,
        () =>
            cambiaLaVoce(context, voce: widget.voce, cambiamenti: cambiamenti),
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

  /// Sposta la voce nell'altra lista. Quello che si è cambiato nel foglio si
  /// salva prima, con le sue due versioni se serve; poi si sposta la voce
  /// com'è sul server.
  Future<void> _sposta(Set<String>? presenti) async {
    final archivio = Servizi.of(context).archivio;
    final cambiamenti = _cambiamenti(presenti);
    setState(() => _inCorso = true);
    try {
      var voce = widget.voce;
      if (cambiamenti.isNotEmpty) {
        final scelta = await salvaOScegli(
          context,
          () => cambiaLaVoce(context, voce: voce, cambiamenti: cambiamenti),
        );
        if (scelta == null || !mounted) return;
        // Scegliendo fra due versioni si è deciso un'altra cosa: la voce si
        // rivede nella lista prima di spostarla.
        if (scelta != SceltaVersione.tua) {
          Navigator.of(context).pop();
          return;
        }
        voce = await archivio.leggiVoce(voce.id) ?? voce;
      }
      if (!mounted) return;
      await spostaLaVoce(context, voce);
      if (!mounted) return;
      final navigatore = Navigator.of(context);
      navigatore.pop();
      final contesto = navigatore.overlay?.context;
      if (contesto != null && contesto.mounted) {
        mostraMessaggio(
          contesto,
          _delViaggio
              ? 'Ora è fra le tue cose: la vedi solo tu.'
              : 'Ora è nella lista del viaggio, e la porti tu.',
        );
      }
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
      message: _delViaggio
          ? 'Esce dalla lista del viaggio, per tutti.'
          : 'Esce dalla lista.',
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
  Widget build(BuildContext context) =>
      StreamBuilder<List<(Partecipazione, Utente?)>>(
        stream: _partecipanti,
        builder: (context, partecipanti) => StreamBuilder<Map<String, String>>(
          stream: _nomi,
          builder: (context, nomi) =>
              _contenuto(partecipanti.data, nomi.data ?? const {}),
        ),
      );

  Widget _contenuto(
    List<(Partecipazione, Utente?)>? partecipanti,
    Map<String, String> nomi,
  ) {
    final io = Servizi.of(context).archivio.io;
    final presenti = partecipanti == null
        ? null
        : {for (final (p, _) in partecipanti) p.utenteId};
    final motivo = _motivo(presenti);
    final porta = _porta(presenti);
    final lista = TipoLista.values.byName(widget.voce.tipo);
    final spostabile =
        widget.dueListe &&
        io != null &&
        siSposta(lista: lista, portaChi: porta, io: io);
    final autore = widget.voce.creatoDa == io
        ? 'te'
        : nomi[widget.voce.creatoDa];
    final altri = [
      for (final (p, u) in partecipanti ?? const <(Partecipazione, Utente?)>[])
        if (p.utenteId != io) (p.utenteId, u?.nome ?? 'Senza nome'),
    ]..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    void scegli(String? chi) => setState(() => _scelta = (chi: chi));
    return Foglio(
      titolo: 'La voce',
      inBasso: AzioniFoglio(
        motivo: motivo,
        azione: PulsanteGrande(
          etichetta: 'Salva',
          inCorso: _inCorso,
          onPressed: motivo == null ? () => _salva(presenti) : null,
        ),
      ),
      children: [
        if (_delViaggio && autore != null) ...[
          Text(
            'Aggiunta da $autore',
            style: Testi.secondario.copyWith(color: Colori.grafite),
          ),
          const SizedBox(height: 16),
        ],
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
        if (_delViaggio && partecipanti != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Chi la porta?',
              style: Testi.etichetta.copyWith(color: Colori.ardesia),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Gettone(
                etichetta: 'Nessuno',
                scelto: porta == null,
                onTap: widget.rete ? () => scegli(null) : null,
              ),
              if (io != null)
                Gettone(
                  etichetta: 'Tu',
                  scelto: porta == io,
                  onTap: widget.rete ? () => scegli(io) : null,
                ),
              for (final (id, nome) in altri)
                Gettone(
                  etichetta: nome,
                  scelto: porta == id,
                  onTap: widget.rete ? () => scegli(id) : null,
                ),
            ],
          ),
        ],
        if (_delViaggio) ...[
          const SizedBox(height: 16),
          Avviso(
            fondo: Colori.foschia,
            icona: icona(
              ios: CupertinoIcons.person_2,
              android: Icons.people_outline_rounded,
            ),
            testo:
                'La vedono tutti nel viaggio. Le tue cose che non riguardano '
                'gli altri vanno in «Mie».',
          ),
        ] else if (widget.dueListe) ...[
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
        if (spostabile) ...[
          const SizedBox(height: 20),
          PulsanteGrande(
            etichetta: _delViaggio
                ? 'Spostala nella tua lista'
                : 'Spostala nella lista del viaggio',
            secondario: true,
            motivo: widget.rete ? null : motivoSenzaRete,
            onPressed: _inCorso || !widget.rete
                ? null
                : () => _sposta(presenti),
          ),
        ],
        SizedBox(height: spostabile ? 10 : 20),
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
