/// I gesti sulle spese che contano per la misurazione, in un posto solo: le
/// schermate li chiamano da qui così che nessuno dimentichi l'evento.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../dati/coda.dart';
import '../dati/database.dart';
import '../dati/lettura.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';

/// Registra una spesa: chi l'ha pagata (chi la registra, se non si dice
/// altro) e per chi è. Funziona anche senza rete: è uno dei gesti della coda
/// (02 §2). Con i suoi eventi (07): il primo elemento del viaggio (H2), la
/// funzione usata (H1), il primo contributo di chi è stato invitato (H3).
/// Dividerla non ha un evento suo: è dentro registrarla.
Future<void> registraLaSpesa(
  BuildContext context, {
  required Viaggio viaggio,
  required int centesimi,
  required String valuta,
  required DateTime data,
  String? descrizione,
  String? pagante,
  Map<String, int> quote = const {},
}) async {
  final servizi = Servizi.of(context);
  final archivio = servizi.archivio;
  final misurazione = servizi.misurazione;
  final v = viaggio.id;
  final io = archivio.io;
  if (io == null) return;
  final (tappe, spese, documenti, voci, tassi, ruolo) = await (
    archivio.osservaTappe(v).first,
    archivio.osservaSpese(v).first,
    servizi.documenti.osserva(v).first,
    archivio.osservaVoci(v).first,
    archivio.osservaTassi().first,
    archivio.mioRuolo(v),
  ).wait;

  final (tassoUsato, tassoAl) = _tassoDi(valuta, tassi);
  await archivio.coda.registraSpesa(
    NuovaSpesa(
      id: const Uuid().v4(),
      viaggioId: v,
      centesimi: centesimi,
      valuta: valuta,
      paganteId: pagante ?? io,
      data: data,
      descrizione: descrizione,
      tassoUsato: tassoUsato,
      tassoAl: tassoAl,
      quote: quote,
    ),
  );
  HapticFeedback.lightImpact();

  if (tappe.isEmpty && spese.isEmpty && documenti.isEmpty && voci.isEmpty) {
    await misurazione.registraUnaVolta(
      'primo_elemento:$v',
      Eventi.primoElementoAggiunto,
      {
        'viaggio_id': v,
        'tipo': 'spesa',
        'ore_dalla_creazione': DateTime.now()
            .toUtc()
            .difference(viaggio.creato.toUtc())
            .inHours,
      },
    );
  }
  await misurazione.registraUnaVolta(
    'funzione:spese:$v',
    Eventi.funzioneUsataNelViaggio,
    {'viaggio_id': v, 'funzione': 'spese'},
  );
  if (ruolo == 'partecipante' &&
      documenti.isEmpty &&
      !tappe.any((t) => t.creatoDa == io) &&
      !spese.any((s) => s.creatoDa == io) &&
      !voci.any((x) => x.creatoDa == io)) {
    await misurazione.registraUnaVolta(
      'primo_contributo:$v',
      Eventi.primoContributoInvitato,
      {'viaggio_id': v, 'tipo': 'spesa'},
    );
  }
  unawaited(misurazione.invia());
}

/// Il tasso di adesso, che resta nella spesa con la sua data: una conversione
/// senza data è una bugia (01-modello-dati.md).
(String?, DateTime?) _tassoDi(String valuta, List<TassoCambio> tassi) =>
    switch (tassi.where((t) => t.valuta == valuta).firstOrNull) {
      final t? => (t.perEuro, t.scaricatoIl),
      null when valuta == 'EUR' => ('1', DateTime.now().toUtc()),
      null => (null, null),
    };

/// «Li ho ricevuti»: chi riceve i soldi segna il rimborso, e il saldo si
/// chiude (decisioni/prodotto.md). È una spesa pagata da chi dà, tutta per
/// chi riceve: si segna anche senza rete, come ogni spesa. Non ha eventi: non
/// è un contributo, e nessuna soglia lo chiede (07, regola 2).
Future<void> registraIlRimborso(
  BuildContext context, {
  required String viaggioId,
  required String da,
  required String a,
  required int centesimi,
  required String valuta,
}) async {
  final archivio = Servizi.of(context).archivio;
  final tassi = await archivio.osservaTassi().first;
  final (tassoUsato, tassoAl) = _tassoDi(valuta, tassi);
  await archivio.coda.registraSpesa(
    NuovaSpesa(
      id: const Uuid().v4(),
      viaggioId: viaggioId,
      centesimi: centesimi,
      valuta: valuta,
      paganteId: da,
      data: DateTime.now(),
      tassoUsato: tassoUsato,
      tassoAl: tassoAl,
      quote: {a: centesimi},
      rimborso: true,
    ),
  );
  HapticFeedback.mediumImpact();
}
