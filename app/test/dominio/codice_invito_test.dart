import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/codice_invito.dart';

void main() {
  group('normalizzaCodice', () {
    test('accetta il codice come lo digita una persona', () {
      expect(normalizzaCodice('abcd-2345'), 'ABCD2345');
      expect(normalizzaCodice(' ABCD 2345 '), 'ABCD2345');
    });

    test('rifiuta lunghezze sbagliate', () {
      expect(normalizzaCodice('ABC2345'), isNull);
      expect(normalizzaCodice('ABCD23456'), isNull);
      expect(normalizzaCodice(''), isNull);
    });

    test('rifiuta i caratteri che il server non genera', () {
      // 0, 1, O, I, L si confondono: il server non li usa mai.
      expect(normalizzaCodice('ABCD2340'), isNull);
      expect(normalizzaCodice('ABCD234O'), isNull);
      expect(normalizzaCodice('ABCD234I'), isNull);
      expect(normalizzaCodice('ABCD234L'), isNull);
    });
  });

  group('codiceDaLink', () {
    test('lo schema dell\'app, quello che usa oggi la pagina d\'invito', () {
      expect(codiceDaLink(Uri.parse('trolley://invito/ABCD2345')), 'ABCD2345');
      expect(codiceDaLink(Uri.parse('trolley://invito/abcd-2345')), 'ABCD2345');
    });

    test('il link web, per quando ci saranno i link universali', () {
      expect(
        codiceDaLink(Uri.parse('https://trolleyapp.vercel.app/i/ABCD2345')),
        'ABCD2345',
      );
    });

    test('ignora i link che non sono inviti', () {
      expect(codiceDaLink(Uri.parse('trolley://accesso?code=xyz')), isNull);
      expect(codiceDaLink(Uri.parse('trolley://invito/')), isNull);
      expect(codiceDaLink(Uri.parse('trolley://invito/NONVALIDO0')), isNull);
      expect(
        codiceDaLink(Uri.parse('https://altrosito.it/i/ABCD2345')),
        isNull,
      );
      expect(
        codiceDaLink(Uri.parse('http://trolleyapp.vercel.app/i/ABCD2345')),
        isNull,
      );
    });
  });

  test('il link condiviso riporta allo stesso codice', () {
    expect(codiceDaLink(linkInvito('ABCD2345')), 'ABCD2345');
  });

  test('il messaggio dice cosa fare a chi non ha l\'app', () {
    final messaggio = messaggioInvito('ABCD2345');
    expect(messaggio, contains('https://trolleyapp.vercel.app/i/ABCD2345'));
    expect(messaggio, contains('installala e poi riapri questo link'));
    expect(messaggio, contains('ABCD-2345'));
  });
}
