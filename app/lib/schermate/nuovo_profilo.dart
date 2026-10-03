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
    final nascita = _nascita;
    final mq = MediaQuery.of(context);
    // Come "5 · Come ti chiami?" della tela: il percorso a puntini in alto,
    // il titolo grande, una scheda bianca con il nome e la data, in fondo
    // "Continua" ed "Esci".
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colori.nebbia)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: mq.padding.top + 110,
          child: const ExcludeSemantics(
            child: CustomPaint(painter: _PercorsoInAlto()),
          ),
        ),
        Scaffold(
          backgroundColor: const Color(0x00000000),
          body: LayoutBuilder(
            builder: (context, vincoli) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                mq.padding.top + 96,
                20,
                mq.padding.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      vincoli.maxHeight -
                      mq.padding.top -
                      mq.padding.bottom -
                      64,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Come ti chiami?',
                            style: Testi.titoli(32)
                                .copyWith(color: Colori.inchiostro),
                          ),
                        ),
                      ).entra(context),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 28),
                        child: Text(
                          'Il nome lo vedono i compagni dei tuoi viaggi.',
                          style: Testi.corpo.copyWith(color: Colori.grafite),
                        ),
                      ).entra(context, ritardo: Ritmo.passo),
                      if (widget.invitoInAttesa) ...[
                        const AvvisoInvito(
                          testo:
                              'Ancora un passo e il viaggio a cui ti hanno '
                              'invitato si apre.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      Pannello(
                        raggio: 24,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Campo(
                              controller: _nome,
                              etichetta: 'Nome',
                              segnaposto: 'Il tuo nome',
                              maiuscole: TextCapitalization.words,
                              suggerimenti: const [AutofillHints.givenName],
                            ),
                            const SizedBox(height: 18),
                            CampoScelta(
                              etichetta: 'Data di nascita',
                              simbolo: icona(
                                ios: CupertinoIcons.gift,
                                android: Icons.cake_outlined,
                              ),
                              segnaposto: 'Scegli la data',
                              valore: nascita == null
                                  ? null
                                  : dataEstesa(nascita),
                              onTap: _scegliData,
                            ),
                          ],
                        ),
                      ).entra(context, ritardo: Ritmo.passo * 2, da: 30),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                        child: Text(
                          'Servono $etaMinimaAccount anni compiuti. Dopo averla '
                          'salvata, la data di nascita si può cambiare solo '
                          'tramite l\'assistenza.',
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
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
                                  style: Testi.secondario.copyWith(
                                    color: Colori.pericolo,
                                  ),
                                ).entra(context, da: 6),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Premibile(
                        onTap: () =>
                            Servizi.of(context).supabase.auth.signOut(),
                        etichetta: 'Esci',
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              'Esci',
                              style: Testi.corpo.copyWith(
                                color: Colori.ardesia,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Il percorso a puntini della tela, in alto a destra: un punto giallo e uno
/// cobalto.
class _PercorsoInAlto extends CustomPainter {
  const _PercorsoInAlto();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final y0 = size.height - 150;
    Offset p(double x, double y) => Offset(x * sx, y0 + y);
    final percorso = Path()
      ..moveTo(p(190, 128).dx, p(190, 128).dy)
      ..cubicTo(240 * sx, y0 + 80, 290 * sx, y0 + 130, 330 * sx, y0 + 70)
      ..cubicTo(370 * sx, y0 + 10, 380 * sx, y0 + 30, 410 * sx, y0 + 40);
    final tratto = Paint()
      ..color = Colori.cobalto.withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final metrica in percorso.computeMetrics()) {
      for (var d = 0.0; d < metrica.length; d += 12) {
        final punto = metrica.getTangentForOffset(d)?.position;
        if (punto != null) {
          canvas.drawLine(punto, punto.translate(0.01, 0), tratto);
        }
      }
    }
    canvas
      ..drawCircle(p(252, 100), 7, Paint()..color = Colori.sole)
      ..drawCircle(p(336, 62), 6, Paint()..color = Colori.cobalto);
  }

  @override
  bool shouldRepaint(_PercorsoInAlto vecchio) => false;
}
