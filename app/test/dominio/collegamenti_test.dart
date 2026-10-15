import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/collegamenti.dart';

/// I collegamenti e i messaggi (5.4): lo stato con una persona com'è sul
/// server, le righe dei collegamenti e delle conversazioni, l'unione dei
/// messaggi che arrivano con quelli scritti, e le parole sotto i nomi.
void main() {
  final adesso = DateTime(2026, 10, 15, 18, 30);

  Map<String, Object?> messaggio(
    String id,
    String quando, {
    bool mio = false,
    String? testo = 'ciao',
    bool tolto = false,
  }) => {
    'id': id,
    'mio': mio,
    'testo': testo,
    'scritto_il': quando,
    'tolto': tolto,
  };

  group('lo stato con una persona', () {
    test('si legge com\'è sul server; niente fra voi è null', () {
      expect(Collegamento.daServer(null), isNull);
      expect(Collegamento.daServer({'stato': 'altro'}), isNull);

      final ricevuta = Collegamento.daServer({
        'stato': 'ricevuta',
        'dal': '2026-10-14T09:00:00Z',
        'messaggio': 'Anche io a Porto!',
      })!;
      expect(ricevuta.stato, StatoCollegamento.ricevuta);
      expect(ricevuta.dal, DateTime.utc(2026, 10, 14, 9));
      expect(ricevuta.messaggio, 'Anche io a Porto!');

      expect(
        Collegamento.daServer({'stato': 'non_accettata'})!.stato,
        StatoCollegamento.nonAccettata,
      );
      expect(
        Collegamento.daServer({'stato': 'collegati'})!.stato,
        StatoCollegamento.collegati,
      );
      expect(
        Collegamento.daServer({'stato': 'inviata'})!.stato,
        StatoCollegamento.inviata,
      );
    });

    test('chiedere dice se è un sì perché l\'altro aveva già chiesto', () {
      expect(esitoRichiesta('richiesto'), EsitoRichiesta.richiesto);
      expect(esitoRichiesta('accettato'), EsitoRichiesta.accettato);
      expect(esitoRichiesta('nessun_cambio'), EsitoRichiesta.nessunCambio);
      expect(esitoRichiesta(null), EsitoRichiesta.nessunCambio);
    });
  });

  group('i collegamenti', () {
    test('ricevute con il messaggio e il profilo, inviate, collegati', () {
      final c = Collegamenti.daServer({
        'ricevute': [
          {
            'utente_id': 'a',
            'nome': 'Andrea',
            'messaggio': 'Ti va di scambiare due consigli?',
            'chiesto_il': '2026-10-14T09:00:00Z',
            'profilo': {
              'id': 'a',
              'nome': 'Andrea',
              'dal': '2026-06-01',
              'gusti': ['cibo'],
              'traguardi': 3,
              'viaggi': <Object?>[],
            },
          },
        ],
        'inviate': [
          {
            'utente_id': 'l',
            'nome': 'Luca',
            'stato': 'richiesto',
            'chiesto_il': '2026-10-13T09:00:00Z',
          },
          {
            'utente_id': 's',
            'nome': 'Sara',
            'stato': 'rifiutato',
            'chiesto_il': '2026-10-01T09:00:00Z',
          },
        ],
        'collegati': [
          {'utente_id': 't', 'nome': 'Teresa', 'dal': '2026-10-02T10:00:00Z'},
        ],
      });
      expect(c.vuoti, isFalse);
      expect(c.ricevute.single.messaggio, 'Ti va di scambiare due consigli?');
      expect(c.ricevute.single.profilo!.gusti, isNotEmpty);
      expect([for (final r in c.inviate) r.accettata], [null, false]);
      expect(c.collegati.single.nome, 'Teresa');
      expect(Collegamenti.daServer(const {}).vuoti, isTrue);
    });

    test('sotto i nomi: da quando, a che punto è la richiesta', () {
      expect(
        collegatiDa(DateTime(2026, 10, 2), adesso),
        'collegati da ottobre',
      );
      expect(
        collegatiDa(DateTime(2025, 9, 2), adesso),
        'collegati da settembre 2025',
      );
      expect(collegatiDa(null, adesso), 'collegati');

      RichiestaInviata inviata(DateTime quando, {bool? accettata}) =>
          RichiestaInviata(
            utenteId: 'l',
            nome: 'Luca',
            chiestaIl: quando,
            accettata: accettata,
          );
      expect(
        statoInviata(inviata(DateTime(2026, 10, 15, 8)), adesso),
        'in attesa, da oggi',
      );
      expect(
        statoInviata(inviata(DateTime(2026, 10, 14, 23)), adesso),
        'in attesa, da ieri',
      );
      expect(
        statoInviata(inviata(DateTime(2026, 10, 13)), adesso),
        'in attesa, da 2 giorni',
      );
      expect(
        statoInviata(inviata(DateTime(2026, 10, 13), accettata: false), adesso),
        'non accettata',
      );
    });
  });

  group('i messaggi', () {
    test('quello arrivato dal server prende il posto di quello in viaggio, e '
        'quelli non arrivati restano in fondo', () {
      final arrivati = [
        Messaggio.daServer(messaggio('1', '2026-10-15T09:00:00Z')),
        Messaggio.daServer(messaggio('2', '2026-10-15T10:00:00Z', mio: true)),
      ];
      final inViaggio = Messaggio(
        id: '3',
        mio: true,
        testo: 'Grazie!',
        scrittoIl: DateTime.utc(2026, 10, 15, 8),
        inViaggio: true,
      );
      var tutti = unisci(arrivati, [inViaggio]);
      expect([for (final m in tutti) m.id], ['1', '2', '3']);

      // Uno nuovo dall'altra parte, più vecchio di quello in viaggio.
      tutti = unisci(tutti, [
        Messaggio.daServer(messaggio('4', '2026-10-15T11:00:00Z')),
      ]);
      expect([for (final m in tutti) m.id], ['1', '2', '4', '3']);

      // Arriva: va al suo posto, e non è più in viaggio.
      tutti = unisci(tutti, [
        Messaggio.daServer(
          messaggio('3', '2026-10-15T12:00:00Z', mio: true, testo: 'Grazie!'),
        ),
      ]);
      expect([for (final m in tutti) m.id], ['1', '2', '4', '3']);
      expect(tutti.last.inViaggio, isFalse);

      // Rimandato dopo una risposta persa: uno solo.
      tutti = unisci(tutti, [
        Messaggio.daServer(messaggio('3', '2026-10-15T12:00:00Z', mio: true)),
      ]);
      expect(tutti, hasLength(4));
    });

    test('non partito resta, con lo stesso id, per riprovare', () {
      final m = Messaggio(
        id: 'x',
        mio: true,
        testo: 'Ci sei?',
        scrittoIl: adesso,
        inViaggio: true,
      ).nonPartito();
      expect(m.id, 'x');
      expect(m.testo, 'Ci sei?');
      expect(m.nonInviato, isTrue);
      expect(m.inViaggio, isFalse);
    });

    test('si chiede dei nuovi da un minuto prima dell\'ultimo arrivato', () {
      final messaggi = [
        Messaggio.daServer(messaggio('1', '2026-10-15T09:00:00Z')),
        Messaggio.daServer(messaggio('2', '2026-10-15T10:00:00Z')),
        Messaggio(
          id: '3',
          mio: true,
          testo: 'in viaggio',
          scrittoIl: DateTime.utc(2026, 10, 15, 11),
          inViaggio: true,
        ),
      ];
      expect(ultimoArrivato(messaggi), DateTime.utc(2026, 10, 15, 10));
      expect(daQuandoChiedere(messaggi), DateTime.utc(2026, 10, 15, 9, 59));
      expect(daQuandoChiedere(const []), isNull);
    });

    test('uno tolto da chi modera non ha più il testo', () {
      final m = Messaggio.daServer(
        messaggio('1', '2026-10-15T09:00:00Z', testo: null, tolto: true),
      );
      expect(m.tolto, isTrue);
      expect(m.testo, isNull);
    });
  });

  group('le conversazioni', () {
    RigaConversazione riga({
      bool collegati = true,
      String? nome = 'Teresa',
      Map<String, Object?>? ultimo,
      int daLeggere = 0,
      String? dal = '2026-10-10T10:00:00Z',
    }) => RigaConversazione.daServer({
      'utente_id': 't',
      'nome': nome,
      'collegati': collegati,
      'dal': dal,
      'ultimo': ultimo,
      'da_leggere': daLeggere,
    });

    test('sotto il nome: l\'ultimo messaggio, il tuo con «Tu:», e i casi '
        'senza messaggi', () {
      expect(
        anteprima(
          riga(
            ultimo: messaggio(
              '1',
              '2026-10-15T09:00:00Z',
              testo: 'E gli okonomiyaki\n  a Osaka',
            ),
          ),
        ),
        'E gli okonomiyaki a Osaka',
      );
      expect(
        anteprima(
          riga(
            ultimo: messaggio(
              '1',
              '2026-10-15T09:00:00Z',
              mio: true,
              testo: 'Ci sentiamo per Porto!',
            ),
          ),
        ),
        'Tu: Ci sentiamo per Porto!',
      );
      expect(anteprima(riga()), 'Siete collegati: scrivi tu per primo');
      expect(
        anteprima(riga(collegati: false, nome: null)),
        'Non siete più collegati',
      );
      expect(
        anteprima(
          riga(
            ultimo: messaggio(
              '1',
              '2026-10-15T09:00:00Z',
              testo: null,
              tolto: true,
            ),
          ),
        ),
        'Messaggio tolto da chi modera',
      );
    });

    test('il numero su «Messaggi» conta le conversazioni, non i messaggi', () {
      expect(
        conversazioniDaLeggere([
          riga(daLeggere: 2),
          riga(daLeggere: 0),
          riga(daLeggere: 1),
        ]),
        2,
      );
    });

    test('in ordine dall\'ultimo messaggio, o da quando siete collegati', () {
      expect(riga().quando, DateTime.utc(2026, 10, 10, 10));
      expect(
        riga(ultimo: messaggio('1', '2026-10-15T09:00:00Z')).quando,
        DateTime.utc(2026, 10, 15, 9),
      );
    });

    test('chi ha chiuso l\'account non ha più un nome', () {
      expect(nomeOAccountChiuso(null), 'Account chiuso');
      expect(nomeOAccountChiuso('Teresa'), 'Teresa');
    });

    test('quando: l\'ora oggi, «ieri», poi il giorno', () {
      expect(quandoInElenco(DateTime(2026, 10, 15, 10, 42), adesso), '10:42');
      expect(quandoInElenco(DateTime(2026, 10, 14, 22), adesso), 'ieri');
      expect(quandoInElenco(DateTime(2026, 10, 3, 9), adesso), '3 ott');
      expect(quandoInElenco(DateTime(2025, 12, 3, 9), adesso), '3 dic 2025');

      expect(
        giornoDellaConversazione(DateTime(2026, 10, 15, 8), adesso),
        'OGGI',
      );
      expect(
        giornoDellaConversazione(DateTime(2026, 10, 14, 8), adesso),
        'IERI',
      );
      expect(
        giornoDellaConversazione(DateTime(2026, 9, 29, 8), adesso),
        '29 SETTEMBRE',
      );
      expect(
        giornoDellaConversazione(DateTime(2025, 9, 29, 8), adesso),
        '29 SETTEMBRE 2025',
      );
    });
  });
}
