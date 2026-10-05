import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/mappa.dart';
import 'package:trolley/dominio/navigazione.dart';

/// La navigazione a piedi (fase 3.2, 08-mappa.md, regola 2): dove si è lungo
/// il percorso, quale svolta viene e fra quanto, se si è usciti di strada,
/// quando chiedere una strada nuova.
void main() {
  // A Porto si va a est per circa 420 metri, poi a nord per circa 440.
  const partenza = (lat: 41.0, lon: 0.0);
  const svolta = (lat: 41.0, lon: 0.005);
  const arrivo = (lat: 41.004, lon: 0.005);
  final aEst = distanzaInMetri(partenza, svolta);
  final aNord = distanzaInMetri(svolta, arrivo);

  Percorso aElle() => Percorso(
    punti: const [partenza, svolta, arrivo],
    passi: [
      Passo(
        istruzione: 'Dirigiti a est su Rua das Carmelitas',
        manovra: Manovra.partenza,
        da: 0,
        a: 1,
        metri: aEst,
      ),
      Passo(
        istruzione: 'Svolta a sinistra in Rua das Flores',
        manovra: Manovra.aSinistra,
        da: 1,
        a: 2,
        metri: aNord,
      ),
      const Passo(
        istruzione: 'Sei arrivato',
        manovra: Manovra.arrivo,
        da: 2,
        a: 2,
        metri: 0,
      ),
    ],
    metri: aEst + aNord,
    durata: const Duration(minutes: 12),
  );

  test('alla partenza: la prima svolta fra quattrocento metri, e tutto il '
      'percorso davanti', () {
    final a = aElle().avanzamento(partenza);
    expect(a.passo, 0);
    expect(a.prossima!.manovra, Manovra.aSinistra);
    expect(a.metriAllaProssima, closeTo(aEst, 1));
    expect(a.metriRimasti, closeTo(aEst + aNord, 1));
    expect(a.tempoRimasto, const Duration(minutes: 12));
    expect(a.fuoriStrada, isFalse);
  });

  test('a metà della prima via, la svolta si avvicina e il tempo cala in '
      'proporzione', () {
    final a = aElle().avanzamento((lat: 41.0, lon: 0.0025));
    expect(a.passo, 0);
    expect(a.metriAllaProssima, closeTo(aEst / 2, 2));
    expect(a.metriRimasti, closeTo(aEst / 2 + aNord, 2));
    expect(
      a.tempoRimasto.inSeconds,
      closeTo(720 * (aEst / 2 + aNord) / (aEst + aNord), 2),
    );
  });

  test('dopo la svolta, la prossima indicazione è l\'arrivo', () {
    final a = aElle().avanzamento((lat: 41.002, lon: 0.005));
    expect(a.passo, 1);
    expect(a.prossima!.manovra, Manovra.arrivo);
    expect(a.metriAllaProssima, closeTo(aNord / 2, 2));
  });

  test('il GPS che sbanda di qualche metro non è uscire di strada', () {
    // Una ventina di metri a sud della via.
    final a = aElle().avanzamento((lat: 40.9998, lon: 0.002));
    expect(a.scarto, closeTo(22, 3));
    expect(a.fuoriStrada, isFalse);
  });

  test('cento metri fuori sì', () {
    final a = aElle().avanzamento((lat: 40.9991, lon: 0.002));
    expect(a.scarto, greaterThan(sogliaFuoriStrada));
    expect(a.fuoriStrada, isTrue);
  });

  test('una strada che torna su sé stessa: si va avanti da dove si era', () {
    // Est per quattrocento metri, poi indietro dieci metri più a nord.
    const ritorno = (lat: 41.00009, lon: 0.0);
    final andata = distanzaInMetri(partenza, svolta);
    final indietro = distanzaInMetri(svolta, ritorno);
    final anello = Percorso(
      punti: const [partenza, svolta, ritorno],
      passi: const [],
      metri: andata + indietro,
      durata: const Duration(minutes: 10),
    );
    // Senza sapere dove si era, si è alla partenza…
    expect(anello.avanzamento(partenza).fatti, closeTo(0, 1));
    // …ma chi ha già fatto quasi tutto è alla fine.
    expect(
      anello.avanzamento(partenza, giaFatti: andata + indietro - 30).fatti,
      closeTo(andata + indietro, 15),
    );
  });

  test('arrivati: a trenta metri sì, a cinquanta no', () {
    expect(
      arrivato(posizione: (lat: 41.00427, lon: 0.005), tappa: arrivo),
      isTrue,
    );
    expect(
      arrivato(posizione: (lat: 41.00445, lon: 0.005), tappa: arrivo),
      isFalse,
    );
  });

  group('quando chiedere una strada nuova', () {
    final adesso = DateTime(2026, 10, 11, 10, 30);

    test('una posizione sola fuori strada può essere il GPS', () {
      expect(
        vaRicalcolato(fuori: 1, fatti: 0, ultimo: null, adesso: adesso),
        Ricalcolo.no,
      );
    });

    test('due di fila sì', () {
      expect(
        vaRicalcolato(fuori: 2, fatti: 0, ultimo: null, adesso: adesso),
        Ricalcolo.si,
      );
    });

    test('non subito dopo l\'ultima', () {
      expect(
        vaRicalcolato(
          fuori: 3,
          fatti: 1,
          ultimo: adesso.subtract(const Duration(seconds: 5)),
          adesso: adesso,
        ),
        Ricalcolo.no,
      );
      expect(
        vaRicalcolato(
          fuori: 3,
          fatti: 1,
          ultimo: adesso.subtract(attesaFraRicalcoli),
          adesso: adesso,
        ),
        Ricalcolo.si,
      );
    });

    test('oltre il tetto basta: si consegna alle Mappe del telefono', () {
      expect(
        vaRicalcolato(
          fuori: 2,
          fatti: ricalcoliMassimi,
          ultimo: null,
          adesso: adesso,
        ),
        Ricalcolo.basta,
      );
    });
  });
}
