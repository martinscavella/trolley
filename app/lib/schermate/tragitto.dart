/// Il mezzo di un tragitto (04, regole 34–39; ADR-015): come si arriva a una
/// tappa dalla tappa prima. Si sceglie nel foglio della tappa, «Come ci
/// arrivi?» (tela, 170), o durante la guida (tela, 171–172); la pillola
/// sulla giornata lo mostra soltanto (tela, 166).
///
/// I tempi sono stime di Trolley, dalla distanza e dal mezzo: si vedono anche
/// senza rete.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/mezzi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dominio/tragitti.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'due_versioni.dart';

/// Da dove si è scelto il mezzo, per `tragitto_sistemato` (07).
enum DaDove {
  /// Dal foglio della tappa, «Come ci arrivi?».
  tappa,

  /// Durante la guida.
  guida,
}

/// `tragitto_sistemato` (07): il mezzo scelto e quello di prima, da dove, e
/// se prima ci si stava. Mai le tappe, mai dove, mai i tempi.
Future<void> registraIlMezzo(
  Servizi servizi, {
  required String viaggioId,
  required Mezzo mezzo,
  required Mezzo? prima,
  required DaDove da,
  bool nonCiStava = false,
}) async {
  await servizi.misurazione.registra(Eventi.tragittoSistemato, {
    'viaggio_id': viaggioId,
    'mezzo': mezzo.codice,
    'prima': prima?.codice ?? 'nessuno',
    'da': da.name,
    'non_ci_stava': nonCiStava,
  });
  unawaited(servizi.misurazione.invia());
}

/// Scrive il mezzo nella tappa, con la sua versione: due versioni si
/// mostrano come per gli altri campi. Vuole la rete, come cambiare una
/// tappa. `true` se il server l'ha scritto.
Future<bool> scriviIlMezzo(
  BuildContext context,
  Tappa tappa,
  Mezzo mezzo,
) async {
  final archivio = Servizi.of(context).archivio;
  try {
    final scelta = await salvaOScegli(
      context,
      () => archivio.modificaTappa(tappa, {'mezzo': mezzo.codice}),
    );
    return scelta != null;
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
    return false;
  }
}

/// «Come ci arrivi?» nel foglio della tappa (tela, 170): da quale tappa, la
/// distanza, i sei mezzi come gettoni con la stima. Ritoccare quello scelto
/// lo toglie.
class ComeCiArrivi extends StatelessWidget {
  const ComeCiArrivi({
    super.key,
    required this.tragitto,
    required this.da,
    required this.onScegli,
  });

  /// Il tragitto con il mezzo scelto nel foglio.
  final Tragitto tragitto;

  /// Il titolo della tappa prima.
  final String da;

  /// `null` per togliere il mezzo.
  final ValueChanged<Mezzo?> onScegli;

  @override
  Widget build(BuildContext context) {
    final t = tragitto;
    final scelto = t.mezzo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colori.foschia,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Come ci arrivi?',
                  style: Testi.evidenza.copyWith(
                    color: Colori.inchiostro,
                    fontSize: 15,
                  ),
                ),
              ),
              if (t.metri != null)
                Text(
                  '${distanza(t.metri!)} in linea d\'aria',
                  style: Testi.didascalia.copyWith(
                    color: Colori.grafite,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Da $da, che finisce alle ${ora(t.partenza)}',
            style: Testi.didascalia.copyWith(color: Colori.ardesia),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Mezzo.values)
                Gettone(
                  key: ValueKey('mezzo-${m.codice}'),
                  etichetta: nomeMezzo(m),
                  simbolo: iconaMezzo(m),
                  aggiunta: switch (t.stima(m)) {
                    final s? => durataBreve(s),
                    null => null,
                  },
                  aggiuntaInRosso: (t.stima(m) ?? Duration.zero) > t.spazio,
                  scelto: m == scelto,
                  onTap: () => onScegli(m == scelto ? null : m),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (t.nonCiStai) ...[
            Text(
              'Non ci stai: fra le due tappe ci sono '
              '${durataBreve(t.spazio)}, ${mezzoInFrase(scelto!)} ne servono '
              '${circa(t.stima()!)}. Non blocca niente.',
              style: Testi.didascalia.copyWith(
                color: Colori.pericolo,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            t.metri == null
                ? 'Senza il posto di tutte e due le tappe Trolley non sa '
                      'quanto ci vuole. Il mezzo vale per tutti quelli del '
                      'viaggio.'
                : 'Tempi stimati da Trolley. Il mezzo vale per tutti quelli '
                      'del viaggio; tocca quello scelto per toglierlo.',
            style: Testi.didascalia.copyWith(
              color: Colori.grafite,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Come ci vai?» dalla guida (tela, 172): i sei mezzi, due per riga, con
/// il tempo stimato di ognuno da dove si è. Chiude restituendo il mezzo.
class FoglioMezzoDellaGuida extends StatelessWidget {
  const FoglioMezzoDellaGuida({
    super.key,
    required this.a,
    required this.scelto,
    this.metri,
  });

  /// Il titolo della tappa.
  final String a;
  final Mezzo scelto;

  /// Da dove si è alla tappa, in linea d'aria; `null` se non si sa.
  final double? metri;

  @override
  Widget build(BuildContext context) => Foglio(
    titolo: 'Come ci vai?',
    inBasso: const PulsanteAnnulla(),
    children: [
      Text(
        [
          'A $a, da dove sei',
          if (metri != null) '${distanza(metri!)} in linea d\'aria',
        ].join(' · '),
        style: Testi.corpo.copyWith(color: Colori.ardesia),
      ),
      const SizedBox(height: 14),
      GrigliaMezzi(
        scelto: scelto,
        stima: (m) => metri == null ? null : m.stima(metri!),
        nota: (m) => switch (m) {
          Mezzo.mezzi => 'Il percorso a passi',
          Mezzo.monopattino => 'Guida come in bici',
          Mezzo.taxi => 'Guida come in auto',
          _ => null,
        },
        onScegli: (m) => Navigator.of(context).pop(m == scelto ? null : m),
      ),
      const SizedBox(height: 12),
      Text(
        'Cambiandolo la strada si ricalcola, e il mezzo resta nella tappa '
        'per tutti quelli del viaggio.',
        style: Testi.didascalia.copyWith(color: Colori.grafite),
      ),
    ],
  );
}

/// I sei mezzi, due per riga, con il tempo stimato di ognuno (tela, 172).
class GrigliaMezzi extends StatelessWidget {
  const GrigliaMezzi({
    super.key,
    required this.scelto,
    required this.stima,
    required this.onScegli,
    this.nota,
  });

  final Mezzo? scelto;
  final Duration? Function(Mezzo m) stima;
  final String? Function(Mezzo m)? nota;
  final ValueChanged<Mezzo>? onScegli;

  @override
  Widget build(BuildContext context) {
    final righe = <Widget>[];
    const mezzi = Mezzo.values;
    for (var i = 0; i < mezzi.length; i += 2) {
      if (i > 0) righe.add(const SizedBox(height: 8));
      righe.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tessera(mezzi[i])),
              const SizedBox(width: 8),
              Expanded(child: _tessera(mezzi[i + 1])),
            ],
          ),
        ),
      );
    }
    return Column(children: righe);
  }

  Widget _tessera(Mezzo m) {
    final scelto = m == this.scelto;
    final stima = this.stima(m);
    final nota = this.nota?.call(m);
    final spento = onScegli == null;
    return Semantics(
      selected: scelto,
      button: true,
      enabled: !spento,
      child: Premibile(
        onTap: spento ? null : () => onScegli!(m),
        etichetta: [
          nomeMezzo(m),
          if (stima != null) circa(stima),
          ?nota,
          if (scelto) 'scelto',
        ].join(', '),
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: scelto ? Colori.cobaltoChiaro : Colori.foschia,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scelto ? Colori.cobalto : Colori.foschia,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colori.bianco,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconaMezzo(m), size: 20, color: Colori.cobalto),
                ),
                const SizedBox(height: 6),
                Text(
                  nomeMezzo(m),
                  style: Testi.corpo.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colori.inchiostro,
                  ),
                ),
                if (stima != null)
                  Text(
                    circa(stima),
                    style: Testi.didascalia.copyWith(color: Colori.grafite),
                  ),
                if (nota != null)
                  Text(
                    nota,
                    style: Testi.didascalia.copyWith(
                      color: Colori.cobaltoScuro,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
