/// I gesti dei collegamenti (5.4; 11, regole 3–5; tela, 76, 77, 112, 113 e
/// 116), uguali da dove si fanno: il profilo di un altro, i collegamenti, una
/// conversazione. Chiedere, rispondere, ritirare, togliere.
///
/// Tutti con la rete. Si misurano chiedere e accettare (07,
/// `collegamento_richiesto` e `collegamento_accettato`): mai chi, solo se
/// l'altro è un compagno di viaggio.
library;

import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aspetto/elementi.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/collegamenti.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';

/// Chiede conferma con il dialogo di sistema. `true` se si conferma.
Future<bool> confermaCollegamento(
  BuildContext context, {
  required String titolo,
  required String messaggio,
  required String azione,
  bool pericolo = true,
}) async {
  var conferma = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: titolo,
    message: messaggio,
    actions: [
      AlertAction(
        title: 'Annulla',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: azione,
        style: pericolo
            ? AlertActionStyle.destructive
            : AlertActionStyle.primary,
        onPressed: () => conferma = true,
      ),
    ],
  );
  return conferma;
}

/// Registra [evento] — chiesto, o accettato — con `compagni`: se [utenteId]
/// è, o è stato, in un viaggio con chi usa il telefono.
Future<void> _misura(Servizi servizi, String evento, String utenteId) async {
  final compagni = await servizi.archivio.compagnoDiViaggio(utenteId);
  await servizi.misurazione.registra(evento, {'compagni': compagni});
  unawaited(servizi.misurazione.invia());
}

/// Apre «Collegarti con …?» (tela, 76). Restituisce com'è andata, o `null`
/// se si chiude senza mandare.
Future<EsitoRichiesta?> chiediDiCollegarvi(
  BuildContext context, {
  required String utenteId,
  required String nome,
}) => apriFoglio<EsitoRichiesta>(
  context,
  _FoglioRichiesta(utenteId: utenteId, nome: nome),
);

/// Accetta o rifiuta la richiesta di [nome]. Rifiutare chiede conferma, e
/// non glielo dice (11, regola 5). `true` se è fatto.
Future<bool> rispondiA(
  BuildContext context, {
  required String utenteId,
  required String nome,
  required bool accetta,
}) async {
  if (!accetta &&
      !await confermaCollegamento(
        context,
        titolo: 'Rifiutare la richiesta di $nome?',
        messaggio:
            'Non glielo diciamo: vedrà solo che la richiesta non è stata '
            'accettata.',
        azione: 'Rifiuta',
      )) {
    return false;
  }
  if (!context.mounted) return false;
  final servizi = Servizi.of(context);
  try {
    await servizi.partePubblica.rispondi(utenteId, accetta: accetta);
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
  if (accetta) {
    await _misura(servizi, Eventi.collegamentoAccettato, utenteId);
  }
  return true;
}

/// Ritira la propria richiesta a [utenteId], o toglie una non accettata.
Future<bool> ritiraRichiesta(BuildContext context, String utenteId) async {
  try {
    await Servizi.of(context).partePubblica.ritiraRichiesta(utenteId);
    return true;
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
}

/// Toglie il collegamento con [nome], dopo il dialogo di sistema: non vi
/// scrivete più, e la conversazione resta solo a lei (P6).
Future<bool> togliIlCollegamento(
  BuildContext context, {
  required String utenteId,
  required String nome,
}) async {
  if (!await confermaCollegamento(
    context,
    titolo: 'Togliere il collegamento con $nome?',
    messaggio:
        'Non potrete più scrivervi, e la conversazione non la vedrai più. A '
        '$nome resta, senza poterti scrivere.',
    azione: 'Togli',
  )) {
    return false;
  }
  if (!context.mounted) return false;
  try {
    await Servizi.of(context).partePubblica.togliCollegamento(utenteId);
    return true;
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
}

/// Toglie una conversazione finita (tela, 116), dopo il dialogo di sistema.
Future<bool> togliLaConversazione(
  BuildContext context, {
  required String utenteId,
}) async {
  if (!await confermaCollegamento(
    context,
    titolo: 'Togliere la conversazione?',
    messaggio: 'Non la vedrai più, e non si può riavere.',
    azione: 'Togli',
  )) {
    return false;
  }
  if (!context.mounted) return false;
  try {
    await Servizi.of(context).partePubblica.togliConversazione(utenteId);
    return true;
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
}

/// «Collegarti con Teresa?» (tela, 76): se accetta potrete scrivervi; fino
/// ad allora passa solo questo messaggio, facoltativo, di 200 caratteri.
class _FoglioRichiesta extends StatefulWidget {
  const _FoglioRichiesta({required this.utenteId, required this.nome});

  final String utenteId;
  final String nome;

  @override
  State<_FoglioRichiesta> createState() => _FoglioRichiestaState();
}

class _FoglioRichiestaState extends State<_FoglioRichiesta> {
  final _messaggio = TextEditingController();
  bool _inCorso = false;

  @override
  void initState() {
    super.initState();
    _messaggio.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messaggio.dispose();
    super.dispose();
  }

  Future<void> _manda() async {
    final servizi = Servizi.of(context);
    setState(() => _inCorso = true);
    try {
      final esito = await servizi.partePubblica.chiediCollegamento(
        widget.utenteId,
        messaggio: _messaggio.text,
      );
      switch (esito) {
        case EsitoRichiesta.richiesto:
          await _misura(servizi, Eventi.collegamentoRichiesto, widget.utenteId);
        case EsitoRichiesta.accettato:
          await _misura(servizi, Eventi.collegamentoAccettato, widget.utenteId);
        case EsitoRichiesta.nessunCambio:
          break;
      }
      if (mounted) Navigator.of(context).pop(esito);
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scritti = _messaggio.text.characters.length;
    return Foglio(
      titolo: 'Collegarti con ${widget.nome}?',
      inBasso: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: 'Invia la richiesta',
              icona: icona(
                ios: CupertinoIcons.paperplane,
                android: Icons.send_rounded,
              ),
              inCorso: _inCorso,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: _manda,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Se rifiuta, vedrai solo che la richiesta non è stata accettata.',
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ],
      ),
      children: [
        Text(
          'Se accetta, potrete scrivervi. Fino ad allora passa solo questo '
          'messaggio, e nient\'altro.',
          style: Testi.secondario.copyWith(color: Colori.grafite),
        ),
        const SizedBox(height: 16),
        Campo(
          controller: _messaggio,
          segnaposto: 'Due righe per ${widget.nome}: perché vi collegate',
          righe: 4,
          lunghezzaMassima: lunghezzaRichiesta,
          maiuscole: TextCapitalization.sentences,
          fuoco: true,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Facoltativo',
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
            const Spacer(),
            Text(
              '$scritti di $lunghezzaRichiesta',
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ),
      ],
    );
  }
}

/// Copia [testo] negli appunti, e lo dice.
Future<void> copiaMessaggio(BuildContext context, String testo) async {
  await Clipboard.setData(ClipboardData(text: testo));
  if (context.mounted) mostraMessaggio(context, 'Copiato.');
}
