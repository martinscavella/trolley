import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/parte_pubblica.dart';

/// La parte pubblica vista dalla persona (5.1): il passo da mostrare, il
/// numero come lo si scrive, le segnalazioni come le dà il server.
void main() {
  group('il numero', () {
    test('senza prefisso è italiano', () {
      expect(numeroInternazionale('347 123 4567'), '+393471234567');
      expect(numeroInternazionale('347-123.4567'), '+393471234567');
      expect(numeroInternazionale('(347) 1234567'), '+393471234567');
    });

    test('con il prefisso, o con 00, resta quello', () {
      expect(numeroInternazionale('+44 7911 123456'), '+447911123456');
      expect(numeroInternazionale('0044 7911 123456'), '+447911123456');
      expect(numeroInternazionale('+39 347 123 4567'), '+393471234567');
    });

    test('quello che non è un numero non passa', () {
      expect(numeroInternazionale(''), isNull);
      expect(numeroInternazionale('347'), isNull);
      expect(numeroInternazionale('tre quattro sette'), isNull);
      expect(numeroInternazionale('+0 123 456 789'), isNull);
      expect(numeroInternazionale('+39 1234 5678 9012 345'), isNull);
    });

    test('si mostra senza mostrarlo tutto', () {
      expect(numeroNascosto('+393471234567'), '+39 347 ••• 4567');
      expect(numeroNascosto('+447911123456'), '+44 ••• 3456');
    });
  });

  test('il codice conta quando ha tutte e sei le cifre', () {
    expect(codiceCompleto('123456'), '123456');
    expect(codiceCompleto('123 456'), '123456');
    expect(codiceCompleto('12345'), isNull);
    expect(codiceCompleto(''), isNull);
  });

  group('il passo del profilo pubblico', () {
    StatoPartePubblica stato({
      bool accoglie = true,
      bool maggiorenne = true,
      bool attivo = false,
      String? telefono,
      DateTime? sospesoIl,
    }) => StatoPartePubblica(
      visibile: true,
      accoglie: accoglie,
      maggiorenne: maggiorenne,
      attivo: attivo,
      telefono: telefono,
      sospesoIl: sospesoIl,
      motivoSospensione: sospesoIl == null ? null : 'Regola 2',
    );

    test('prima il numero, poi si accende', () {
      expect(passoDi(stato()), PassoProfiloPubblico.serveIlTelefono);
      expect(
        passoDi(stato(telefono: '+393471234567')),
        PassoProfiloPubblico.daAccendere,
      );
      expect(
        passoDi(stato(telefono: '+393471234567', attivo: true)),
        PassoProfiloPubblico.acceso,
      );
    });

    test('sotto i 18 anni non c\'è, e chiusa ai nuovi lo dice', () {
      expect(
        passoDi(stato(maggiorenne: false)),
        PassoProfiloPubblico.minorenne,
      );
      expect(passoDi(stato(accoglie: false)), PassoProfiloPubblico.chiusa);
    });

    test('chi c\'è già resta acceso anche quando è chiusa ai nuovi', () {
      expect(
        passoDi(stato(accoglie: false, attivo: true, telefono: '+39347')),
        PassoProfiloPubblico.acceso,
      );
    });

    test('la sospensione vince su tutto', () {
      expect(
        passoDi(stato(sospesoIl: DateTime.utc(2026, 10, 4), telefono: '+39')),
        PassoProfiloPubblico.sospeso,
      );
    });

    test('dal server', () {
      final s = StatoPartePubblica.daServer({
        'visibile': true,
        'accoglie': false,
        'maggiorenne': true,
        'telefono': '+393471234567',
        'attivo': false,
        'sospeso_il': '2026-10-04T08:00:00+00:00',
        'sospensione_motivo': 'Regola 2: messaggi molesti.',
        'condizioni': '2026-10-09',
      });
      expect(s.visibile, isTrue);
      expect(s.accoglie, isFalse);
      expect(s.telefono, '+393471234567');
      expect(s.sospesoIl, DateTime.utc(2026, 10, 4, 8));
      expect(s.motivoSospensione, 'Regola 2: messaggi molesti.');
      expect(s.condizioni, '2026-10-09');
    });
  });

  test('una segnalazione dal server, ricevuta e gestita', () {
    final ricevuta = Segnalazione.daServer({
      'id': 's1',
      'tipo_oggetto': 'profilo',
      'nome': 'Luca',
      'motivo': 'molestie',
      'stato': 'ricevuta',
      'esito': null,
      'creata_il': '2026-10-08T19:12:00+00:00',
      'gestita_il': null,
    });
    expect(ricevuta.tipo, TipoSegnalato.profilo);
    expect(ricevuta.motivo, MotivoSegnalazione.molestie);
    expect(ricevuta.gestita, isFalse);

    final gestita = Segnalazione.daServer({
      'id': 's2',
      'tipo_oggetto': 'messaggio',
      'nome': null,
      'motivo': 'minore',
      'stato': 'gestita',
      'esito': 'profilo_sospeso',
      'creata_il': '2026-10-01T10:00:00+00:00',
      'gestita_il': '2026-10-02T09:00:00+00:00',
    });
    expect(gestita.tipo, TipoSegnalato.messaggio);
    expect(gestita.nome, '');
    expect(gestita.esito, EsitoSegnalazione.profiloSospeso);
    expect(gestita.gestitaIl, DateTime.utc(2026, 10, 2, 9));
  });

  test('i motivi sono quelli del server, nell\'ordine della tela', () {
    expect(
      [for (final m in MotivoSegnalazione.values) m.name],
      ['molestie', 'falso', 'inappropriato', 'minore', 'altro'],
    );
  });
}
