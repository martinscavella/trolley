/// Segnalare, e le proprie segnalazioni (5.1; 12, regole 1, 2 e 6; tela, 70 e
/// 71). Si segnala in due tocchi da dove si sta guardando: un profilo (5.3),
/// un messaggio (5.4), con «…». Chi segnala riceve conferma, e poi vede quando
/// è stata gestita. Chi è segnalato non lo sa.
///
/// Richiede la rete. Gli eventi `segnalazione_ricevuta` e
/// `segnalazione_gestita` li scrive il server; qui si misura il blocco che
/// parte con la segnalazione (`persona_bloccata`).
library;

import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/errori.dart';
import '../dominio/parte_pubblica.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';

/// Come si dice un motivo (tela, 70).
String etichettaMotivo(MotivoSegnalazione m) => switch (m) {
  MotivoSegnalazione.molestie => 'Messaggi molesti o minacce',
  MotivoSegnalazione.falso => 'Profilo falso',
  MotivoSegnalazione.inappropriato => 'Contenuti inappropriati',
  MotivoSegnalazione.minore => 'Potrebbe avere meno di 18 anni',
  MotivoSegnalazione.altro => 'Altro',
};

/// Apre «Segnala» per [oggettoId] — un profilo, un messaggio — di [nome], la
/// persona [utenteId]. Mandata, mostra che è arrivata.
Future<void> segnala(
  BuildContext context, {
  required TipoSegnalato tipo,
  required String oggettoId,
  required String utenteId,
  required String nome,
}) async {
  final mandata = await apriFoglio<bool>(
    context,
    _FoglioSegnala(
      tipo: tipo,
      oggettoId: oggettoId,
      utenteId: utenteId,
      nome: nome,
    ),
  );
  if (mandata == true && context.mounted) {
    await apri<void>(
      context,
      const SchermataSegnalazioni(appenaArrivata: true),
    );
  }
}

/// «Segnala Luca» (tela, 70): motivi fissi, una nota facoltativa, e «Blocca
/// anche» già acceso.
class _FoglioSegnala extends StatefulWidget {
  const _FoglioSegnala({
    required this.tipo,
    required this.oggettoId,
    required this.utenteId,
    required this.nome,
  });

  final TipoSegnalato tipo;
  final String oggettoId;
  final String utenteId;
  final String nome;

  @override
  State<_FoglioSegnala> createState() => _FoglioSegnalaState();
}

class _FoglioSegnalaState extends State<_FoglioSegnala> {
  /// Nasce con il foglio: rimandarla dopo una risposta persa non la duplica.
  final _id = const Uuid().v4();
  final _nota = TextEditingController();
  MotivoSegnalazione? _motivo;
  bool _blocca = true;
  bool _inCorso = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _manda() async {
    final motivo = _motivo;
    if (motivo == null) return;
    final servizi = Servizi.of(context);
    setState(() => _inCorso = true);
    try {
      await servizi.partePubblica.segnala(
        id: _id,
        tipo: widget.tipo,
        oggettoId: widget.oggettoId,
        motivo: motivo,
        nota: _nota.text,
        blocca: _blocca,
        misurazione: await servizi.misurazione.attiva,
      );
      if (_blocca) {
        await servizi.misurazione.registra(Eventi.personaBloccata, {
          'da': 'segnalazione',
        });
      }
      unawaited(servizi.misurazione.invia());
      if (mounted) Navigator.of(context).pop(true);
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      mostraMessaggio(context, e.messaggio, errore: true);
    }
  }

  @override
  Widget build(BuildContext context) => Foglio(
    titolo: 'Segnala ${widget.nome}',
    inBasso: ConLaRete(
      builder: (context, rete) => PulsanteGrande(
        etichetta: 'Invia la segnalazione',
        inCorso: _inCorso,
        motivo: !rete
            ? motivoSenzaRete
            : _motivo == null
            ? 'Scegli un motivo.'
            : null,
        onPressed: _manda,
      ),
    ),
    children: [
      Text(
        'La legge solo chi modera. ${widget.nome} non viene avvisato, e non '
        'saprà da chi arriva.',
        style: Testi.secondario.copyWith(color: Colori.grafite),
      ),
      const SizedBox(height: 10),
      for (final m in MotivoSegnalazione.values)
        _Motivo(
          etichetta: etichettaMotivo(m),
          scelto: _motivo == m,
          onTap: () => setState(() => _motivo = m),
        ),
      const SizedBox(height: 12),
      Campo(
        controller: _nota,
        segnaposto: 'Vuoi aggiungere qualcosa? Facoltativo',
        righe: 2,
        lunghezzaMassima: 500,
        maiuscole: TextCapitalization.sentences,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              'Blocca anche ${widget.nome}',
              style: Testi.evidenza.copyWith(color: Colori.inchiostro),
            ),
          ),
          AdaptiveSwitch(
            value: _blocca,
            onChanged: (v) => setState(() => _blocca = v),
          ),
        ],
      ),
    ],
  );
}

/// Una riga dei motivi: si sceglie uno solo.
class _Motivo extends StatelessWidget {
  const _Motivo({
    required this.etichetta,
    required this.scelto,
    required this.onTap,
  });

  final String etichetta;
  final bool scelto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: scelto,
    child: Premibile(
      onTap: onTap,
      scala: 0.99,
      etichetta: etichetta,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEF0F4), width: 1.5)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Ritmo.breve,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scelto ? Colori.inchiostro : Colori.cenere,
                  width: scelto ? 7 : 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                etichetta,
                style: Testi.corpo.copyWith(
                  color: Colori.inchiostro,
                  fontWeight: scelto ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// «Le tue segnalazioni» (tela, 71): ricevute o gestite, con l'esito. Appena
/// mandata una, in cima dice che è arrivata.
class SchermataSegnalazioni extends StatefulWidget {
  const SchermataSegnalazioni({super.key, this.appenaArrivata = false});

  final bool appenaArrivata;

  @override
  State<SchermataSegnalazioni> createState() => _SchermataSegnalazioniState();
}

class _SchermataSegnalazioniState extends State<SchermataSegnalazioni> {
  Future<List<Segnalazione>>? _segnalazioni;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _segnalazioni ??= Servizi.of(context).partePubblica.leMieSegnalazioni();
  }

  void _ricarica() => setState(() {
    _segnalazioni = Servizi.of(context).partePubblica.leMieSegnalazioni();
  });

  @override
  Widget build(BuildContext context) {
    final contatto = Servizi.of(context).archivio.osservaContattoModerazione();
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
            if (widget.appenaArrivata) ...[
              const _Arrivata().entra(context),
              const SizedBox(height: 8),
              const EtichettaSezione('Le tue segnalazioni'),
            ] else
              const TitoloPagina(
                'Le tue segnalazioni',
                sottotitolo:
                    'Le legge solo chi modera. Chi hai segnalato non lo sa.',
              ).entra(context),
            FutureBuilder<List<Segnalazione>>(
              future: _segnalazioni,
              builder: (context, lette) {
                if (lette.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: IndicatoreAttivita()),
                  );
                }
                if (lette.hasError) {
                  return Avviso(
                    icona: icona(
                      ios: CupertinoIcons.wifi_slash,
                      android: Icons.wifi_off_rounded,
                    ),
                    errore: true,
                    testo: lette.error is ErroreTrolley
                        ? (lette.error! as ErroreTrolley).messaggio
                        : 'Le segnalazioni si guardano con la connessione.',
                    azioni: [
                      ConLaRete(
                        builder: (context, rete) => PulsantePiccolo(
                          etichetta: 'Riprova',
                          onPressed: rete ? _ricarica : null,
                        ),
                      ),
                    ],
                  );
                }
                final elenco = lette.data!;
                if (elenco.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Non hai fatto segnalazioni.',
                      style: Testi.secondario.copyWith(color: Colori.grafite),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final (i, s) in elenco.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RigaSegnalazione(segnalazione: s)
                            .entra(context, ritardo: Ritmo.passo * (i + 1)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<String?>(
              stream: contatto,
              builder: (context, letto) => Avviso(
                icona: icona(
                  ios: CupertinoIcons.checkmark_shield,
                  android: Icons.verified_user_outlined,
                ),
                inizio: letto.data == null
                    ? 'Se sei in pericolo,'
                    : 'Per un\'urgenza',
                testo: letto.data == null
                    ? 'chiama il 112.'
                    : 'scrivi a ${letto.data}. Se sei in pericolo, chiama il '
                          '112.',
              ),
            ),
            const SizedBox(height: 12),
            Avviso(
              icona: icona(
                ios: CupertinoIcons.person_2,
                android: Icons.group_outlined,
              ),
              testo:
                  'Se la persona che hai segnalato è in un tuo viaggio, chi '
                  'ne è responsabile può toglierla.',
            ),
          ],
        ),
      ),
    );
  }
}

/// «È arrivata» (tela, 71).
class _Arrivata extends StatelessWidget {
  const _Arrivata();

  @override
  Widget build(BuildContext context) => Pannello(
    raggio: 22,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colori.menta,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icona(
              ios: CupertinoIcons.checkmark_alt,
              android: Icons.check_rounded,
            ),
            size: 22,
            color: Colori.verde,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'È arrivata',
                  style: Testi.titoli(20).copyWith(color: Colori.inchiostro),
                ),
              ),
              Text(
                'Ti diciamo quando l\'abbiamo gestita.',
                style: Testi.secondario.copyWith(color: Colori.grafite),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Una segnalazione: chi o che cosa, quando, e come è finita.
class _RigaSegnalazione extends StatelessWidget {
  const _RigaSegnalazione({required this.segnalazione});

  final Segnalazione segnalazione;

  @override
  Widget build(BuildContext context) {
    final s = segnalazione;
    final titolo = switch (s.tipo) {
      TipoSegnalato.profilo => '${s.nome} · un profilo',
      TipoSegnalato.messaggio => 'Un messaggio',
    };
    final come = switch (s.esito) {
      null => 'Ricevuta ${quandoAggiornato(s.creataIl, DateTime.now())}',
      final esito =>
        'Gestita il ${dataBreve(s.gestitaIl!.toLocal())}: ${_esito(esito)}',
    };
    return Semantics(
      container: true,
      label: '$titolo. $come.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              if (s.tipo == TipoSegnalato.profilo)
                Avatar(nome: s.nome, dimensione: 40)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colori.foschia,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icona(
                      ios: CupertinoIcons.chat_bubble,
                      android: Icons.chat_bubble_outline,
                    ),
                    size: 22,
                    color: Colori.grafite,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                    ),
                    Text(
                      come,
                      style: Testi.didascalia.copyWith(color: Colori.grafite),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pillola(
                s.gestita ? 'GESTITA' : 'RICEVUTA',
                colore: s.gestita ? Colori.verde : Colori.grafite,
                fondo: s.gestita ? Colori.menta : Colori.foschia,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _esito(EsitoSegnalazione e) => switch (e) {
    EsitoSegnalazione.nessunaAzione => 'non abbiamo trovato violazioni',
    EsitoSegnalazione.contenutoRimosso => 'il messaggio è stato tolto',
    EsitoSegnalazione.profiloSospeso => 'il profilo è stato sospeso',
  };
}
