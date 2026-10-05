import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/partenza.dart';
import 'package:trolley/dominio/stato_viaggio.dart';

void main() {
  group('quando il viaggio mostra «Prima di partire»', () {
    final oggi = DateTime(2026, 10, 8, 21, 30);
    int? fra(int giorni, {StatoViaggio stato = StatoViaggio.definito}) =>
        giorniAllaPartenza(
          stato: stato,
          inizio: DateTime(2026, 10, 8 + giorni),
          oggi: oggi,
        );

    test('da due giorni prima', () {
      expect(fra(3), isNull);
      expect(fra(2), 2);
      expect(fra(1), 1);
    });

    test('il giorno della partenza il viaggio è in corso, e il giro resta', () {
      expect(fra(0, stato: StatoViaggio.inCorso), 0);
      expect(fra(-1, stato: StatoViaggio.inCorso), isNull);
    });

    test('non per le idee, l\'archivio, i viaggi finiti', () {
      expect(fra(1, stato: StatoViaggio.idea), isNull);
      expect(fra(1, stato: StatoViaggio.archiviato), isNull);
      expect(fra(-5, stato: StatoViaggio.chiuso), isNull);
      expect(
        giorniAllaPartenza(
          stato: StatoViaggio.definito,
          inizio: null,
          oggi: oggi,
        ),
        isNull,
      );
    });
  });

  group('la valigia prima di partire', () {
    VocePrimaDiPartire voce(
      String testo, {
      bool spuntata = false,
      bool personale = false,
      String? portaChi,
      int nata = 0,
    }) => (
      testo: testo,
      spuntata: spuntata,
      personale: personale,
      portaChi: portaChi,
      creataIl: DateTime.utc(2026, 10, 1, nata),
    );

    test('conta la propria lista e quello che porti tu della lista del '
        'viaggio; non quello che portano gli altri', () {
      final valigia = valigiaPrimaDiPartire([
        voce('Ombrello', personale: true, nata: 3),
        voce('Passaporto', personale: true, nata: 1),
        voce('Spazzolino', personale: true, spuntata: true, nata: 2),
        voce('Adattatore', portaChi: 'io', nata: 4),
        voce('Crema solare', portaChi: 'marco', nata: 5),
      ], io: 'io');

      expect(valigia.tutte, 4);
      expect(valigia.fatte, 1);
      // Nell'ordine in cui sono nate.
      expect(valigia.mancano, ['Passaporto', 'Ombrello', 'Adattatore']);
      expect(valigia.diNessuno, 0);
      expect(valigia.fatta, isFalse);
    });

    test('le voci del viaggio che non porta nessuno si dicono a parte, e '
        'finché ci sono la valigia non è fatta', () {
      final valigia = valigiaPrimaDiPartire([
        voce('Passaporto', personale: true, spuntata: true),
        voce('Adattatore'),
        voce('Carte', spuntata: true),
      ], io: 'io');

      expect(valigia.tutte, 1);
      expect(valigia.diNessuno, 1);
      expect(valigia.fatta, isFalse);
      expect(valigia.vuota, isFalse);
    });

    test('vuota, e fatta', () {
      expect(valigiaPrimaDiPartire([], io: 'io').vuota, isTrue);
      expect(valigiaPrimaDiPartire([], io: 'io').fatta, isFalse);
      expect(
        valigiaPrimaDiPartire([
          voce('Passaporto', personale: true, spuntata: true),
          voce('Crema solare', portaChi: 'marco'),
        ], io: 'io').fatta,
        isTrue,
      );
    });
  });

  test('la copia tiene interi i viaggi non finiti', () {
    expect(StatoViaggio.idea.copiaSempreAggiornata, isTrue);
    expect(StatoViaggio.archiviato.copiaSempreAggiornata, isTrue);
    expect(StatoViaggio.definito.copiaSempreAggiornata, isTrue);
    expect(StatoViaggio.inCorso.copiaSempreAggiornata, isTrue);
    expect(StatoViaggio.chiuso.copiaSempreAggiornata, isFalse);
  });
}
