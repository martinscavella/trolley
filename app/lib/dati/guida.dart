/// La guida passo passo verso una tappa (08-mappa.md, regola 2; CR-06,
/// passo 4; ADR-014), dietro questa interfaccia: oggi il Navigation SDK di
/// Google, sul telefono. Nessuna schermata parla con lui.
///
/// Cosa vede Google: dove si trova il telefono mentre ti guida, e la tappa
/// a cui vai (le coordinate, o il suo `place_id`). Non chi sei né di quale
/// viaggio: la guida parla con Google dal telefono, con la chiave legata
/// all'app. Fuori dalla guida, niente.
///
/// Ogni destinazione si paga (le prime 1000 al mese sono gratis): per
/// questo, prima di partire, il server la conta sul tetto di chi la chiede
/// ([Mappe.guidaConsentita]).
library;

import 'package:flutter/widgets.dart';

import '../dominio/mappa.dart';
import 'mappe.dart';

/// Com'è andata una richiesta alla guida.
enum EsitoGuida {
  ok,

  /// Le condizioni di Google per la guida non sono state accettate.
  condizioniRifiutate,

  /// Il telefono non sa dove sei.
  senzaPosizione,

  /// Non c'è una strada fino alla tappa.
  nonTrovata,
  senzaRete,

  /// Le destinazioni di questo mese, per tutta l'app, sono finite.
  tetto,

  /// La guida non si può usare su questo telefono, o non risponde.
  nonDisponibile,
}

/// Che svolta viene: l'icona dell'intestazione (tela, 163).
enum Svolta {
  dritto,
  leggermenteADestra,
  aDestra,
  strettaADestra,
  leggermenteASinistra,
  aSinistra,
  strettaASinistra,
  inversione,
  tieniLaDestra,
  tieniLaSinistra,
  rotonda,
  traghetto,
  arrivo,
}

/// L'indicazione di adesso: la svolta che viene, fra quanti metri, e
/// come la dice la guida («Svolta a destra in Gothersgade»).
class Indicazione {
  const Indicazione({
    required this.svolta,
    required this.testo,
    this.metri,
    this.ricalcolo = false,
  });

  final Svolta svolta;
  final String testo;
  final double? metri;

  /// La guida sta cercando una strada nuova: si è usciti da quella.
  final bool ricalcolo;
}

/// Quanto manca all'arrivo.
class Rimasto {
  const Rimasto({required this.metri, required this.tempo});

  final double metri;
  final Duration tempo;
}

/// Comanda la mappa della guida.
abstract interface class ControlloGuida {
  /// La mappa torna a seguire la persona.
  Future<void> seguimi();

  /// In 3D ([inclinata]) o in 2D, con un passaggio morbido.
  Future<void> inclina({required bool inclinata});
}

abstract interface class Guida {
  /// Se su questo telefono la guida c'è.
  bool get disponibile;

  /// La prepara: la prima volta le condizioni di Google, da accettare, poi
  /// la sessione. Prima della [vista].
  Future<EsitoGuida> prepara();

  /// La mappa che segue la persona, con sopra i nostri [segni], la nostra
  /// strada e il nostro puntino: niente grafica di Google, solo il logo
  /// (tela, 163). [inclinata]: in 3D, o in 2D. [qui] è dove il telefono
  /// dice di essere: vale quando la guida non dà la sua posizione sulla
  /// strada. [verso] è dove punta il telefono, in gradi dal nord: il cono
  /// del puntino.
  /// [margini] è lo spazio coperto da quello che le sta sopra. [onSegue]
  /// dice quando la mappa smette di seguire la persona, perché la si è
  /// spostata col dito, e quando torna a farlo.
  Widget vista({
    required List<SegnoMappa> segni,
    required Coordinate centro,
    EdgeInsets margini = EdgeInsets.zero,
    bool inclinata = true,
    Coordinate? qui,
    double? verso,
    required void Function(ControlloGuida controllo) onPronta,
    void Function(bool segue)? onSegue,
  });

  /// Parte, a piedi, verso [posto]: se la tappa ha il posto di Google
  /// ([placeId]) verso quello, che sa dov'è l'ingresso.
  Future<EsitoGuida> parti({
    required String titolo,
    required Coordinate posto,
    String? placeId,
  });

  /// Quanto manca, mentre si cammina.
  Stream<Rimasto> get rimasto;

  /// La svolta che viene, mentre si cammina.
  Stream<Indicazione> get indicazioni;

  /// Si è arrivati.
  Stream<void> get arrivo;

  /// La voce che legge le indicazioni: accesa all'inizio, si spegne e si
  /// riaccende col pulsante (tela, 163).
  Future<void> voce({required bool accesa});

  /// Smette di guidare, e chiude la sessione.
  Future<void> ferma();
}

/// Senza guida: le Mappe del telefono portano lo stesso.
class GuidaAssente implements Guida {
  const GuidaAssente();

  @override
  bool get disponibile => false;

  @override
  Future<EsitoGuida> prepara() async => EsitoGuida.nonDisponibile;

  @override
  Widget vista({
    required List<SegnoMappa> segni,
    required Coordinate centro,
    EdgeInsets margini = EdgeInsets.zero,
    bool inclinata = true,
    Coordinate? qui,
    double? verso,
    required void Function(ControlloGuida controllo) onPronta,
    void Function(bool segue)? onSegue,
  }) => const SizedBox.shrink();

  @override
  Future<EsitoGuida> parti({
    required String titolo,
    required Coordinate posto,
    String? placeId,
  }) async => EsitoGuida.nonDisponibile;

  @override
  Stream<Rimasto> get rimasto => const Stream.empty();

  @override
  Stream<Indicazione> get indicazioni => const Stream.empty();

  @override
  Stream<void> get arrivo => const Stream.empty();

  @override
  Future<void> voce({required bool accesa}) async {}

  @override
  Future<void> ferma() async {}
}
