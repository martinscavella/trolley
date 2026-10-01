import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dominio/calendario.dart';
import '../dominio/giornate.dart';

/// Le date e gli orari mentre li si scrive: le date possono mancare ancora,
/// gli orari no, perché partono da un valore proposto.
class BozzaProgramma {
  const BozzaProgramma({
    this.inizio,
    this.fine,
    this.arrivo = arrivoProposto,
    this.partenza = partenzaProposta,
  });

  BozzaProgramma.da(Programma p)
    : this(
        inizio: p.inizio,
        fine: p.fine,
        arrivo: p.arrivo,
        partenza: p.partenza,
      );

  final DateTime? inizio;
  final DateTime? fine;
  final Duration arrivo;
  final Duration partenza;

  /// Il programma, se ci sono le date.
  Programma? get programma {
    final (i, f) = (inizio, fine);
    if (i == null || f == null) return null;
    return Programma(inizio: i, fine: f, arrivo: arrivo, partenza: partenza);
  }

  /// Cosa manca o cosa non va, detto alla persona; `null` se si può salvare.
  String? get problema {
    if (inizio == null) return 'Scegli il primo giorno';
    if (fine == null) return 'Scegli l\'ultimo giorno';
    return programma!.problema;
  }

  /// Cambiando il primo giorno, l'ultimo lo segue se restava indietro.
  BozzaProgramma conInizio(DateTime d) {
    final nuovo = soloData(d);
    final f = fine;
    return BozzaProgramma(
      inizio: nuovo,
      fine: f == null || f.isBefore(nuovo) ? nuovo : f,
      arrivo: arrivo,
      partenza: partenza,
    );
  }

  BozzaProgramma conFine(DateTime d) => BozzaProgramma(
    inizio: inizio,
    fine: soloData(d),
    arrivo: arrivo,
    partenza: partenza,
  );

  BozzaProgramma conArrivo(Duration o) =>
      BozzaProgramma(inizio: inizio, fine: fine, arrivo: o, partenza: partenza);

  BozzaProgramma conPartenza(Duration o) =>
      BozzaProgramma(inizio: inizio, fine: fine, arrivo: arrivo, partenza: o);
}

/// Cosa ne viene fuori, a parole: `3 giorni: il primo dalle 10:00, l'ultimo
/// fino alle 18:00.`
String _cosaNeViene(Programma p) {
  final giorni = p.giorni;
  if (giorni.length == 1) {
    return 'Un giorno solo, ${finestraDelGiorno(giorni.single)}.';
  }
  return '${quanti(giorni.length, 'giorno', 'giorni')}: il primo '
      '${finestraDelGiorno(giorni.first)}, l\'ultimo '
      '${finestraDelGiorno(giorni.last)}.';
}

/// Dal, al, a che ora si arriva il primo giorno, a che ora si riparte
/// l'ultimo; e sotto, cosa ne viene fuori.
class CampiDate extends StatelessWidget {
  const CampiDate({super.key, required this.bozza, required this.onCambio});

  final BozzaProgramma bozza;
  final ValueChanged<BozzaProgramma> onCambio;

  /// Un viaggio può essere cominciato da poco quando lo si scrive.
  static final _primaData = DateTime.now().subtract(const Duration(days: 7));

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final (inizio, fine) = (bozza.inizio, bozza.fine);
    final problema = inizio != null && fine != null ? bozza.problema : null;
    final programma = bozza.programma;

    Future<DateTime?> data(DateTime? attuale, DateTime primaPossibile) {
      final minima = attuale != null && attuale.isBefore(primaPossibile)
          ? attuale
          : primaPossibile;
      final iniziale = attuale ?? minima;
      return AdaptiveDatePicker.show(
        context: context,
        initialDate: DateTime(iniziale.year, iniziale.month, iniziale.day),
        firstDate: DateTime(minima.year, minima.month, minima.day),
        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      );
    }

    Future<Duration?> orario(Duration attuale) async {
      final scelto = await AdaptiveTimePicker.show(
        context: context,
        initialTime: TimeOfDay(
          hour: attuale.inHours % 24,
          minute: attuale.inMinutes % 60,
        ),
        use24HourFormat: true,
        minuteInterval: 5,
      );
      return scelto == null
          ? null
          : Duration(hours: scelto.hour, minutes: scelto.minute);
    }

    final dataIcona = icona(
      ios: CupertinoIcons.calendar,
      android: Icons.calendar_month_outlined,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pannello(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoScelta(
                simbolo: dataIcona,
                segnaposto: 'Primo giorno',
                valore: inizio == null ? null : 'Dal ${dataEstesa(inizio)}',
                onTap: () async {
                  final d = await data(inizio, _primaData);
                  if (d != null) onCambio(bozza.conInizio(d));
                },
              ),
              const SizedBox(height: 8),
              CampoScelta(
                simbolo: dataIcona,
                segnaposto: 'Ultimo giorno',
                valore: fine == null ? null : 'Al ${dataEstesa(fine)}',
                onTap: () async {
                  final d = await data(fine ?? inizio, inizio ?? _primaData);
                  if (d != null) onCambio(bozza.conFine(d));
                },
              ),
              const SizedBox(height: 8),
              CampoScelta(
                simbolo: icona(
                  ios: CupertinoIcons.airplane,
                  android: Icons.flight_land_outlined,
                ),
                segnaposto: 'Arrivo',
                valore: 'Il primo giorno arrivi alle ${ora(bozza.arrivo)}',
                onTap: () async {
                  final o = await orario(bozza.arrivo);
                  if (o != null) onCambio(bozza.conArrivo(o));
                },
              ),
              const SizedBox(height: 8),
              CampoScelta(
                simbolo: icona(
                  ios: CupertinoIcons.house,
                  android: Icons.flight_takeoff_outlined,
                ),
                segnaposto: 'Ripartenza',
                valore: 'L\'ultimo giorno riparti alle ${ora(bozza.partenza)}',
                onTap: () async {
                  final o = await orario(bozza.partenza);
                  if (o != null) onCambio(bozza.conPartenza(o));
                },
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: Ritmo.medio,
          curve: Ritmo.curva,
          alignment: Alignment.topCenter,
          child: programma == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Text(
                    problema ?? _cosaNeViene(programma),
                    style: Testi.secondario.copyWith(
                      color: problema == null ? t.testoSecondario : t.pericolo,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
