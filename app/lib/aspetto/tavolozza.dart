/// I colori dell'app, presi dalla tela di Claude Design "Trolley — design
/// dell'app", stile «Biglietti» (CLAUDE.md, regola 9).
///
/// Un fondo grigio freddo con schede bianche; l'inchiostro per il testo e i
/// pulsanti principali; il cobalto per i viaggi definiti e quello che è
/// attivo. Il giallo sta solo con le idee, il verde solo con le tappe fatte.
/// La tela è solo chiara, e l'app pure finché la tela non disegna anche lo
/// scuro (punti-aperti.md).
library;

import 'package:flutter/widgets.dart';

/// I colori della tela, per nome.
abstract final class Colori {
  /// Il testo e i pulsanti principali.
  static const inchiostro = Color(0xFF15192B);

  /// Il testo secondario.
  static const grafite = Color(0xFF5A6072);

  /// Le etichette sopra i campi.
  static const ardesia = Color(0xFF4A5066);

  /// Il fondo delle schermate.
  static const nebbia = Color(0xFFEDEFF3);

  /// Il fondo dei campi dentro le schede bianche.
  static const foschia = Color(0xFFF2F4F8);

  /// I bordi dei pulsanti secondari e delle scelte.
  static const cenere = Color(0xFFDCE0E8);

  /// Il tempo già occupato e il percorso ancora da fare.
  static const piombo = Color(0xFF9AA1B5);

  /// I viaggi definiti, le icone, quello che è attivo.
  static const cobalto = Color(0xFF2B4ACB);

  /// Il cobalto per il testo piccolo: collegamenti, il testo sul giallo.
  static const cobaltoScuro = Color(0xFF1F3699);

  /// Il fondo delle capsule cobalto.
  static const cobaltoChiaro = Color(0xFFE4E9FB);

  /// Solo le idee.
  static const sole = Color(0xFFFFCF4A);

  /// Il testo sul giallo dell'idea.
  static const senape = Color(0xFF5C4A00);

  /// Solo le tappe fatte: il timbro «fatta».
  static const verde = Color(0xFF1F5F4A);

  /// Un tipo di tappa: i pasti.
  static const pomodoro = Color(0xFFE8573A);

  /// Un tipo di tappa: le passeggiate.
  static const ottanio = Color(0xFF138A84);

  /// Gli errori, le azioni che tolgono qualcosa, quello che non entra.
  static const pericolo = Color(0xFFB42318);

  /// Il fondo di un avviso d'errore.
  static const rosa = Color(0xFFFDEDEB);

  /// Il fondo di una cosa a posto, dietro la spunta verde (tela, 56 e 90).
  static const menta = Color(0xFFE3F0EA);

  /// Il fondo di una cosa ancora da fare, che non è un errore: la giornata
  /// libera, la valigia a metà (tela, 47 e 56).
  static const crema = Color(0xFFFFF4D1);

  /// L'icona sul fondo crema.
  static const ocra = Color(0xFF8A6A00);

  static const bianco = Color(0xFFFFFFFF);
}

/// I colori come li usano le schermate.
class Tavolozza {
  const Tavolozza._();

  static const _unica = Tavolozza._();

  /// La tela è chiara: il contesto non cambia niente, ma resta il punto da
  /// cui passare il giorno in cui avrà anche lo scuro.
  static Tavolozza of(BuildContext context) => _unica;

  Color get sfondo => Colori.nebbia;

  /// Schede e pannelli.
  Color get superficie => Colori.bianco;

  /// Il fondo dei campi di testo.
  Color get riempimento => Colori.foschia;

  Color get testo => Colori.inchiostro;
  Color get testoSecondario => Colori.grafite;
  Color get testoTerziario => Colori.grafite.withValues(alpha: 0.7);
  Color get etichetta => Colori.ardesia;
  Color get separatore => Colori.cenere;
  Color get accento => Colori.cobalto;

  /// Testo e icone sopra l'accento.
  Color get suAccento => Colori.bianco;
  Color get pericolo => Colori.pericolo;
}

/// I colori dei giorni sulla mappa del viaggio (tela, 54): una serie
/// propria, non quella dei tipi di tappa, così il colore dice il giorno e
/// basta. Scuri abbastanza da reggere il numero bianco, e diversi anche in
/// luminosità. Dopo l'ultimo si ricomincia.
const coloriDeiGiorni = [
  Colori.cobalto,
  Color(0xFFB4235F),
  Color(0xFF0F7570),
  Color(0xFF9A5B00),
  Color(0xFF6B3FB8),
  Color(0xFF3F6212),
];

/// Il colore del giorno in posizione [indice] nel viaggio, dallo 0.
Color coloreGiorno(int indice) =>
    coloriDeiGiorni[indice % coloriDeiGiorni.length];

/// I colori delle iniziali delle persone: scuri, perché il bianco si legga.
/// La stessa persona ha sempre lo stesso.
const _coloriAvatar = [
  Colori.cobalto,
  Colori.verde,
  Color(0xFF0F7570),
  Colori.inchiostro,
  Color(0xFFA63A22),
];

Color coloreAvatar(String chiave) =>
    _coloriAvatar[indiceStabile(chiave, _coloriAvatar.length)];

/// Un indice che dipende solo dalla chiave, uguale a ogni avvio e su ogni telefono.
int indiceStabile(String chiave, int quanti) {
  var h = 0;
  for (final c in chiave.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return h % quanti;
}
