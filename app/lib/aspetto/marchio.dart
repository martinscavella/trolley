/// Il marchio di Trolley: il logo approvato (la valigia con l'itinerario e la
/// scritta), l'avvio animato e la valigia che aspetta. Vengono dal kit del
/// marchio, il pacchetto `trolley_brand` in `packages/`, che li disegna come
/// vettori: le schermate passano da qui e non parlano col pacchetto.
///
/// Il kit guarda la stessa impostazione di `movimento.dart`: con "Riduci
/// movimento" l'avvio mostra subito il logo finito e la valigia sta ferma.
library;

import 'package:flutter/widgets.dart';
import 'package:trolley_brand/trolley_brand.dart';

import 'movimento.dart';
import 'tavolozza.dart';

/// Il logo completo, bianco: sta sul cobalto della testata dell'accesso.
class Marchio extends StatelessWidget {
  const Marchio({super.key, this.larghezza = 200});

  final double larghezza;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: larghezza,
    child: const TrolleyLogo(color: Colori.bianco),
  );
}

/// L'arrivo della valigia, la frenata e la scritta tracciata dal percorso,
/// sul bianco. Gira una volta sola; [onFinito] dice che si vede il logo
/// intero, non che l'app è pronta.
class AvvioAnimato extends StatelessWidget {
  const AvvioAnimato({super.key, this.onFinito});

  final VoidCallback? onFinito;

  @override
  Widget build(BuildContext context) =>
      TrolleySplash(duration: Ritmo.avvio, onCompleted: onFinito);
}

/// La valigia che si disegna l'itinerario: un'attesa senza percentuale, da
/// togliere quando il lavoro finisce.
class ValigiaCheAspetta extends StatelessWidget {
  const ValigiaCheAspetta({super.key, this.dimensione = 72});

  final double dimensione;

  @override
  Widget build(BuildContext context) => TrolleyLoader(size: dimensione);
}
