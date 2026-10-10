/// Il profilo pubblico di un altro viaggiatore (5.3; tela, 73): i numeri,
/// cosa ama in viaggio, cosa avete in comune, i viaggi chiusi e finiti che ha
/// lasciato sul profilo — la meta, il mese, i giorni. Da «…» si segnala o si
/// blocca, in due tocchi (12, regola 1).
///
/// Dipende dalla rete, e non resta sul telefono. Se il profilo non si vede
/// più — spento, sospeso, bloccato — il server dice solo che non c'è.
/// «Chiedi di collegarvi» arriva con la 5.4.
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
import '../dominio/itinerario.dart';
import '../dominio/parte_pubblica.dart';
import '../dominio/profilo_pubblico.dart';
import '../dominio/ricordo.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
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

  Future<void> _menu(String nome) => scegliAzione(context, [
    AzioneMenu('Segnala $nome', () => _segnala(nome)),
    AzioneMenu('Blocca $nome', () => _blocca(nome), pericolo: true),
  ]);

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
      return Pagina(
        azioni: [
          if (profilo != null)
            ConLaRete(
              builder: (context, rete) => PulsanteTondo(
                icona: icona(
                  ios: CupertinoIcons.ellipsis,
                  android: Icons.more_horiz,
                ),
                etichetta: 'Segnala o blocca',
                onPressed: rete ? () => _menu(nome) : null,
              ),
            ),
        ],
        corpo: Builder(
          builder: (context) {
            final padding = EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top,
              20,
              MediaQuery.paddingOf(context).bottom + 32,
            );
            return ListView(
              padding: padding,
              children: [
                _Testata(nome: nome, dal: profilo?.dal).entra(context),
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
      const SizedBox(height: 8),
      Text(
        'I viaggi in programma o in corso non si vedono mai, di nessuno.',
        textAlign: TextAlign.center,
        style: Testi.didascalia.copyWith(color: Colori.grafite),
      ),
    ];
  }
}

/// L'iniziale, il nome, da quando è su Trolley (tela, 73).
class _Testata extends StatelessWidget {
  const _Testata({required this.nome, required this.dal});

  final String nome;
  final DateTime? dal;

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
