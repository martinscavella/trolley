import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dati/coda.dart';
import 'package:trolley/dati/conflitti.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dominio/valute.dart';

import '../aiuti.dart';

/// Le spese (06-spese.md) nei dati: registrarle senza rete con la coda,
/// scaricarle con la copia, cambiarle con la versione, i tassi di cambio.
void main() {
  late Ambiente ambiente;
  late Coda coda;

  setUp(() async {
    ambiente = Ambiente();
    coda = ambiente.archivio.coda;
    ambiente.server
      ..viaggi.add(
        rigaViaggio(
          'v',
          stato: 'definito',
          citta: 'Marrakech',
          paese: 'MA',
          inizio: '2026-10-10',
          fine: '2026-10-12',
        ),
      )
      ..partecipazioni.add(rigaPartecipazione('v'));
    await ambiente.accedi();
    await ambiente.archivio.aggiornaCopia();
  });

  tearDown(() => ambiente.chiudi());

  NuovaSpesa nuova(String id, {int centesimi = 17000, String valuta = 'MAD'}) =>
      NuovaSpesa(
        id: id,
        viaggioId: 'v',
        centesimi: centesimi,
        valuta: valuta,
        paganteId: idDiProva,
        data: DateTime.utc(2026, 10, 10),
        descrizione: '  Jardin Majorelle ',
        tassoUsato: '11.18',
        tassoAl: DateTime.utc(2026, 10, 10, 4),
      );

  Future<List<Spesa>> copia() => ambiente.db.select(ambiente.db.spese).get();
  Future<List<OperazioneInCoda>> inCoda() =>
      ambiente.db.select(ambiente.db.codaScrittura).get();

  group('registrare, anche senza rete', () {
    test(
      'senza rete la spesa c\'è subito, e parte quando la rete torna',
      () async {
        ambiente.rete.disponibile = false;
        await coda.registraSpesa(nuova('s1'));

        final locale = (await copia()).single;
        expect(locale.importo, '170.00');
        expect(locale.valuta, 'MAD');
        expect(locale.descrizione, 'Jardin Majorelle');
        expect(locale.versione, 0);
        expect(locale.creatoDa, idDiProva);
        expect(ambiente.server.spese, isEmpty);

        ambiente.rete.disponibile = true;
        await coda.svuota();

        final arrivata = ambiente.server.spese.single;
        expect(arrivata['id'], 's1');
        expect(arrivata['importo'], 170);
        expect(arrivata['pagante_id'], idDiProva);
        // Entra con la sua data, non con quella dell'invio (06, casi limite).
        expect(arrivata['data'], '2026-10-10');
        // Il tasso resta nella spesa con la sua data.
        expect(arrivata['tasso_usato'], '11.18');
        expect(arrivata['tasso_al'], '2026-10-10T04:00:00.000Z');
        expect(await inCoda(), isEmpty);
        expect((await copia()).single.versione, 1);
      },
    );

    test('rimandata, non si registra due volte', () async {
      ambiente.rete.disponibile = false;
      await coda.registraSpesa(nuova('s1'));
      // La prima volta è arrivata, ma la risposta si è persa per strada.
      ambiente.server.spese.add(
        rigaDiSpesa(
          's1',
          viaggio: 'v',
          importo: '170',
          valuta: 'MAD',
          data: '2026-10-10',
        ),
      );

      ambiente.rete.disponibile = true;
      await coda.svuota();

      expect(ambiente.server.spese, hasLength(1));
      expect(await inCoda(), isEmpty);
      expect((await copia()).single.versione, 1);
    });

    test(
      'senza tasso la spesa si registra lo stesso, senza inventarne uno',
      () {
        final riga = NuovaSpesa(
          id: 's',
          viaggioId: 'v',
          centesimi: 5000000,
          valuta: 'VND',
          paganteId: idDiProva,
          data: DateTime.utc(2026, 10, 10),
        ).riga;
        expect(riga['tasso_usato'], isNull);
        expect(riga['tasso_al'], isNull);
        expect(riga['importo'], '50000.00');
        expect(riga['descrizione'], isNull);
      },
    );

    test('una copia riscaricata non perde la spesa ancora in coda', () async {
      ambiente.rete.disponibile = false;
      await coda.registraSpesa(nuova('s1'));
      // La coda non parte (il server la rifiuta), ma la copia si riscarica.
      ambiente.rete.disponibile = true;
      ambiente.server.percorsi['POST /rest/v1/rpc/registra_spesa'] = (
        _,
      ) async => risposta({'code': '42501', 'message': 'no'}, 403);
      await ambiente.archivio.aggiornaCopia();

      expect((await copia()).single.id, 's1');
      expect((await inCoda()).single.tentativi, 1);
    });

    test('scartata dopo i rifiuti, esce anche dalla copia', () async {
      ambiente.server.percorsi['POST /rest/v1/rpc/registra_spesa'] = (
        _,
      ) async => risposta({'code': '42501', 'message': 'no'}, 403);
      await coda.registraSpesa(nuova('s1'));
      for (var i = 0; i < Coda.tentativiMassimi; i++) {
        await coda.svuota();
      }
      final op = (await inCoda()).single;
      expect(op.messaDaParte, isTrue);
      expect(
        Coda.cosaNonEArrivato(op),
        'La spesa «Jardin Majorelle» non è arrivata.',
      );

      await coda.scarta(op.id);
      expect(await inCoda(), isEmpty);
      expect(await copia(), isEmpty);
    });
  });

  group('la copia', () {
    test('scarica le spese del viaggio, senza quelle tolte', () async {
      ambiente.server.spese.addAll([
        rigaDiSpesa('a', viaggio: 'v', data: '2026-10-10'),
        rigaDiSpesa('b', viaggio: 'v', data: '2026-10-11')
          ..['eliminato_il'] = '2026-10-11T20:00:00Z',
      ]);
      await ambiente.archivio.aggiornaCopia();
      expect((await copia()).map((s) => s.id), ['a']);
    });

    test('scarica i tassi, e non li richiede prima di sei ore', () async {
      ambiente.server.tassi.addAll([
        rigaTasso('MAD', 11.18, '2026-10-10'),
        rigaTasso('USD', 1.125, '2026-10-10'),
      ]);
      // Il setUp li ha già chiesti, quando il server non ne aveva: si riprova.
      await ambiente.archivio.aggiornaTassi(
        adesso: DateTime.now().add(const Duration(hours: 7)),
      );
      final tassi = await ambiente.db.select(ambiente.db.tassiCambio).get();
      expect(tassi.map((t) => t.valuta), containsAll(['MAD', 'USD']));
      expect(tassi.firstWhere((t) => t.valuta == 'MAD').perEuro, '11.18');

      final chiamate = ambiente.server
          .chiamate('GET', '/rest/v1/tasso_cambio')
          .length;
      await ambiente.archivio.aggiornaTassi();
      expect(
        ambiente.server.chiamate('GET', '/rest/v1/tasso_cambio'),
        hasLength(chiamate),
      );
    });

    test('senza rete i tassi restano quelli di prima', () async {
      ambiente.server.tassi.add(rigaTasso('MAD', 11.18, '2026-10-10'));
      await ambiente.archivio.aggiornaTassi(
        adesso: DateTime.now().add(const Duration(hours: 7)),
      );
      ambiente.rete.disponibile = false;
      await expectLater(
        ambiente.archivio.aggiornaTassi(
          adesso: DateTime.now().add(const Duration(days: 3)),
        ),
        throwsA(isA<ErroreTrolley>()),
      );
      final tassi = await ambiente.db.select(ambiente.db.tassiCambio).get();
      expect(tassi.single.perEuro, '11.18');
    });
  });

  group('cambiare e togliere richiedono la rete', () {
    setUp(() async {
      ambiente.server.spese.add(
        rigaDiSpesa('a', viaggio: 'v', data: '2026-10-10', versione: 2),
      );
      await ambiente.archivio.aggiornaCopia();
    });

    Future<Spesa> spesa() async => (await copia()).single;

    test('si cambia con la versione su cui si è deciso', () async {
      await ambiente.archivio.modificaSpesa(await spesa(), {
        'importo': '14.00',
      });
      final chiamata = ambiente.server
          .chiamate('POST', '/rest/v1/rpc/cambia_spesa')
          .single;
      expect(corpoDi(chiamata), {
        'p_spesa': 'a',
        'p_versione': 2,
        'p_valori': {'importo': '14.00'},
        'p_quote': null,
      });
      expect(centesimiDa((await spesa()).importo), 1400);
      expect((await spesa()).versione, 3);
    });

    test('se qualcuno ha cambiato l\'importo intanto, si mostrano le due '
        'versioni e la copia ha la sua', () async {
      final vista = await spesa();
      ambiente.server.spese.single
        ..['importo'] = 20
        ..['versione'] = 5;
      await expectLater(
        ambiente.archivio.modificaSpesa(vista, {'importo': '14.00'}),
        throwsA(
          isA<Conflitto>()
              .having((c) => c.mia['importo'], 'la mia', 1400)
              .having((c) => c.loro['importo'], 'la loro', 2000)
              .having((c) => c.diversi, 'diversi', {'importo'}),
        ),
      );
      expect((await spesa()).versione, 5);
      expect(centesimiDa((await spesa()).importo), 2000);
    });

    test('se intanto è cambiato solo il numero di versione, si scrive sulla '
        'nuova', () async {
      final vista = await spesa();
      ambiente.server.spese.single['versione'] = 5;
      await ambiente.archivio.modificaSpesa(vista, {'importo': '14.00'});
      expect(centesimiDa((await spesa()).importo), 1400);
      expect((await spesa()).versione, 6);
    });

    test('togliere la marca, non la cancella', () async {
      await ambiente.archivio.togliSpesa(await spesa());
      expect(ambiente.server.spese.single['eliminato_il'], isNotNull);
      expect(await copia(), isEmpty);
    });

    test('senza rete non si cambia, e la spesa resta com\'era', () async {
      ambiente.rete.disponibile = false;
      await expectLater(
        ambiente.archivio.modificaSpesa(await spesa(), {'importo': '14.00'}),
        throwsA(
          isA<ErroreTrolley>().having((e) => e.serveLaRete, 'rete', true),
        ),
      );
      expect(centesimiDa((await spesa()).importo), 1240);
    });

    test(
      'una spesa ancora in coda non si cambia: prima deve partire',
      () async {
        ambiente.rete.disponibile = false;
        await coda.registraSpesa(nuova('s1'));
        final inAttesa = (await copia()).firstWhere((s) => s.id == 's1');
        await expectLater(
          ambiente.archivio.modificaSpesa(inAttesa, {'importo': '1.00'}),
          throwsA(isA<ErroreTrolley>()),
        );
      },
    );
  });

  test('la propria valuta si cambia sul profilo, con la versione', () async {
    await ambiente.archivio.cambiaValuta('USD');
    final chiamata = ambiente.server
        .chiamate('PATCH', '/rest/v1/utente')
        .single;
    expect(corpoDi(chiamata), {'valuta_predefinita': 'USD', 'versione': 1});
    expect((await ambiente.archivio.profiloLocale())!.valutaPredefinita, 'USD');
  });

  group('dividere', () {
    Future<List<SpesaQuota>> quoteNellaCopia() =>
        ambiente.db.select(ambiente.db.speseQuote).get();

    test('le quote viaggiano con la spesa: senza rete sono subito nella '
        'copia, poi arrivano insieme e valgono quelle del server', () async {
      ambiente.rete.disponibile = false;
      await coda.registraSpesa(
        NuovaSpesa(
          id: 's1',
          viaggioId: 'v',
          centesimi: 4200,
          valuta: 'EUR',
          paganteId: idDiProva,
          data: DateTime.utc(2026, 10, 10),
          quote: const {idDiProva: 2100, 'marco': 2100},
        ),
      );
      expect(
        (await quoteNellaCopia()).map((q) => (q.utenteId, q.quota)),
        unorderedEquals([(idDiProva, '21.00'), ('marco', '21.00')]),
      );

      ambiente.rete.disponibile = true;
      await coda.svuota();

      final chiamata = ambiente.server
          .chiamate('POST', '/rest/v1/rpc/registra_spesa')
          .single;
      expect(corpoDi(chiamata)['p_quote'], [
        {'utente_id': idDiProva, 'quota': '21.00'},
        {'utente_id': 'marco', 'quota': '21.00'},
      ]);
      expect(ambiente.server.quote, hasLength(2));
      final arrivate = await quoteNellaCopia();
      expect(arrivate, hasLength(2));
      expect(arrivate.every((q) => q.versione == 1), isTrue);
    });

    test('un rimborso è una spesa segnata come tale', () async {
      await coda.registraSpesa(
        NuovaSpesa(
          id: 'r1',
          viaggioId: 'v',
          centesimi: 1220,
          valuta: 'EUR',
          paganteId: 'sara',
          data: DateTime.utc(2026, 10, 12),
          quote: const {idDiProva: 1220},
          rimborso: true,
        ),
      );
      await coda.svuota();
      expect(ambiente.server.spese.single['rimborso'], isTrue);
      expect((await copia()).single.rimborso, isTrue);
    });

    test('scaricando la copia arrivano le quote, senza quelle tolte', () async {
      ambiente.server
        ..spese.add(rigaDiSpesa('a', viaggio: 'v', data: '2026-10-10'))
        ..quote.addAll([
          rigaDiQuota('a', viaggio: 'v', utente: idDiProva, quota: '6.20'),
          rigaDiQuota('a', viaggio: 'v', utente: 'marco', quota: '6.20')
            ..['eliminato_il'] = '2026-10-11T20:00:00Z',
        ]);
      await ambiente.archivio.aggiornaCopia();
      expect((await quoteNellaCopia()).map((q) => q.utenteId), [idDiProva]);
    });

    test('chi ha pagato e per chi si cambiano con la spesa, in una '
        'scrittura sola', () async {
      ambiente.server
        ..spese.add(rigaDiSpesa('a', viaggio: 'v', data: '2026-10-10'))
        ..quote.addAll([
          rigaDiQuota('a', viaggio: 'v', utente: idDiProva, quota: '6.20'),
          rigaDiQuota('a', viaggio: 'v', utente: 'marco', quota: '6.20'),
        ]);
      await ambiente.archivio.aggiornaCopia();

      await ambiente.archivio.modificaSpesa((await copia()).single, {
        'pagante_id': 'marco',
        'quote': [
          {'utente_id': 'marco', 'quota': '12.40'},
        ],
      });

      final c = corpoDi(
        ambiente.server.chiamate('POST', '/rest/v1/rpc/cambia_spesa').single,
      );
      expect(c['p_valori'], {'pagante_id': 'marco'});
      expect(c['p_quote'], [
        {'utente_id': 'marco', 'quota': '12.40'},
      ]);
      expect((await copia()).single.paganteId, 'marco');
      expect((await quoteNellaCopia()).map((q) => (q.utenteId, q.quota)), [
        ('marco', '12.4'),
      ]);
    });

    test('se intanto qualcuno ha cambiato per chi è, due versioni', () async {
      ambiente.server
        ..spese.add(rigaDiSpesa('a', viaggio: 'v', data: '2026-10-10'))
        ..quote.add(
          rigaDiQuota('a', viaggio: 'v', utente: idDiProva, quota: '12.40'),
        );
      await ambiente.archivio.aggiornaCopia();
      final vista = (await copia()).single;
      // Marco l'ha divisa a metà, dal suo telefono.
      ambiente.server.spese.single['versione'] = 2;
      ambiente.server.quote
        ..single['quota'] = 6.2
        ..add(rigaDiQuota('a', viaggio: 'v', utente: 'marco', quota: '6.20'));

      await expectLater(
        ambiente.archivio.modificaSpesa(vista, {
          'descrizione': 'Pranzo al mercato',
        }),
        throwsA(
          isA<Conflitto>().having(
            (c) => c.diversi,
            'diversi',
            containsAll(['descrizione', 'quote']),
          ),
        ),
      );
      expect(await quoteNellaCopia(), hasLength(2));
    });
  });
}
