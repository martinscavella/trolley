/// Il profilo pubblico di un altro viaggiatore (5.3; tela, 73): i numeri,
/// cosa ama in viaggio, cosa avete in comune, i viaggi chiusi e finiti che ha
/// lasciato sul profilo — la meta, il mese, i giorni. Da «…» si segnala o si
/// blocca, in due tocchi (12, regola 1).
///
/// Con la 5.4 il pulsante in basso dice a che punto siete (tela, 73, 112 e
/// 113): Chiedi di collegarvi, Richiesta inviata, Accetta o Rifiuta, Scrivi.
/// Collegati, da «…» si toglie anche il collegamento.
///
/// Dipende dalla rete, e non resta sul telefono. Se il profilo non si vede
/// più — spento, sospeso, bloccato — il server dice solo che non c'è.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/collegamenti.dart';
import '../dominio/itinerario.dart';
import '../dominio/parte_pubblica.dart';
import '../dominio/profilo_pubblico.dart';
import '../dominio/ricordo.dart';
import '../servizi.dart';
import 'collegamenti.dart';
import 'con_la_rete.dart';
import 'conversazione.dart';
import 'gesti_collegamenti.dart';
import 'persone_bloccate.dart';
import 'segnalazioni.dart';
import 'viaggiatori.dart';

/// Si chiude con `true` se la persona è stata bloccata: chi l'ha aperta la
/// toglie dall'elenco.
class SchermataProfiloAltrui extends StatefulWidget {
  const SchermataProfiloAltrui({
    super.key,
    required this.utenteId,
    required this.nome,
    this.mieiGusti = const {},
    this.mieMete = const [],
  });

  final String utenteId;

  /// Il nome com'era nella ricerca: si mostra mentre il profilo arriva.
  final String nome;

  /// Di chi guarda, per dire che cosa avete in comune.
  final Set<Interesse> mieiGusti;
  final List<Meta> mieMete;

  @override
  State<SchermataProfiloAltrui> createState() => _SchermataProfiloAltruiState();
}

class _SchermataProfiloAltruiState extends State<SchermataProfiloAltrui> {
  Future<ProfiloPubblico>? _profilo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profilo ??= Servizi.of(context).partePubblica.profiloDi(widget.utenteId);
  }

  void _ricarica() => setState(() {
    _profilo = Servizi.of(context).partePubblica.profiloDi(widget.utenteId);
  });

  Future<void> _menu(String nome, {required bool collegati}) =>
      scegliAzione(context, [
        AzioneMenu('Segnala $nome', () => _segnala(nome)),
        AzioneMenu('Blocca $nome', () => _blocca(nome), pericolo: true),
        if (collegati)
          AzioneMenu(
            'Togli il collegamento',
            () => _togliCollegamento(nome),
            pericolo: true,
          ),
      ]);

  Future<void> _togliCollegamento(String nome) async {
    if (await togliIlCollegamento(
          context,
          utenteId: widget.utenteId,
          nome: nome,
        ) &&
        mounted) {
      _ricarica();
    }
  }

  Future<void> _chiedi(String nome) async {
    final esito = await chiediDiCollegarvi(
      context,
      utenteId: widget.utenteId,
      nome: nome,
    );
    if (esito == null || !mounted) return;
    // Aveva già chiesto anche lei: siete collegati.
    if (esito == EsitoRichiesta.accettato) {
      mostraMessaggio(context, 'Siete collegati: ora potete scrivervi.');
    }
    _ricarica();
  }

  Future<void> _ritira(String nome) async {
    if (!await confermaCollegamento(
          context,
          titolo: 'Ritirare la richiesta a $nome?',
          messaggio: 'Non la vedrà più. Potrai chiedere di nuovo quando vuoi.',
          azione: 'Ritira',
        ) ||
        !mounted) {
      return;
    }
    if (await ritiraRichiesta(context, widget.utenteId) && mounted) {
      _ricarica();
    }
  }

  Future<void> _scrivi(String nome) async {
    final tolta = await apri<bool>(
      context,
      SchermataConversazione(utenteId: widget.utenteId, nome: nome),
    );
    if (!mounted) return;
    // Bloccata da lì: non vi vedete più, e chi ha aperto il profilo lo toglie.
    if (tolta == true) {
      final bloccate = await Servizi.of(context).partePubblica
          .personeBloccate()
          .catchError((_) => const <PersonaBloccata>[]);
      if (!mounted) return;
      if (bloccate.any((b) => b.id == widget.utenteId)) {
        Navigator.of(context).pop(true);
        return;
      }
    }
    _ricarica();
  }

  Future<void> _segnala(String nome) async {
    final servizi = Servizi.of(context);
    await segnala(
      context,
      tipo: TipoSegnalato.profilo,
      oggettoId: widget.utenteId,
      utenteId: widget.utenteId,
      nome: nome,
    );
    if (!mounted) return;
    // Con «Blocca anche», acceso di partenza, non vi vedete più.
    final bloccate = await servizi.partePubblica.personeBloccate().catchError(
      (_) => const <PersonaBloccata>[],
    );
    if (mounted && bloccate.any((b) => b.id == widget.utenteId)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _blocca(String nome) async {
    final fatto = await blocca(
      context,
      utenteId: widget.utenteId,
      nome: nome,
      da: DaDoveSiBlocca.profilo,
    );
    if (!fatto || !mounted) return;
    mostraMessaggio(context, 'Hai bloccato $nome: non vi vedete più.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProfiloPubblico>(
    future: _profilo,
    builder: (context, letto) {
      final profilo = letto.data;
      final nome = profilo?.nome ?? widget.nome;
      final collegamento = profilo?.collegamento;
      final collegati = collegamento?.stato == StatoCollegamento.collegati;
      final caricato = letto.connectionState == ConnectionState.done;
      return Pagina(
        azioni: [
          if (profilo != null)
            ConLaRete(
              builder: (context, rete) => PulsanteTondo(
                icona: icona(
                  ios: CupertinoIcons.ellipsis,
                  android: Icons.more_horiz,
                ),
                etichetta: collegati
                    ? 'Segnala, blocca o togli il collegamento'
                    : 'Segnala o blocca',
                onPressed: rete
                    ? () => _menu(nome, collegati: collegati)
                    : null,
              ),
            ),
        ],
        inBasso: profilo != null && caricato
            ? _InBasso(
                nome: nome,
                utenteId: widget.utenteId,
                collegamento: collegamento,
                onChiedi: () => _chiedi(nome),
                onRitira: () => _ritira(nome),
                onScrivi: () => _scrivi(nome),
                onRisposto: (accettata) {
                  if (accettata) {
                    mostraMessaggio(
                      context,
                      'Siete collegati: ora potete scrivervi.',
                    );
                  }
                  _ricarica();
                },
              )
            : null,
        corpo: Builder(
          builder: (context) {
            final padding = EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top,
              20,
              MediaQuery.paddingOf(context).bottom +
                  (profilo == null
                      ? 32
                      : collegamento?.stato == StatoCollegamento.ricevuta
                      ? 300
                      : 140),
            );
            return ListView(
              padding: padding,
              children: [
                _Testata(
                  nome: nome,
                  dal: profilo?.dal,
                  collegati: collegati,
                ).entra(context),
                const SizedBox(height: 16),
                if (letto.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: IndicatoreAttivita()),
                  )
                else if (profilo == null)
                  ..._nonSiLegge(letto.error)
                else
                  ..._profiloDi(profilo),
              ],
            );
          },
        ),
      );
    },
  );

  List<Widget> _nonSiLegge(Object? errore) {
    final nonCe =
        errore is ErroreTrolley && errore.codice == CodiciServer.nonTrovato;
    return [
      Avviso(
        icona: nonCe
            ? icona(ios: CupertinoIcons.person, android: Icons.person_outline)
            : icona(
                ios: CupertinoIcons.wifi_slash,
                android: Icons.wifi_off_rounded,
              ),
        errore: !nonCe,
        testo: errore is ErroreTrolley
            ? errore.messaggio
            : 'La parte pubblica si guarda con la connessione.',
      ).entra(context),
      if (!nonCe) ...[
        const SizedBox(height: 16),
        ConLaRete(
          builder: (context, rete) => PulsanteGrande(
            etichetta: 'Riprova',
            secondario: true,
            motivo: rete ? null : motivoSenzaRete,
            onPressed: _ricarica,
          ),
        ),
      ],
    ];
  }

  List<Widget> _profiloDi(ProfiloPubblico p) {
    final comune = inComuneInParole(
      inComune(mieMete: widget.mieMete, mieiGusti: widget.mieiGusti, altro: p),
    );
    return [
      NumeriDelProfilo(profilo: p).entra(context, ritardo: Ritmo.passo),
      if (p.gusti.isNotEmpty) ...[
        const SizedBox(height: 12),
        Semantics(
          label:
              'In viaggio ama: ${[for (final g in p.gusti) g.nome].join(', ')}',
          excludeSemantics: true,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final g in p.gusti) Pillola(g.nome.toUpperCase())],
          ),
        ).entra(context, ritardo: Ritmo.passo),
      ],
      if (comune != null) ...[
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'In comune: ',
                style: Testi.secondario.copyWith(
                  color: Colori.inchiostro,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: comune),
            ],
          ),
          style: Testi.secondario.copyWith(color: Colori.ardesia),
        ).entra(context, ritardo: Ritmo.passo),
      ],
      const SizedBox(height: 6),
      const EtichettaSezione('Viaggi chiusi'),
      if (p.viaggi.isEmpty)
        Text(
          'Nessun viaggio sul profilo, per ora.',
          style: Testi.secondario.copyWith(color: Colori.grafite),
        )
      else
        for (final (i, v) in p.viaggi.indexed) ...[
          BigliettoPubblico(viaggio: v)
              .entra(context, ritardo: Ritmo.passo * (i < 6 ? i + 2 : 8)),
          const SizedBox(height: 10),
        ],
      // Con il pulsante in basso la riga va lì sotto (tela, 73); quando il
      // pulsante dice altro, resta qui.
      if (p.collegamento != null) ...[
        const SizedBox(height: 8),
        Text(
          'I viaggi in programma o in corso non si vedono mai, di nessuno.',
          textAlign: TextAlign.center,
          style: Testi.didascalia.copyWith(color: Colori.grafite),
        ),
      ],
    ];
  }
}

/// In basso, a che punto siete (tela, 73, 112 e 113): Chiedi di collegarvi;
/// Richiesta inviata, che si tocca per ritirarla; la sua richiesta con
/// Accetta e Rifiuta; Scrivi.
class _InBasso extends StatelessWidget {
  const _InBasso({
    required this.nome,
    required this.utenteId,
    required this.collegamento,
    required this.onChiedi,
    required this.onRitira,
    required this.onScrivi,
    required this.onRisposto,
  });

  final String nome;
  final String utenteId;
  final Collegamento? collegamento;
  final VoidCallback onChiedi;
  final VoidCallback onRitira;
  final VoidCallback onScrivi;
  final ValueChanged<bool> onRisposto;

  @override
  Widget build(BuildContext context) {
    final c = collegamento;
    final sotto = switch (c?.stato) {
      null => 'I viaggi in programma o in corso non si vedono mai, di nessuno.',
      StatoCollegamento.collegati =>
        'Siete ${collegatiDa(c!.dal, DateTime.now())}. Da «…» lo togli '
            'quando vuoi.',
      StatoCollegamento.inviata =>
        'Se accetta, potrete scrivervi. Toccala per ritirarla.',
      StatoCollegamento.nonAccettata =>
        'La tua richiesta non è stata accettata. Puoi chiedere di nuovo.',
      StatoCollegamento.ricevuta =>
        'Rifiutare non glielo dice: vedrà solo che non è stata accettata.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c?.stato == StatoCollegamento.ricevuta)
          _Ricevuta(
            nome: nome,
            utenteId: utenteId,
            messaggio: c!.messaggio,
            onRisposto: onRisposto,
          )
        else
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: switch (c?.stato) {
                StatoCollegamento.collegati => 'Scrivi a $nome',
                StatoCollegamento.inviata => 'Richiesta inviata',
                StatoCollegamento.nonAccettata => 'Chiedi di nuovo',
                _ => 'Chiedi di collegarvi',
              },
              icona: switch (c?.stato) {
                StatoCollegamento.collegati => icona(
                  ios: CupertinoIcons.chat_bubble,
                  android: Icons.chat_bubble_outline,
                ),
                StatoCollegamento.inviata => icona(
                  ios: CupertinoIcons.checkmark,
                  android: Icons.check,
                ),
                _ => icona(
                  ios: CupertinoIcons.person_add,
                  android: Icons.person_add_alt,
                ),
              },
              secondario: c?.stato == StatoCollegamento.inviata,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: switch (c?.stato) {
                StatoCollegamento.collegati => onScrivi,
                StatoCollegamento.inviata => onRitira,
                _ => onChiedi,
              },
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            sotto,
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ),
      ],
    );
  }
}

/// «Andrea ti ha chiesto di collegarvi» (tela, 113): il suo messaggio, se
/// c'è, e Accetta o Rifiuta.
class _Ricevuta extends StatelessWidget {
  const _Ricevuta({
    required this.nome,
    required this.utenteId,
    required this.messaggio,
    required this.onRisposto,
  });

  final String nome;
  final String utenteId;
  final String? messaggio;
  final ValueChanged<bool> onRisposto;

  @override
  Widget build(BuildContext context) {
    final messaggio = this.messaggio;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colori.bianco,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colori.inchiostro.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$nome ti ha chiesto di collegarvi',
            style: Testi.evidenza.copyWith(
              fontSize: 15,
              color: Colori.inchiostro,
            ),
          ),
          if (messaggio != null) ...[
            const SizedBox(height: 8),
            MessaggioDellaRichiesta(messaggio),
          ],
          const SizedBox(height: 10),
          RispostaAllaRichiesta(
            utenteId: utenteId,
            nome: nome,
            onRisposto: onRisposto,
          ),
        ],
      ),
    );
  }
}

/// L'iniziale, il nome, da quando è su Trolley (tela, 73); se siete
/// collegati, lo dice (112).
class _Testata extends StatelessWidget {
  const _Testata({
    required this.nome,
    required this.dal,
    this.collegati = false,
  });

  final String nome;
  final DateTime? dal;
  final bool collegati;

  @override
  Widget build(BuildContext context) {
    final dal = this.dal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Avatar(nome: nome, dimensione: 68),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    nome,
                    style: Testi.titoli(24).copyWith(color: Colori.inchiostro),
                  ),
                ),
                if (dal != null)
                  Text(
                    suTrolleyDa(dal, DateTime.now()),
                    style: Testi.secondario.copyWith(color: Colori.grafite),
                  ),
                if (collegati) ...[
                  const SizedBox(height: 6),
                  const Pillola('COLLEGATI'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
