import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/periodo.dart';
import 'package:trolley/dominio/stato_viaggio.dart';

void main() {
  group('lo stato lo dice il calendario', () {
    StatoViaggio stato(String registrato, DateTime oggi) => statoDelViaggio(
      registrato: registrato,
      inizio: DateTime.utc(2026, 10, 10),
      fine: DateTime.utc(2026, 10, 12),
      oggi: oggi,
    );

    test('definito prima della partenza', () {
      expect(
        stato('definito', DateTime(2026, 10, 9, 23, 59)),
        StatoViaggio.definito,
      );
    });

    test(
      'in corso dalla data di inizio a quella di fine, estremi compresi',
      () {
        expect(stato('definito', DateTime(2026, 10, 10)), StatoViaggio.inCorso);
        expect(
          stato('definito', DateTime(2026, 10, 12, 23, 59)),
          StatoViaggio.inCorso,
        );
      },
    );

    test('chiuso dopo la data di fine', () {
      expect(stato('definito', DateTime(2026, 10, 13)), StatoViaggio.chiuso);
    });

    test('idea, archiviato e chiuso a mano restano quello che sono', () {
      final durante = DateTime(2026, 10, 11);
      expect(stato('idea', durante), StatoViaggio.idea);
      expect(stato('archiviato', durante), StatoViaggio.archiviato);
      expect(stato('chiuso', durante), StatoViaggio.chiuso);
    });
  });

  test('cosa permette ogni stato', () {
    expect(StatoViaggio.idea.haGiorni, isFalse);
    expect(StatoViaggio.definito.haGiorni, isTrue);
    expect(StatoViaggio.inCorso.dateModificabili, isTrue);
    expect(StatoViaggio.chiuso.dateModificabili, isFalse);
    expect(StatoViaggio.definito.puoTornareIdea, isTrue);
    expect(StatoViaggio.inCorso.puoTornareIdea, isFalse);
  });

  group('scadenza di un\'idea', () {
    test('la fine del periodo indicato', () {
      expect(
        scadenzaIdea(
          periodo: const MeseDi(2027, 8),
          creataIl: DateTime(2026, 10, 1),
        ),
        DateTime.utc(2027, 8, 31),
      );
    });

    test('senza periodo, dodici mesi dalla creazione', () {
      expect(
        scadenzaIdea(periodo: null, creataIl: DateTime(2026, 10, 1, 18)),
        DateTime.utc(2027, 10, 1),
      );
    });
  });

  group('prima di archiviare si avvisa, una volta sola', () {
    final scadenza = DateTime.utc(2027, 8, 31);

    test('il sollecito compare nelle ultime due settimane', () {
      expect(
        sollecitoDovuto(scadenza: scadenza, oggi: DateTime(2027, 8, 16)),
        isFalse,
      );
      expect(
        sollecitoDovuto(scadenza: scadenza, oggi: DateTime(2027, 8, 17)),
        isTrue,
      );
      expect(
        sollecitoDovuto(scadenza: scadenza, oggi: DateTime(2027, 12, 1)),
        isTrue,
      );
    });

    test('senza sollecito non si archivia mai', () {
      expect(
        daArchiviare(
          scadenza: scadenza,
          sollecitataIl: null,
          oggi: DateTime(2028, 1, 1),
        ),
        isFalse,
      );
    });

    test('sollecitata in tempo: va in archivio il giorno dopo la scadenza', () {
      final il = DateTime(2027, 8, 17);
      expect(
        daArchiviare(
          scadenza: scadenza,
          sollecitataIl: il,
          oggi: DateTime(2027, 8, 31),
        ),
        isFalse,
      );
      expect(
        daArchiviare(
          scadenza: scadenza,
          sollecitataIl: il,
          oggi: DateTime(2027, 9, 1),
        ),
        isTrue,
      );
    });

    test('sollecitata in ritardo: restano due settimane dal sollecito', () {
      final il = DateTime(2027, 12, 1);
      expect(
        daArchiviare(
          scadenza: scadenza,
          sollecitataIl: il,
          oggi: DateTime(2027, 12, 14),
        ),
        isFalse,
      );
      expect(
        daArchiviare(
          scadenza: scadenza,
          sollecitataIl: il,
          oggi: DateTime(2027, 12, 15),
        ),
        isTrue,
      );
    });

    test(
      'il giorno dell\'archivio è quello in cui daArchiviare diventa vero',
      () {
        for (final il in [DateTime(2027, 8, 17), DateTime(2027, 12, 1)]) {
          final giorno = giornoDellArchivio(
            scadenza: scadenza,
            sollecitataIl: il,
          );
          expect(
            daArchiviare(scadenza: scadenza, sollecitataIl: il, oggi: giorno),
            isTrue,
          );
          expect(
            daArchiviare(
              scadenza: scadenza,
              sollecitataIl: il,
              oggi: giorno.subtract(const Duration(days: 1)),
            ),
            isFalse,
          );
        }
      },
    );
  });
}
