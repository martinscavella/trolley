/// I biglietti della tela: il viaggio è una carta d'imbarco, l'idea un
/// biglietto giallo. Solo viaggi e idee sono biglietti; il resto sono schede
/// bianche, senza dentelli.
library;

import 'package:flutter/material.dart';

import 'movimento.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Una casella della matrice, sotto la riga tratteggiata: «DAL 12 mag».
class CampoMatrice {
  const CampoMatrice(
    this.etichetta,
    this.valore, {
    this.sotto,
    this.onTap,
    this.azione,
  });

  final String etichetta;
  final String valore;

  /// Una riga piccola sotto il valore: «Aggiungi le date».
  final String? sotto;
  final VoidCallback? onTap;

  /// Cosa fa toccarla, per VoiceOver.
  final String? azione;
}

/// Un biglietto grande: in alto le scritte piccole, il codice di tre lettere
/// e il nome; sotto la riga tratteggiata, la matrice con le sue caselle.
class Biglietto extends StatelessWidget {
  const Biglietto({
    super.key,
    required this.codice,
    required this.nome,
    required this.sinistra,
    this.destra,
    this.campi = const [],
    this.colore = Colori.cobalto,
    this.fondo = Colori.nebbia,
    this.grandezzaCodice = 72,
    this.nomeComeTitolo = false,
    this.onTap,
    this.etichetta,
  });

  /// Tre lettere dalla destinazione, o «?» se non c'è ancora.
  final String codice;
  final String nome;

  /// Le scritte piccole in alto: «IN CORSO», «GIORNO 3 DI 6».
  final String sinistra;
  final String? destra;
  final List<CampoMatrice> campi;

  /// Cobalto per un viaggio, giallo per un'idea, inchiostro per un ricordo.
  final Color colore;

  /// Il colore che sta dietro: si vede nei dentelli.
  final Color fondo;
  final double grandezzaCodice;

  /// Il nome è il titolo della schermata, grande, in Unbounded.
  final bool nomeComeTitolo;

  /// Tutto il biglietto si tocca: nell'elenco dei viaggi.
  final VoidCallback? onTap;

  /// Cosa legge VoiceOver quando tutto il biglietto si tocca.
  final String? etichetta;

  @override
  Widget build(BuildContext context) {
    final chiaro = colore.computeLuminance() > 0.5;
    final testo = chiaro ? Colori.inchiostro : Colori.bianco;
    final piccolo = chiaro
        ? Colori.senape
        : Colori.bianco.withValues(alpha: 0.85);
    final nomeWidget = Text(
      nome,
      style: nomeComeTitolo
          ? Testi.titoloScheda.copyWith(color: testo)
          : Testi.evidenza.copyWith(
              color: testo,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
    );
    final biglietto = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: colore,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sinistra,
                          style: Testi.sezione.copyWith(color: piccolo),
                        ),
                      ),
                      if (destra != null)
                        Text(
                          destra!,
                          style: Testi.sezione.copyWith(color: piccolo),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: Text(
                      codice,
                      style: Testi.codice(grandezzaCodice)
                          .copyWith(color: testo),
                    ),
                  ),
                  SizedBox(height: nomeComeTitolo ? 10 : 6),
                  if (nomeComeTitolo)
                    Semantics(header: true, child: nomeWidget)
                  else
                    nomeWidget,
                ],
              ),
            ),
            if (campi.isNotEmpty) ...[
              _Perforazione(
                fondo: fondo,
                tratto: chiaro
                    ? Colori.inchiostro.withValues(alpha: 0.3)
                    : Colori.bianco.withValues(alpha: 0.45),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, c) in campi.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _Casella(
                          campo: c,
                          testo: testo,
                          piccolo: piccolo,
                          collegamento: chiaro
                              ? Colori.cobaltoScuro
                              : Colori.bianco,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return biglietto;
    return Premibile(
      onTap: onTap,
      scala: 0.98,
      etichetta: etichetta,
      child: ExcludeSemantics(child: biglietto),
    );
  }
}

class _Casella extends StatelessWidget {
  const _Casella({
    required this.campo,
    required this.testo,
    required this.piccolo,
    required this.collegamento,
  });

  final CampoMatrice campo;
  final Color testo;
  final Color piccolo;
  final Color collegamento;

  @override
  Widget build(BuildContext context) {
    final casella = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          campo.etichetta.toUpperCase(),
          style: Testi.sezione.copyWith(color: piccolo),
        ),
        const SizedBox(height: 4),
        Text(campo.valore, style: Testi.numero.copyWith(color: testo)),
        if (campo.sotto != null) ...[
          const SizedBox(height: 4),
          Text(
            campo.sotto!,
            style: Testi.didascalia.copyWith(
              color: campo.onTap == null ? piccolo : collegamento,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
    if (campo.onTap == null) {
      return Semantics(
        label: '${campo.etichetta}: ${campo.valore}',
        excludeSemantics: true,
        child: casella,
      );
    }
    return Premibile(
      onTap: campo.onTap,
      scala: 0.97,
      etichetta:
          '${campo.etichetta}: ${campo.valore}. ${campo.azione ?? campo.sotto ?? ''}',
      child: ExcludeSemantics(child: casella),
    );
  }
}

/// Un biglietto basso, in un elenco, con il codice nella matrice a sinistra:
/// giallo per un'idea; d'inchiostro per un viaggio del passaporto (tela,
/// 65), con il suo timbro a destra.
class BigliettoBasso extends StatelessWidget {
  const BigliettoBasso({
    super.key,
    required this.codice,
    required this.titolo,
    required this.sottotitolo,
    required this.onTap,
    this.colore = Colori.sole,
    this.fondo = Colori.nebbia,
    this.timbro,
    this.etichetta,
  });

  final String codice;
  final String titolo;
  final String sottotitolo;
  final VoidCallback? onTap;
  final Color colore;
  final Color fondo;

  /// A destra: «VERIFICATO».
  final Widget? timbro;
  final String? etichetta;

  static const _matrice = 78.0;

  @override
  Widget build(BuildContext context) {
    final scuro = colore.computeLuminance() < 0.2;
    final testo = scuro ? Colori.bianco : Colori.inchiostro;
    final biglietto = SizedBox(
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: colore,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _matrice,
                child: Center(
                  child: Text(
                    codice,
                    style: Testi.codice(codice == '?' ? 22 : 17)
                        .copyWith(color: testo),
                  ),
                ),
              ),
              _Perforazione(
                fondo: fondo,
                tratto: testo.withValues(alpha: scuro ? 0.4 : 0.3),
                verticale: true,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.evidenza.copyWith(color: testo),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sottotitolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Testi.didascalia.copyWith(
                          color: scuro
                              ? Colori.bianco.withValues(alpha: 0.85)
                              : Colori.senape,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (timbro != null)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(child: timbro),
                ),
            ],
          ),
        ),
      ),
    );
    return Premibile(
      onTap: onTap,
      scala: 0.98,
      etichetta: etichetta ?? '$titolo, $sottotitolo',
      child: ExcludeSemantics(child: biglietto),
    );
  }
}

/// La riga tratteggiata fra la testa e la matrice, con i due dentelli: due
/// cerchi del colore che sta dietro, mezzi dentro e mezzi fuori dal bordo.
class _Perforazione extends StatelessWidget {
  const _Perforazione({
    required this.fondo,
    required this.tratto,
    this.verticale = false,
  });

  final Color fondo;
  final Color tratto;
  final bool verticale;

  @override
  Widget build(BuildContext context) {
    final dente = verticale ? 16.0 : 24.0;
    Widget cerchio() => Container(
      width: dente,
      height: dente,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
    );
    return SizedBox(
      width: verticale ? 2 : null,
      height: verticale ? null : 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: verticale ? 0 : 20,
            right: verticale ? 0 : 20,
            top: verticale ? 12 : 0,
            bottom: verticale ? 12 : 0,
            child: CustomPaint(painter: _Tratteggio(tratto, verticale)),
          ),
          if (verticale) ...[
            Positioned(left: 1 - dente / 2, top: -dente / 2, child: cerchio()),
            Positioned(
              left: 1 - dente / 2,
              bottom: -dente / 2,
              child: cerchio(),
            ),
          ] else ...[
            Positioned(left: -dente / 2, top: 1 - dente / 2, child: cerchio()),
            Positioned(right: -dente / 2, top: 1 - dente / 2, child: cerchio()),
          ],
        ],
      ),
    );
  }
}

class _Tratteggio extends CustomPainter {
  const _Tratteggio(this.colore, this.verticale);

  final Color colore;
  final bool verticale;

  @override
  void paint(Canvas canvas, Size size) {
    final pennello = Paint()
      ..color = colore
      ..strokeWidth = 2;
    final lunghezza = verticale ? size.height : size.width;
    for (var d = 0.0; d < lunghezza; d += 10) {
      final fine = (d + 6).clamp(0, lunghezza).toDouble();
      if (verticale) {
        canvas.drawLine(Offset(1, d), Offset(1, fine), pennello);
      } else {
        canvas.drawLine(Offset(d, 1), Offset(fine, 1), pennello);
      }
    }
  }

  @override
  bool shouldRepaint(_Tratteggio vecchio) =>
      vecchio.colore != colore || vecchio.verticale != verticale;
}
