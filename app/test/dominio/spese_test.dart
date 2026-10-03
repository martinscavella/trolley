import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/spese.dart';
import 'package:trolley/dominio/stato_viaggio.dart';

VoceSpesa<String> spesa(
  String nome,
  DateTime data, {
  int centesimi = 1000,
  String valuta = 'EUR',
  int ora = 9,
}) => VoceSpesa(
  spesa: nome,
  centesimi: centesimi,
  valuta: valuta,
  data: data,
  creataIl: data.add(Duration(hours: ora)),
);

void main() {
  test('le spese esistono solo da quando il viaggio ha le date', () {
    expect(speseAmmesse(StatoViaggio.idea), isFalse);
    expect(speseAmmesse(StatoViaggio.archiviato), isFalse);
    expect(speseAmmesse(StatoViaggio.definito), isTrue);
    expect(speseAmmesse(StatoViaggio.inCorso), isTrue);
    expect(speseAmmesse(StatoViaggio.chiuso), isTrue);
  });

  test('i gruppi: dopo il viaggio in cima, i giorni dal più recente, prima '
      'del viaggio in fondo', () {
    final inizio = DateTime.utc(2026, 10, 10);
    final fine = DateTime.utc(2026, 10, 12);
    final gruppi = raggruppaSpese(
      [
        spesa('volo', DateTime.utc(2026, 9, 12)),
        spesa('pranzo', DateTime.utc(2026, 10, 10), ora: 13),
        spesa('taxi', DateTime.utc(2026, 10, 10), ora: 18),
        spesa('cena', DateTime.utc(2026, 10, 11)),
        spesa('acconto', DateTime.utc(2026, 9, 20)),
        spesa('souvenir all\'aeroporto', DateTime.utc(2026, 10, 13)),
      ],
      inizio: inizio,
      fine: fine,
    );
    expect(gruppi.map((g) => g.tipo), [
      TipoGruppoSpese.dopo,
      TipoGruppoSpese.giorno,
      TipoGruppoSpese.giorno,
      TipoGruppoSpese.prima,
    ]);
    expect(gruppi[1].data, DateTime.utc(2026, 10, 11));
    // Dentro un giorno, l'ultima registrata in cima.
    expect(gruppi[2].spese.map((s) => s.spesa), ['taxi', 'pranzo']);
    // Prima del viaggio, dalla più recente.
    expect(gruppi[3].spese.map((s) => s.spesa), ['acconto', 'volo']);
  });

  test('il totale converte quello che può, e il resto lo tiene a parte', () {
    final oggi = DateTime.utc(2026, 10, 10);
    final totale = totaleSpese(
      [
        spesa('pranzo', oggi, centesimi: 1240),
        spesa('taxi', oggi, centesimi: 8000, valuta: 'MAD'),
        spesa('pho', oggi, centesimi: 15000000, valuta: 'VND'),
        spesa('banh mi', oggi, centesimi: 5000000, valuta: 'VND'),
      ],
      mia: 'EUR',
      perEuro: const {'MAD': 11.18},
    );
    expect(totale.centesimi, 1240 + 716);
    expect(totale.nonConvertite, {'VND': 20000000});
    expect(totale.completo, isFalse);
  });

  test('le valute proposte: la propria, quella del posto, quelle usate', () {
    expect(
      valuteProposte(mia: 'EUR', delPosto: 'MAD', usate: ['USD', 'MAD', 'GBP']),
      ['EUR', 'MAD', 'USD', 'GBP'],
    );
    expect(valuteProposte(mia: 'EUR', delPosto: 'EUR', usate: const []), [
      'EUR',
    ]);
    expect(
      valuteProposte(
        mia: 'EUR',
        delPosto: null,
        usate: ['A', 'B', 'C', 'D'],
        quante: 3,
      ),
      ['EUR', 'A', 'B'],
    );
  });
}
