/// Le due schede di «Viaggiatori» accanto a Cerca (5.4; tela, 77 e 111): i
/// collegamenti — le richieste ricevute, con Accetta e Rifiuta; i collegati;
/// le richieste mandate, in attesa o non accettate — e i messaggi, una riga
/// per conversazione.
///
/// Dipendono dalla rete come tutta la parte pubblica: le legge e le ricarica
/// la Community, che ne mostra i numeri sulle schede.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/collegamenti.dart';
import '../dominio/itinerario.dart';
import '../dominio/profilo_pubblico.dart';
import '../dominio/ricordo.dart';
import 'con_la_rete.dart';
import 'conversazione.dart';
import 'gesti_collegamenti.dart';
import 'viaggiatori.dart';

/// «Collegamenti» (tela, 77).
class ElencoCollegamenti extends StatelessWidget {
  const ElencoCollegamenti({
    super.key,
    required this.collegamenti,
    required this.mieMete,
    required this.mieiGusti,
    required this.onCambiato,
    required this.onProfilo,
    required this.onConversazione,
  });

  final Collegamenti collegamenti;

  /// Di chi guarda, per dire che cosa avete in comune.
  final List<Meta> mieMete;
  final Set<Interesse> mieiGusti;

  /// Dopo un gesto: si ricaricano i collegamenti.
  final VoidCallback onCambiato;
  final void Function(String utenteId, String nome) onProfilo;
  final void Function(String utenteId, String? nome) onConversazione;

  @override
  Widget build(BuildContext context) {
    final c = collegamenti;
    if (c.vuoti) {
      return Avviso(
        icona: icona(
          ios: CupertinoIcons.person_2,
          android: Icons.group_outlined,
        ),
        testo:
            'Nessun collegamento, per ora. Cerca chi viaggia come te e chiedi '
            'di collegarvi: se accetta, potrete scrivervi.',
      ).entra(context);
    }
    final adesso = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.ricevute.isNotEmpty) ...[
          EtichettaSezione(
            'Ricevute · ${c.ricevute.length}',
            colore: Colori.cobalto,
          ),
          for (final (i, r) in c.ricevute.indexed) ...[
            _Ricevuta(
              richiesta: r,
              inComune: r.profilo == null
                  ? null
                  : inComuneInParole(
                      inComune(
                        mieMete: mieMete,
                        mieiGusti: mieiGusti,
                        altro: r.profilo!,
                      ),
                    ),
              onProfilo: () => onProfilo(r.utenteId, r.nome),
              onCambiato: onCambiato,
            ).entra(context, ritardo: Ritmo.passo * i),
            const SizedBox(height: 10),
          ],
        ],
        if (c.collegati.isNotEmpty) ...[
          EtichettaSezione('Collegati · ${c.collegati.length}'),
          for (final p in c.collegati) ...[
            _RigaPersona(
              nome: p.nome,
              sotto: collegatiDa(p.dal, adesso),
              onTap: () => onConversazione(p.utenteId, p.nome),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (c.inviate.isNotEmpty) ...[
          EtichettaSezione('Inviate · ${c.inviate.length}'),
          for (final r in c.inviate) ...[
            _RigaPersona(
              nome: r.nome,
              sotto: statoInviata(r, adesso),
              onTap: () => onProfilo(r.utenteId, r.nome),
              azione: ConLaRete(
                builder: (context, rete) => _PulsanteRiga(
                  etichetta: r.accettata == false ? 'Togli' : 'Ritira',
                  descrizione: r.accettata == false
                      ? 'Togli la richiesta non accettata a ${r.nome}'
                      : 'Ritira la richiesta a ${r.nome}',
                  onPressed: rete
                      ? () async {
                          if (await ritiraRichiesta(context, r.utenteId)) {
                            onCambiato();
                          }
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Rifiutare non lo dice a nessuno: chi ha chiesto vede solo che non '
            'è stata accettata.',
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ),
      ],
    );
  }
}

/// Una richiesta ricevuta (tela, 77): chi, quando, che cosa avete in comune,
/// il suo messaggio, Accetta e Rifiuta. Toccando la persona si apre il suo
/// profilo.
class _Ricevuta extends StatelessWidget {
  const _Ricevuta({
    required this.richiesta,
    required this.inComune,
    required this.onProfilo,
    required this.onCambiato,
  });

  final RichiestaRicevuta richiesta;
  final String? inComune;
  final VoidCallback onProfilo;
  final VoidCallback onCambiato;

  @override
  Widget build(BuildContext context) {
    final r = richiesta;
    final sotto = [
      quantoFa(r.chiestaIl, DateTime.now()),
      if (inComune != null) '$inComune in comune',
    ].join(' · ');
    final messaggio = r.messaggio;
    return Pannello(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      raggio: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Premibile(
            onTap: onProfilo,
            scala: 0.99,
            etichetta: '${r.nome}, $sotto. Apri il profilo',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Avatar(nome: r.nome, dimensione: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.nome,
                          style: Testi.evidenza.copyWith(
                            color: Colori.inchiostro,
                          ),
                        ),
                        Text(
                          sotto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    icona(
                      ios: CupertinoIcons.chevron_forward,
                      android: Icons.chevron_right,
                    ),
                    size: 16,
                    color: Colori.grafite,
                  ),
                ],
              ),
            ),
          ),
          if (messaggio != null) ...[
            const SizedBox(height: 10),
            MessaggioDellaRichiesta(messaggio),
          ],
          const SizedBox(height: 10),
          RispostaAllaRichiesta(
            utenteId: r.utenteId,
            nome: r.nome,
            onRisposto: (_) => onCambiato(),
          ),
        ],
      ),
    );
  }
}

/// Il messaggio di una richiesta, in un riquadro grigio (tela, 77 e 113).
class MessaggioDellaRichiesta extends StatelessWidget {
  const MessaggioDellaRichiesta(this.testo, {super.key});

  final String testo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: Colori.foschia,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      testo,
      style: Testi.corpo.copyWith(
        fontSize: 15,
        height: 1.4,
        color: Colori.inchiostro,
      ),
    ),
  );
}

/// Accetta e Rifiuta, affiancati (tela, 77 e 113). [onRisposto] dice se si
/// è accettato.
class RispostaAllaRichiesta extends StatefulWidget {
  const RispostaAllaRichiesta({
    super.key,
    required this.utenteId,
    required this.nome,
    required this.onRisposto,
  });

  final String utenteId;
  final String nome;
  final ValueChanged<bool> onRisposto;

  @override
  State<RispostaAllaRichiesta> createState() => _RispostaAllaRichiestaState();
}

class _RispostaAllaRichiestaState extends State<RispostaAllaRichiesta> {
  bool _inCorso = false;

  Future<void> _rispondi(bool accetta) async {
    setState(() => _inCorso = true);
    final fatto = await rispondiA(
      context,
      utenteId: widget.utenteId,
      nome: widget.nome,
      accetta: accetta,
    );
    if (!mounted) return;
    setState(() => _inCorso = false);
    if (fatto) widget.onRisposto(accetta);
  }

  @override
  Widget build(BuildContext context) => ConLaRete(
    builder: (context, rete) {
      final attivo = rete && !_inCorso;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PulsanteMedio(
                  etichetta: 'Accetta',
                  descrizione: 'Accetta la richiesta di ${widget.nome}',
                  onPressed: attivo ? () => _rispondi(true) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulsanteMedio(
                  etichetta: 'Rifiuta',
                  descrizione: 'Rifiuta la richiesta di ${widget.nome}',
                  secondario: true,
                  onPressed: attivo ? () => _rispondi(false) : null,
                ),
              ),
            ],
          ),
          if (!rete) ...[
            const SizedBox(height: 6),
            Text(
              motivoSenzaRete,
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ],
      );
    },
  );
}

/// Un pulsante alto 44, d'inchiostro o bianco con il bordo (tela, 77).
class _PulsanteMedio extends StatelessWidget {
  const _PulsanteMedio({
    required this.etichetta,
    required this.descrizione,
    required this.onPressed,
    this.secondario = false,
  });

  final String etichetta;
  final String descrizione;
  final VoidCallback? onPressed;
  final bool secondario;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: onPressed != null,
    child: Premibile(
      onTap: onPressed,
      scala: 0.96,
      etichetta: descrizione,
      child: AnimatedOpacity(
        duration: Ritmo.breve,
        opacity: onPressed == null ? 0.35 : 1,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: secondario ? Colori.bianco : Colori.inchiostro,
            borderRadius: BorderRadius.circular(14),
            border: secondario
                ? Border.all(color: Colori.cenere, width: 2)
                : null,
          ),
          child: Text(
            etichetta,
            style: Testi.pulsante.copyWith(
              fontSize: 15,
              color: secondario ? Colori.inchiostro : Colori.bianco,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Un pulsante bianco e piccolo dentro una riga: «Ritira», «Togli».
class _PulsanteRiga extends StatelessWidget {
  const _PulsanteRiga({
    required this.etichetta,
    required this.descrizione,
    required this.onPressed,
  });

  final String etichetta;
  final String descrizione;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onPressed,
    scala: 0.94,
    etichetta: descrizione,
    child: Opacity(
      opacity: onPressed == null ? 0.35 : 1,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colori.bianco,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colori.cenere, width: 2),
        ),
        child: Text(
          etichetta,
          style: Testi.secondario.copyWith(
            color: Colori.inchiostro,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// Una persona in una riga bianca (tela, 77): l'iniziale, il nome, sotto
/// come state, a destra un'azione o la freccia.
class _RigaPersona extends StatelessWidget {
  const _RigaPersona({
    required this.nome,
    required this.sotto,
    required this.onTap,
    this.azione,
  });

  final String nome;
  final String sotto;
  final VoidCallback onTap;
  final Widget? azione;

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Premibile(
            onTap: onTap,
            scala: 0.99,
            etichetta: '$nome, $sotto',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Avatar(nome: nome, dimensione: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.evidenza.copyWith(
                            color: Colori.inchiostro,
                          ),
                        ),
                        Text(
                          sotto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Testi.didascalia.copyWith(
                            color: Colori.grafite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (azione == null)
                    Icon(
                      icona(
                        ios: CupertinoIcons.chevron_forward,
                        android: Icons.chevron_right,
                      ),
                      size: 16,
                      color: Colori.grafite,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (azione != null) ...[const SizedBox(width: 10), azione!],
      ],
    ),
  );
}

// ─── Messaggi ─────────────────────────────────────────────────────────────

/// «Messaggi» (tela, 111): una riga per conversazione, dalla più recente.
class ElencoConversazioni extends StatelessWidget {
  const ElencoConversazioni({
    super.key,
    required this.righe,
    required this.onApri,
  });

  final List<RigaConversazione> righe;
  final void Function(String utenteId, String? nome) onApri;

  @override
  Widget build(BuildContext context) {
    if (righe.isEmpty) {
      return Avviso(
        icona: icona(
          ios: CupertinoIcons.chat_bubble_2,
          android: Icons.forum_outlined,
        ),
        testo:
            'Nessuna conversazione, per ora. Si scrive solo a chi è collegato: '
            'quando una richiesta è accettata, la conversazione è qui.',
      ).entra(context);
    }
    final adesso = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        for (final (i, r) in righe.indexed) ...[
          _RigaConversazione(
            riga: r,
            adesso: adesso,
            onTap: () => onApri(r.utenteId, r.nome),
          ).entra(context, ritardo: Ritmo.passo * (i < 8 ? i : 8)),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Text(
            'Si scrive solo a chi è collegato. I messaggi arrivano mentre '
            'Trolley è aperta.',
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
        ),
      ],
    );
  }
}

/// Una conversazione (tela, 111): i non letti in cobalto con il numero; una
/// finita in grigio.
class _RigaConversazione extends StatelessWidget {
  const _RigaConversazione({
    required this.riga,
    required this.adesso,
    required this.onTap,
  });

  final RigaConversazione riga;
  final DateTime adesso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = riga;
    final nome = nomeOAccountChiuso(r.nome);
    final quando = r.quando == null ? null : quandoInElenco(r.quando!, adesso);
    final nuovi = r.daLeggere > 0;
    final finita = !r.collegati;
    final testo = anteprima(r);
    return Premibile(
      onTap: onTap,
      scala: 0.99,
      etichetta: [
        nome,
        testo,
        ?quando,
        if (nuovi) quanti(r.daLeggere, 'da leggere', 'da leggere'),
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: finita ? Colori.foschia : Colori.bianco,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              AvatarConversazione(nome: r.nome),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.evidenza.copyWith(
                        color: finita ? Colori.grafite : Colori.inchiostro,
                      ),
                    ),
                    Text(
                      testo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Testi.secondario.copyWith(
                        color: nuovi ? Colori.inchiostro : Colori.grafite,
                        fontWeight: nuovi ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (quando != null)
                    Text(
                      quando,
                      style: Testi.didascalia.copyWith(
                        color: nuovi ? Colori.cobalto : Colori.grafite,
                        fontWeight: nuovi ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (nuovi)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colori.cobalto,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${r.daLeggere}',
                        style: Testi.didascalia.copyWith(
                          color: Colori.bianco,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
