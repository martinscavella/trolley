/// La barra delle sezioni principali, uguale in ogni schermata che la porta:
/// Viaggi, Mappa, il «+», Community quando c'è, Profilo (tela, 74).
///
/// Community compare solo se l'ultima volta che il server l'ha detto la
/// parte pubblica c'era per questa persona — aperta, o chiusa ai nuovi; per
/// il team sempre — ed è maggiorenne (11, regola 1; 01, regola 2). Il
/// telefono lo ricorda (Archivio.osservaCommunity): la barra non aspetta la
/// rete per sapere che voci ha.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/barra.dart';
import '../aspetto/elementi.dart';
import '../aspetto/piattaforma.dart';
import '../dati/lettura.dart';
import '../dominio/mappa.dart';
import '../servizi.dart';
import 'community.dart';
import 'impostazioni.dart';
import 'mappa.dart';
import 'nuovo_viaggio.dart';

/// Quale sezione è aperta, se è una di quelle che stanno dopo il «+».
enum SezioneDopo { nessuna, community }

class BarraDelleSezioni extends StatelessWidget {
  const BarraDelleSezioni({
    super.key,
    required this.prima,
    this.attiva = SezioneDopo.nessuna,
    this.onAggiungi,
  });

  /// Viaggi e Mappa: cosa fanno dipende da dove si è.
  final List<VoceBarra> prima;
  final SezioneDopo attiva;

  /// Il «+»: un viaggio nuovo, se non si dice altro.
  final VoidCallback? onAggiungi;

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: Servizi.of(context).archivio.osservaCommunity(),
    builder: (context, community) => BarraPrincipale(
      prima: prima,
      dopo: [
        if (community.data == true || attiva == SezioneDopo.community)
          VoceBarra(
            icona: icona(
              ios: CupertinoIcons.person_2,
              android: Icons.group_outlined,
            ),
            etichetta: 'Community',
            attiva: attiva == SezioneDopo.community,
            onTap: attiva == SezioneDopo.community
                ? () {}
                : () => apri<void>(context, const SchermataCommunity()),
          ),
        VoceBarra(
          icona: icona(
            ios: CupertinoIcons.person,
            android: Icons.person_outline,
          ),
          etichetta: 'Profilo',
          onTap: () => apri<void>(context, const SchermataImpostazioni()),
        ),
      ],
      etichettaAggiungi: 'Nuovo viaggio',
      onAggiungi:
          onAggiungi ??
          () => apri<void>(
            context,
            const SchermataNuovoViaggio(),
            dalBasso: true,
          ),
    ),
  );
}

/// «Viaggi» da una schermata aperta sopra l'elenco: si torna all'elenco.
VoceBarra voceViaggi(BuildContext context, {bool attiva = false}) => VoceBarra(
  icona: icona(ios: CupertinoIcons.briefcase, android: Icons.luggage_outlined),
  etichetta: 'Viaggi',
  attiva: attiva,
  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
);

/// «Mappa» da dove non c'è un viaggio aperto: la mappa del viaggio che
/// conta oggi (dominio/mappa.dart, viaggioPerLaMappa).
VoceBarra voceMappa(BuildContext context) => VoceBarra(
  icona: icona(ios: CupertinoIcons.globe, android: Icons.public_rounded),
  etichetta: 'Mappa',
  onTap: () => apriLaMappa(context),
);

/// Apre la mappa del viaggio che conta oggi: quello in corso, o il prossimo;
/// fra due in corso, quello scelto oggi. Senza viaggi con le date lo dice.
Future<void> apriLaMappa(BuildContext context) async {
  final archivio = Servizi.of(context).archivio;
  final oggi = DateTime.now();
  final (viaggi, scelto) = await (
    archivio.osservaViaggiInElenco().first,
    archivio.viaggioSceltoOggi(oggi),
  ).wait;
  final id = viaggioPerLaMappa(
    viaggi: [for (final v in viaggi) v.viaggio],
    idDi: (v) => v.id,
    statoDi: (v) => v.statoA(oggi),
    inizioDi: (v) => v.inizio,
    sceltoOggi: scelto,
  );
  if (!context.mounted) return;
  if (id == null) {
    mostraMessaggio(
      context,
      'Sulla mappa vanno le tappe dei viaggi con le date: per ora non ce '
      'ne sono.',
    );
    return;
  }
  await apri<void>(context, SchermataMappa(viaggioId: id));
}
