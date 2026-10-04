import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dati/lettura.dart';
import '../dominio/divisione.dart';
import '../dominio/valute.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'due_versioni.dart';
import 'gesti_spesa.dart';
import 'spese.dart';

/// I saldi (06-spese.md, «Saldi»; tela, 40 e 89): chi deve cosa a chi, con il
/// giro più corto (regola 9), nella valuta della persona e dicendo di quando
/// sono i tassi. Chi ha lasciato il viaggio resta, tratteggiato: sparire non
/// estingue un debito (regola 10).
///
/// «Li ho ricevuti» lo tocca chi riceve: segna un rimborso, anche senza rete,
/// e il saldo si chiude per tutti. I soldi passano fuori da Trolley. Un
/// rimborso segnato per sbaglio si toglie, con la rete.
class SchermataSaldi extends StatelessWidget {
  const SchermataSaldi({super.key, required this.viaggioId});

  final String viaggioId;

  @override
  Widget build(BuildContext context) => ConConto(
    viaggioId: viaggioId,
    builder: (context, conto) => conto == null
        ? const Pagina(corpo: SizedBox.shrink())
        : ConLaRete(
            builder: (context, rete) =>
                _Saldi(viaggioId: viaggioId, conto: conto, rete: rete),
          ),
  );
}

class _Saldi extends StatelessWidget {
  const _Saldi({
    required this.viaggioId,
    required this.conto,
    required this.rete,
  });

  final String viaggioId;
  final ContoViaggio conto;
  final bool rete;

  String get _sottotitolo {
    final n = conto.passaggi.length;
    if (n == 0) return 'Siete pari: nessuno deve niente a nessuno.';
    final senza = conto.passaggiSenzaGiro;
    final quantiPassaggi = n == 1
        ? 'un passaggio'
        : '${numeroInParole(n)} passaggi';
    return senza > n
        ? 'Il giro più corto per pareggiare: $quantiPassaggi invece di '
              '${numeroInParole(senza)}.'
        : 'Il giro più corto per pareggiare: $quantiPassaggi.';
  }

  @override
  Widget build(BuildContext context) {
    final altre = {
      for (final s in [...conto.spese, ...conto.rimborsi])
        if (s.valuta != conto.mia) s.valuta,
    };
    final rimborsi = [...conto.rimborsi]
      ..sort((a, b) => b.registrata.compareTo(a.registrata));
    return Pagina(
      azioni: [if (!rete) const SeiOffline()],
      corpo: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            20,
            MediaQuery.paddingOf(context).bottom + 24,
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
                      'Saldi',
                      style: Testi.titolo.copyWith(color: Colori.inchiostro),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sottotitolo,
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ).entra(context),
            for (final (i, p) in conto.passaggi.indexed) ...[
              const SizedBox(height: 10),
              _SchedaPassaggio(
                passaggio: p,
                conto: conto,
                viaggioId: viaggioId,
              ).entra(context, ritardo: Ritmo.passo * (i + 1)),
            ],
            if (rimborsi.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    'GIÀ DATI',
                    style: Testi.sezione.copyWith(color: Colori.grafite),
                  ),
                ),
              ),
              for (final (i, r) in rimborsi.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _RigaRimborso(rimborso: r, conto: conto, rete: rete),
              ],
            ],
            if (altre.isNotEmpty || conto.saldi.senzaTasso.isNotEmpty) ...[
              const SizedBox(height: 12),
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.clock,
                  android: Icons.schedule_rounded,
                ),
                testo: [
                  'In ${nomeCortoValuta(conto.mia).toLowerCase()}, con i '
                      '${quandoITassi(conto.giornoTassi, DateTime.now())}'
                      '${rete ? '' : ': senza rete possono essere cambiati'}. '
                      'Ogni spesa resta anche nella sua valuta: quella è la '
                      'verità, il cambio no.',
                  if (conto.saldi.senzaTasso.isNotEmpty)
                    'Le spese in ${elenco(conto.saldi.senzaTasso.toList())} '
                        'non sono nei saldi: manca il tasso.',
                ].join(' '),
              ),
            ],
            if (conto.passaggi.isNotEmpty) ...[
              const SizedBox(height: 12),
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.creditcard,
                  android: Icons.credit_card_rounded,
                ),
                testo:
                    '«Li ho ricevuti» registra un rimborso, e il saldo si '
                    'chiude. I soldi passano fuori da Trolley, come sempre.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un passaggio del giro: chi dà, a chi, quanto (tela, 40).
class _SchedaPassaggio extends StatelessWidget {
  const _SchedaPassaggio({
    required this.passaggio,
    required this.conto,
    required this.viaggioId,
  });

  final Passaggio passaggio;
  final ContoViaggio conto;
  final String viaggioId;

  Future<void> _ricevuti(BuildContext context) async {
    final p = passaggio;
    final importo = scriviImporto(p.centesimi, conto.mia);
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Hai ricevuto $importo da ${conto.nome(p.da)}?',
      message: 'Il saldo si chiude per tutti quelli del viaggio.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Li ho ricevuti',
          style: AlertActionStyle.defaultAction,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !context.mounted) return;
    await registraIlRimborso(
      context,
      viaggioId: viaggioId,
      da: p.da,
      a: p.a,
      centesimi: p.centesimi,
      valuta: conto.mia,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = passaggio;
    final io = conto.io;
    final chi = p.da == io
        ? 'Tu dai a ${conto.nome(p.a)}'
        : p.a == io
        ? '${conto.nome(p.da)} dà a te'
        : '${conto.nome(p.da)} dà a ${conto.nome(p.a)}';
    final importo = scriviImporto(p.centesimi, conto.mia);
    final nota = p.da == io
        ? 'Quando li riceve, lo segna ${conto.nome(p.a)}: il saldo si chiude '
              'per tutti.'
        : conto.uscito(p.da)
        ? 'Ha lasciato il viaggio, ma il saldo resta: sparire non estingue un '
              'debito.'
        : conto.uscito(p.a)
        ? 'Ha lasciato il viaggio, ma il saldo resta.'
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                _Persona(id: p.da, conto: conto),
                const SizedBox(width: 10),
                Icon(
                  icona(
                    ios: CupertinoIcons.chevron_forward,
                    android: Icons.chevron_right_rounded,
                  ),
                  size: 18,
                  color: Colori.piombo,
                ),
                const SizedBox(width: 10),
                _Persona(id: p.a, conto: conto),
                const Spacer(),
                Text(
                  importo,
                  style: Testi.titoli(
                    20,
                    spaziatura: 0,
                    altezza: 1.1,
                  ).copyWith(color: Colori.inchiostro),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: conMaiuscola(chi),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colori.inchiostro,
                  ),
                ),
                TextSpan(text: ' $importo${nota == null ? '' : '. $nota'}'),
              ],
            ),
            style: Testi.corpo.copyWith(
              fontSize: 15,
              height: 1.4,
              color: Colori.ardesia,
            ),
          ),
          if (p.a == io) ...[
            const SizedBox(height: 10),
            PulsantePiccolo(
              etichetta: 'Li ho ricevuti',
              onPressed: () => _ricevuti(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un rimborso già segnato (tela, 89): chi ha dato a chi, quanto e quando. Se
/// è sbagliato si toglie, con la rete, e il saldo torna com'era.
class _RigaRimborso extends StatelessWidget {
  const _RigaRimborso({
    required this.rimborso,
    required this.conto,
    required this.rete,
  });

  final Spesa rimborso;
  final ContoViaggio conto;
  final bool rete;

  Future<void> _togli(BuildContext context) async {
    final archivio = Servizi.of(context).archivio;
    var conferma = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Togliere questo rimborso?',
      message: 'Il saldo torna com\'era, per tutti quelli del viaggio.',
      actions: [
        AlertAction(
          title: 'Annulla',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Togli',
          style: AlertActionStyle.destructive,
          onPressed: () => conferma = true,
        ),
      ],
    );
    if (!conferma || !context.mounted) return;
    try {
      await salvaOScegli(context, () => archivio.togliSpesa(rimborso));
    } on ErroreTrolley catch (e) {
      if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = rimborso;
    final a = conto.quoteDi(r).keys.firstOrNull;
    final verso = [
      r.paganteId == conto.io ? 'Tu' : conto.nome(r.paganteId),
      if (a != null) a == conto.io ? 'a te' : 'a ${conto.nome(a)}',
    ].join(' ');
    final importo = scriviImporto(r.centesimi, r.valuta);
    final quando = dataBreve(r.giorno);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  _Persona(id: r.paganteId, conto: conto, dimensione: 36),
                  const SizedBox(width: 6),
                  Icon(
                    icona(
                      ios: CupertinoIcons.chevron_forward,
                      android: Icons.chevron_right_rounded,
                    ),
                    size: 16,
                    color: Colori.piombo,
                  ),
                  const SizedBox(width: 6),
                  if (a != null) _Persona(id: a, conto: conto, dimensione: 36),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    importo,
                    style: Testi.evidenza.copyWith(
                      fontSize: 15,
                      color: Colori.inchiostro,
                    ),
                  ),
                  Text(
                    [
                      '$verso · $quando',
                      if (r.inCoda) 'parte con la rete',
                    ].join(' · '),
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                ],
              ),
            ),
            PulsantePiccolo(
              etichetta: 'Togli',
              pericolo: true,
              onPressed: rete && !r.inCoda ? () => _togli(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Le iniziali di qualcuno del viaggio; tratteggiate se ne è uscito.
class _Persona extends StatelessWidget {
  const _Persona({required this.id, required this.conto, this.dimensione = 40});

  final String id;
  final ContoViaggio conto;
  final double dimensione;

  @override
  Widget build(BuildContext context) {
    final nome = conto.nomi[id] ?? '?';
    if (!conto.uscito(id)) return Avatar(nome: nome, dimensione: dimensione);
    return CustomPaint(
      painter: const _CerchioTratteggiato(),
      child: SizedBox(
        width: dimensione,
        height: dimensione,
        child: Center(
          child: Text(
            iniziali(nome),
            style: Testi.titoli(
              dimensione * 0.36,
              spaziatura: 0,
              altezza: 1,
              peso: 600,
            ).copyWith(color: Colori.grafite),
          ),
        ),
      ),
    );
  }
}

class _CerchioTratteggiato extends CustomPainter {
  const _CerchioTratteggiato();

  @override
  void paint(Canvas canvas, Size size) {
    const tratti = 14;
    const pieno = 0.6;
    final pennello = Paint()
      ..color = Colori.piombo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final cerchio = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    const passo = 2 * 3.141592653589793 / tratti;
    for (var i = 0; i < tratti; i++) {
      canvas.drawArc(cerchio, i * passo, passo * pieno, false, pennello);
    }
  }

  @override
  bool shouldRepaint(_CerchioTratteggiato oldDelegate) => false;
}

/// «due», «tre», … fino a dieci; poi le cifre.
String numeroInParole(int n) => switch (n) {
  1 => 'uno',
  2 => 'due',
  3 => 'tre',
  4 => 'quattro',
  5 => 'cinque',
  6 => 'sei',
  7 => 'sette',
  8 => 'otto',
  9 => 'nove',
  10 => 'dieci',
  _ => '$n',
};
