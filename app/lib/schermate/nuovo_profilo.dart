import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/eta.dart';
import '../servizi.dart';
import 'avviso_invito.dart';
import 'benvenuto.dart';
import 'con_la_rete.dart';

/// Nome e data di nascita, la prima volta (01-account-e-profilo.md).
///
/// La data di nascita dopo non si cambia da soli: lo si dice prima di salvarla.
class SchermataNuovoProfilo extends StatefulWidget {
  const SchermataNuovoProfilo({
    super.key,
    required this.invitoInAttesa,
    required this.onCreato,
  });

  final bool invitoInAttesa;
  final Future<void> Function() onCreato;

  @override
  State<SchermataNuovoProfilo> createState() => _SchermataNuovoProfiloState();
}

class _SchermataNuovoProfiloState extends State<SchermataNuovoProfilo> {
  final _nome = TextEditingController();
  DateTime? _nascita;
  bool _inCorso = false;
  String? _messaggio;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _scegliData() async {
    final oggi = DateTime.now();
    final scelta = await AdaptiveDatePicker.show(
      context: context,
      initialDate: _nascita ?? DateTime(oggi.year - 30, oggi.month, oggi.day),
      firstDate: DateTime(1900),
      lastDate: oggi,
    );
    if (scelta != null && mounted) setState(() => _nascita = scelta);
  }

  Future<void> _salva() async {
    final nome = _nome.text.trim();
    final nascita = _nascita;
    if (nome.isEmpty || nascita == null) {
      setState(() => _messaggio = 'Servono il nome e la data di nascita.');
      return;
    }
    if (!puoCreareAccount(nascita, DateTime.now())) {
      setState(
        () => _messaggio =
            'Per usare Trolley servono $etaMinimaAccount anni compiuti.',
      );
      return;
    }
    setState(() {
      _inCorso = true;
      _messaggio = null;
    });
    try {
      await Servizi.of(context).archivio
          .creaProfilo(nome: nome, dataNascita: nascita);
      await widget.onCreato();
    } on ErroreTrolley catch (e) {
      if (mounted) setState(() => _messaggio = e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final nascita = _nascita;
    return LayoutBenvenuto(
      titolo: 'Come ti chiami?',
      sottotitolo: 'Il nome lo vedono i compagni dei tuoi viaggi.',
      inAlto: CupertinoButton(
        onPressed: () => Servizi.of(context).supabase.auth.signOut(),
        child: Text(
          'Esci',
          style: Testi.evidenza.copyWith(color: Colors.white),
        ),
      ),
      pannello: Pannello(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.invitoInAttesa) ...[
              const AvvisoInvito(
                testo:
                    'Ancora un passo e il viaggio a cui ti hanno invitato '
                    'si apre.',
              ),
              const SizedBox(height: 16),
            ],
            Campo(
              controller: _nome,
              segnaposto: 'Nome',
              icona: icona(
                ios: CupertinoIcons.person,
                android: Icons.person_outline,
              ),
              maiuscole: TextCapitalization.words,
              suggerimenti: const [AutofillHints.givenName],
            ),
            const SizedBox(height: 10),
            CampoScelta(
              simbolo: icona(
                ios: CupertinoIcons.gift,
                android: Icons.cake_outlined,
              ),
              segnaposto: 'Data di nascita',
              valore: nascita == null ? null : dataEstesa(nascita),
              onTap: _scegliData,
            ),
            const SizedBox(height: 10),
            Text(
              'Servono $etaMinimaAccount anni compiuti. Dopo averla salvata, la '
              'data di nascita si può cambiare solo tramite l\'assistenza.',
              style: Testi.didascalia.copyWith(color: t.testoSecondario),
            ),
            const SizedBox(height: 20),
            ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Continua',
                inCorso: _inCorso,
                motivo: rete ? null : motivoSenzaRete,
                onPressed: _salva,
              ),
            ),
            AnimatedSize(
              duration: Ritmo.medio,
              curve: Ritmo.curva,
              child: _messaggio == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _messaggio!,
                        textAlign: TextAlign.center,
                        style: Testi.secondario.copyWith(color: t.pericolo),
                      ).entra(context, da: 6),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
