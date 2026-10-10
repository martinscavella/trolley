/// «Viaggi sul profilo» (5.3; tela, 109): quali viaggi chiusi stanno sul
/// profilo pubblico, uno per uno (11, regola 2; 5.2, M3). Gli altri ne vedono
/// la meta, il mese e i giorni, mai con chi si era né che cosa si è fatto.
/// Ci si arriva da «Così ti vedono» e, prima di accendere il profilo, dalla
/// schermata che lo accende.
///
/// Dipende dalla rete: la scelta sta sul server, e ogni interruttore la
/// scrive subito. Non ha un evento: nessuna soglia lo chiede (07, regola 2).
library;

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
import '../dati/errori.dart';
import '../dominio/profilo_pubblico.dart';
import '../servizi.dart';
import 'con_la_rete.dart';
import 'viaggiatori.dart';

class SchermataViaggiSulProfilo extends StatefulWidget {
  const SchermataViaggiSulProfilo({super.key});

  @override
  State<SchermataViaggiSulProfilo> createState() =>
      _SchermataViaggiSulProfiloState();
}

class _SchermataViaggiSulProfiloState extends State<SchermataViaggiSulProfilo> {
  List<ViaggioPubblico>? _viaggi;
  Object? _errore;
  bool _letto = false;

  /// I viaggi che si stanno scrivendo: il loro interruttore aspetta.
  final _inCorso = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_letto) _leggi();
  }

  Future<void> _leggi() async {
    _letto = true;
    if (_errore != null) setState(() => _errore = null);
    try {
      final mio = await Servizi.of(context).partePubblica.ilMioProfilo();
      if (mounted) setState(() => _viaggi = mio?.tuttiIViaggi ?? const []);
    } on Object catch (e) {
      if (mounted) setState(() => _errore = e);
    }
  }

  Future<void> _cambia(ViaggioPubblico v, bool mostra) async {
    final id = v.viaggioId;
    if (id == null) return;
    final servizi = Servizi.of(context);
    setState(() {
      _inCorso.add(id);
      _viaggi = [
        for (final x in _viaggi!)
          x.viaggioId == id ? x.conSulProfilo(mostra) : x,
      ];
    });
    try {
      await servizi.partePubblica.mostraSulProfilo(id, mostra: mostra);
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      mostraMessaggio(context, e.messaggio, errore: true);
      setState(() {
        _viaggi = [
          for (final x in _viaggi!)
            x.viaggioId == id ? x.conSulProfilo(!mostra) : x,
        ];
      });
    }
    if (mounted) setState(() => _inCorso.remove(id));
  }

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) {
        final viaggi = _viaggi;
        final errore = _errore;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            const TitoloPagina(
              'Viaggi sul profilo',
              sottotitolo:
                  'Gli altri vedono la meta, il mese e i giorni. Mai con chi '
                  'eri, né che cosa hai fatto lì.',
            ).entra(context),
            if (errore != null) ...[
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.wifi_slash,
                  android: Icons.wifi_off_rounded,
                ),
                errore: true,
                testo: errore is ErroreTrolley
                    ? errore.messaggio
                    : 'La parte pubblica si guarda con la connessione.',
              ),
              const SizedBox(height: 16),
              ConLaRete(
                builder: (context, rete) => PulsanteGrande(
                  etichetta: 'Riprova',
                  secondario: true,
                  motivo: rete ? null : motivoSenzaRete,
                  onPressed: _leggi,
                ),
              ),
            ] else if (viaggi == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: IndicatoreAttivita()),
              )
            else if (viaggi.isEmpty)
              Avviso(
                icona: icona(
                  ios: CupertinoIcons.tickets,
                  android: Icons.confirmation_number_outlined,
                ),
                testo:
                    'Non hai ancora viaggi chiusi. Compariranno qui dopo la '
                    'loro fine, e sceglierai tu se mostrarli.',
              ).entra(context, ritardo: Ritmo.passo)
            else ...[
              EtichettaSezione(
                '${viaggi.where((v) => v.sulProfilo).length} di '
                '${viaggi.length} sul profilo',
              ),
              ConLaRete(
                builder: (context, rete) => Pannello(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (final (i, v) in viaggi.indexed)
                        _RigaViaggio(
                          viaggio: v,
                          primo: i == 0,
                          sotto: rete ? null : motivoSenzaRete,
                          onCambia: rete && !_inCorso.contains(v.viaggioId)
                              ? (mostra) => _cambia(v, mostra)
                              : null,
                        ),
                    ],
                  ),
                ),
              ).entra(context, ritardo: Ritmo.passo),
            ],
            const SizedBox(height: 14),
            Text(
              'I viaggi in programma o in corso non compaiono mai. Uno chiuso '
              'prima della fine compare dopo la fine.',
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        );
      },
    ),
  );
}

/// Un viaggio con il suo interruttore (tela, 109): il codice in un gettone
/// d'inchiostro, tratteggiato se è importato.
class _RigaViaggio extends StatelessWidget {
  const _RigaViaggio({
    required this.viaggio,
    required this.primo,
    required this.onCambia,
    this.sotto,
  });

  final ViaggioPubblico viaggio;
  final bool primo;
  final ValueChanged<bool>? onCambia;
  final String? sotto;

  @override
  Widget build(BuildContext context) {
    final v = viaggio;
    final meta = metaPubblica(v);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: primo
          ? null
          : const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFEEF0F4), width: 1.5),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: v.importato ? Colori.bianco : Colori.inchiostro,
              borderRadius: BorderRadius.circular(10),
              border: v.importato
                  ? Border.all(color: Colori.piombo, width: 2)
                  : null,
            ),
            child: ExcludeSemantics(
              child: Text(
                codiceDestinazione(meta),
                style: Testi.codice(12).copyWith(
                  color: v.importato ? Colori.inchiostro : Colori.bianco,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta,
                  style: Testi.evidenza.copyWith(color: Colori.inchiostro),
                ),
                Text(
                  sotto ??
                      (v.importato
                          ? '${quandoPubblico(v)} · importato'
                          : quandoPubblico(v)),
                  style: Testi.didascalia.copyWith(color: Colori.grafite),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: '$meta sul profilo',
            child: AdaptiveSwitch(value: v.sulProfilo, onChanged: onCambia),
          ),
        ],
      ),
    );
  }
}
