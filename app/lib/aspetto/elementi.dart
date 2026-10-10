/// I pezzi con cui sono fatte le schermate, come li disegna la tela di
/// Claude Design, stile «Biglietti» (CLAUDE.md, regola 9).
library;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'formati.dart';
import 'movimento.dart';
import 'piattaforma.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Una scheda bianca sul fondo grigio: il contenitore dei contenuti.
class Pannello extends StatelessWidget {
  const Pannello({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.colore,
    this.raggio = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Un colore al posto del bianco.
  final Color? colore;
  final double raggio;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colore ?? Colori.bianco,
      borderRadius: BorderRadius.circular(raggio),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Il titolo di una sezione: «Giorni», «Partecipanti».
class TitoloSezione extends StatelessWidget {
  const TitoloSezione(this.testo, {super.key, this.sotto});

  final String testo;

  /// Una riga piccola sotto: «Ancora senza date».
  final String? sotto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            testo,
            style: Testi.titoloSezione.copyWith(color: Colori.inchiostro),
          ),
        ),
        if (sotto != null) ...[
          const SizedBox(height: 4),
          Text(sotto!, style: Testi.secondario.copyWith(color: Colori.grafite)),
        ],
      ],
    ),
  );
}

/// Il titolo grande di una schermata, in cima ai contenuti.
class TitoloPagina extends StatelessWidget {
  const TitoloPagina(this.testo, {super.key, this.sottotitolo});

  final String testo;
  final String? sottotitolo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            testo,
            style: Testi.titoloGrande.copyWith(color: Colori.inchiostro),
          ),
        ),
        if (sottotitolo != null) ...[
          const SizedBox(height: 12),
          Text(
            sottotitolo!,
            style: Testi.corpo.copyWith(color: Colori.grafite),
          ),
        ],
      ],
    ),
  );
}

/// Le iniziali in un cerchio pieno. Il colore dipende dal nome: la stessa
/// persona ha lo stesso colore in tutti i viaggi.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.nome,
    this.dimensione = 44,
    this.bordo,
  });

  final String nome;
  final double dimensione;
  final Color? bordo;

  @override
  Widget build(BuildContext context) => Container(
    width: dimensione,
    height: dimensione,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: coloreAvatar(nome),
      border: bordo == null ? null : Border.all(color: bordo!, width: 2),
    ),
    child: Text(
      iniziali(nome),
      style: Testi.titoli(
        dimensione * 0.36,
        spaziatura: 0,
        altezza: 1,
        peso: 600,
      ).copyWith(color: Colori.bianco),
    ),
  );
}

/// Fino a tre avatar sovrapposti, poi `+N`.
class PilaAvatar extends StatelessWidget {
  const PilaAvatar({
    super.key,
    required this.nomi,
    this.dimensione = 30,
    this.bordo = Colori.bianco,
  });

  final List<String> nomi;
  final double dimensione;
  final Color bordo;

  @override
  Widget build(BuildContext context) {
    final visibili = nomi.take(3).toList();
    final altri = nomi.length - visibili.length;
    final passo = dimensione * 0.68;
    final larghezza =
        dimensione + passo * (visibili.length - 1 + (altri > 0 ? 1 : 0));
    return SizedBox(
      width: larghezza,
      height: dimensione,
      child: Stack(
        children: [
          for (final (i, nome) in visibili.indexed)
            Positioned(
              left: passo * i,
              child: Avatar(nome: nome, dimensione: dimensione, bordo: bordo),
            ),
          if (altri > 0)
            Positioned(
              left: passo * visibili.length,
              child: Container(
                width: dimensione,
                height: dimensione,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colori.grafite,
                  border: Border.all(color: bordo, width: 2),
                ),
                child: Text(
                  '+$altri',
                  style: TextStyle(
                    fontFamily: Testi.dmSans,
                    color: Colori.bianco,
                    fontSize: dimensione * 0.36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un'etichetta a capsula. Sulle schede bianche è cobalto chiaro; sopra un
/// biglietto colorato è bianca e trasparente. Con un pallino di colore se
/// serve.
class Pillola extends StatelessWidget {
  const Pillola(
    this.testo, {
    super.key,
    this.icona,
    this.suCopertina = false,
    this.colore,
    this.fondo,
    this.pallino,
  });

  final String testo;
  final IconData? icona;

  /// Sopra un biglietto colorato.
  final bool suCopertina;

  /// Il colore del testo: cobalto scuro se non si dice altro.
  final Color? colore;
  final Color? fondo;
  final Color? pallino;

  @override
  Widget build(BuildContext context) {
    final c = suCopertina ? Colori.bianco : (colore ?? Colori.cobaltoScuro);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color:
            fondo ??
            (suCopertina
                ? Colori.bianco.withValues(alpha: 0.18)
                : Colori.cobaltoChiaro),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pallino != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: pallino, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          if (icona != null) ...[
            Icon(icona, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          Text(testo, style: Testi.pillola.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// L'etichetta maiuscola sopra un gruppo: «2026», «Da prendere»,
/// «Impostazioni».
class EtichettaSezione extends StatelessWidget {
  const EtichettaSezione(this.testo, {super.key, this.colore = Colori.grafite});

  final String testo;
  final Color colore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
    child: Semantics(
      header: true,
      child: Text(
        testo.toUpperCase(),
        style: Testi.sezione.copyWith(color: colore),
      ),
    ),
  );
}

/// Una riga bianca che porta altrove (tela, 64): l'icona in un quadrato, il
/// nome, a destra quanto c'è. Senza [onTap] è spenta, e chi la usa dice
/// perché.
class RigaScheda extends StatelessWidget {
  const RigaScheda({
    super.key,
    required this.simbolo,
    required this.titolo,
    required this.onTap,
    this.valore,
    this.sottotitolo,
    this.pericolo = false,
  });

  final IconData simbolo;
  final String titolo;
  final VoidCallback? onTap;

  /// A destra: «9 viaggi», «Euro».
  final String? valore;

  /// Sotto il nome, piccolo.
  final String? sottotitolo;

  /// Porta a togliere qualcosa: nome e icona in rosso (tela, 100).
  final bool pericolo;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.98,
    etichetta: [titolo, ?valore, ?sottotitolo].join(', '),
    child: ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1,
        duration: Ritmo.breve,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colori.bianco,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colori.foschia,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  simbolo,
                  size: 22,
                  color: pericolo ? Colori.pericolo : Colori.inchiostro,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: Testi.evidenza.copyWith(
                        color: pericolo ? Colori.pericolo : Colori.inchiostro,
                      ),
                    ),
                    if (sottotitolo != null)
                      Text(
                        sottotitolo!,
                        style: Testi.didascalia.copyWith(color: Colori.grafite),
                      ),
                  ],
                ),
              ),
              if (valore != null) ...[
                const SizedBox(width: 8),
                Text(
                  valore!,
                  style: Testi.secondario.copyWith(color: Colori.grafite),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                icona(
                  ios: CupertinoIcons.chevron_forward,
                  android: Icons.chevron_right_rounded,
                ),
                size: 16,
                color: Colori.grafite,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// L'icona che apre una riga: cobalto, a tratto, senza fondo.
class IconaTonda extends StatelessWidget {
  const IconaTonda(this.icona, {super.key, this.colore, this.dimensione = 24});

  final IconData icona;
  final Color? colore;
  final double dimensione;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimensione,
    child: Icon(icona, color: colore ?? Colori.cobalto, size: 22),
  );
}

/// Il pulsante quadrato in alto: indietro, codice d'invito, altro. Scuro per
/// tornare indietro e per l'azione che conta, bianco per il resto. Dentro una
/// scheda bianca prende il [fondo] che gli si dà, con l'icona grafite: «…» su
/// una persona, la × di un riquadro.
class PulsanteTondo extends StatelessWidget {
  const PulsanteTondo({
    super.key,
    required this.icona,
    required this.etichetta,
    required this.onPressed,
    this.scuro = false,
    this.fondo,
  });

  final IconData icona;

  /// Cosa legge VoiceOver: il pulsante non ha testo.
  final String etichetta;
  final VoidCallback? onPressed;
  final bool scuro;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    final tinta = scuro
        ? Colori.bianco
        : fondo != null
        ? Colori.grafite
        : Colori.inchiostro;
    return Tooltip(
      message: etichetta,
      excludeFromSemantics: true,
      child: Premibile(
        onTap: onPressed,
        scala: 0.92,
        etichetta: etichetta,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scuro ? Colori.inchiostro : (fondo ?? Colori.bianco),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icona,
            size: 22,
            color: onPressed == null ? tinta.withValues(alpha: 0.35) : tinta,
          ),
        ),
      ),
    );
  }
}

/// L'etichetta sopra un campo: «Email», «Nome».
class _EtichettaCampo extends StatelessWidget {
  const _EtichettaCampo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 6),
    child: Text(testo, style: Testi.etichetta.copyWith(color: Colori.ardesia)),
  );
}

/// Un campo di testo della tela: grigio chiaro, che diventa bianco con il
/// bordo cobalto mentre si scrive. Cupertino su iOS, Material su Android,
/// stesso aspetto.
class Campo extends StatefulWidget {
  const Campo({
    super.key,
    required this.controller,
    required this.segnaposto,
    this.etichetta,
    this.icona,
    this.tastiera,
    this.oscura = false,
    this.suggerimenti,
    this.maiuscole = TextCapitalization.none,
    this.correzione = true,
    this.azione,
    this.onInvio,
    this.onCambia,
    this.fuoco = false,
    this.prefisso,
    this.righe = 1,
    this.lunghezzaMassima,
  });

  final TextEditingController controller;
  final String segnaposto;

  /// Un testo fisso prima di quello che si scrive, in una capsula: «+39».
  final String? prefisso;

  /// Quante righe si vedono: più di una per un testo lungo, che va a capo.
  final int righe;

  /// Oltre, non si scrive.
  final int? lunghezzaMassima;

  /// Sopra il campo, come nella tela. Se manca, conta il segnaposto.
  final String? etichetta;
  final IconData? icona;
  final TextInputType? tastiera;
  final bool oscura;
  final Iterable<String>? suggerimenti;
  final TextCapitalization maiuscole;
  final bool correzione;
  final TextInputAction? azione;
  final ValueChanged<String>? onInvio;
  final ValueChanged<String>? onCambia;

  /// Prende la tastiera appena compare.
  final bool fuoco;

  @override
  State<Campo> createState() => _CampoState();
}

class _CampoState extends State<Campo> {
  final _fuoco = FocusNode();

  @override
  void initState() {
    super.initState();
    _fuoco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fuoco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stile = Testi.campo.copyWith(color: Colori.inchiostro);
    final attivo = _fuoco.hasFocus;
    final forma = BoxDecoration(
      color: attivo ? Colori.bianco : Colori.foschia,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: attivo ? Colori.cobalto : Colori.foschia,
        width: 2,
      ),
    );
    final w = widget;
    final icona = w.prefisso != null
        ? Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: attivo ? Colori.foschia : Colori.bianco,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                w.prefisso!,
                style: Testi.evidenza.copyWith(color: Colori.inchiostro),
              ),
            ),
          )
        : w.icona == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(w.icona, size: 20, color: Colori.cobalto),
          );
    final limite = w.lunghezzaMassima == null
        ? null
        : [LengthLimitingTextInputFormatter(w.lunghezzaMassima)];
    final piuRighe = w.righe > 1;
    final campo = suIOS
        ? CupertinoTextField(
            controller: w.controller,
            focusNode: _fuoco,
            placeholder: w.segnaposto,
            placeholderStyle: stile.copyWith(
              color: Colori.grafite.withValues(alpha: 0.6),
            ),
            style: stile,
            cursorColor: Colori.cobalto,
            prefix: icona,
            padding: EdgeInsets.fromLTRB(icona == null ? 16 : 10, 15, 16, 15),
            decoration: forma,
            keyboardType: w.tastiera,
            obscureText: w.oscura,
            autofillHints: w.suggerimenti,
            textCapitalization: w.maiuscole,
            autocorrect: w.correzione,
            textInputAction: w.azione,
            onSubmitted: w.onInvio,
            onChanged: w.onCambia,
            autofocus: w.fuoco,
            inputFormatters: limite,
            minLines: piuRighe ? w.righe : null,
            maxLines: piuRighe ? w.righe + 2 : 1,
            clearButtonMode: w.onCambia == null || piuRighe
                ? OverlayVisibilityMode.never
                : OverlayVisibilityMode.editing,
          )
        : DecoratedBox(
            decoration: forma,
            child: TextField(
              controller: w.controller,
              focusNode: _fuoco,
              style: stile,
              cursorColor: Colori.cobalto,
              decoration: InputDecoration(
                hintText: w.segnaposto,
                hintStyle: stile.copyWith(
                  color: Colori.grafite.withValues(alpha: 0.6),
                ),
                prefixIcon: icona,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              keyboardType: w.tastiera,
              obscureText: w.oscura,
              autofillHints: w.suggerimenti,
              textCapitalization: w.maiuscole,
              autocorrect: w.correzione,
              textInputAction: w.azione,
              onSubmitted: w.onInvio,
              onChanged: w.onCambia,
              autofocus: w.fuoco,
              inputFormatters: limite,
              minLines: piuRighe ? w.righe : null,
              maxLines: piuRighe ? w.righe + 2 : 1,
            ),
          );
    if (w.etichetta == null) return campo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_EtichettaCampo(w.etichetta!), campo],
    );
  }
}

/// Un riquadro che sembra un campo ma si tocca per scegliere: una data, una
/// destinazione. Come "Scegli la data" della tela.
class CampoScelta extends StatelessWidget {
  const CampoScelta({
    super.key,
    required this.simbolo,
    required this.segnaposto,
    required this.valore,
    required this.onTap,
    this.etichetta,
    this.onCancella,
    this.righe,
  });

  final IconData simbolo;
  final String segnaposto;
  final String? valore;
  final VoidCallback? onTap;
  final String? etichetta;

  /// Toglie il valore, quando è facoltativo: un orario che si era messo.
  final VoidCallback? onCancella;

  /// Al massimo quante righe, per un valore lungo come un indirizzo.
  final int? righe;

  @override
  Widget build(BuildContext context) {
    final riquadro = Premibile(
      onTap: onTap,
      scala: 0.985,
      etichetta: [?etichetta, valore ?? segnaposto].join(': '),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colori.foschia,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(simbolo, size: 22, color: Colori.cobalto),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: Ritmo.breve,
                child: Text(
                  valore ?? segnaposto,
                  key: ValueKey(valore),
                  maxLines: righe,
                  overflow: righe == null ? null : TextOverflow.ellipsis,
                  style: Testi.campo.copyWith(
                    color: valore == null ? Colori.grafite : Colori.inchiostro,
                  ),
                ),
              ),
            ),
            if (onCancella != null && valore != null)
              Semantics(
                button: true,
                label: 'Togli ${etichetta ?? segnaposto}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCancella,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colori.grafite,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (etichetta == null) return riquadro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_EtichettaCampo(etichetta!), riquadro],
    );
  }
}

/// Il pulsante della tela, alto 56. Il principale è d'inchiostro; il
/// secondario è bianco con il bordo grigio.
class PulsanteGrande extends StatelessWidget {
  const PulsanteGrande({
    super.key,
    required this.etichetta,
    required this.onPressed,
    this.secondario = false,
    this.inCorso = false,
    this.motivo,
    this.pericolo = false,
    this.icona,
    this.colore,
  });

  final String etichetta;
  final VoidCallback? onPressed;
  final bool secondario;

  /// Mentre l'azione è in corso il pulsante si spegne e lo dice.
  final bool inCorso;

  /// Perché il pulsante è spento, scritto sotto: un controllo che non si può
  /// usare lo dice prima, non dopo (00-architettura.md, regola 3).
  final String? motivo;

  /// Un'azione che toglie qualcosa: in rosso.
  final bool pericolo;
  final IconData? icona;

  /// Il colore al posto dell'inchiostro: il cobalto di un'azione del viaggio
  /// che sta dentro una scheda (tela, 56).
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final attivo = !inCorso && motivo == null && onPressed != null;
    final tinta = pericolo ? Colori.pericolo : colore ?? Colori.inchiostro;
    final testo = secondario ? tinta : Colori.bianco;
    final pulsante = Semantics(
      enabled: attivo,
      child: Premibile(
        onTap: attivo ? onPressed : null,
        etichetta: inCorso ? 'Un attimo…' : etichetta,
        child: AnimatedOpacity(
          duration: Ritmo.breve,
          opacity: attivo || inCorso ? 1 : 0.35,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: secondario ? Colori.bianco : tinta,
              border: secondario
                  ? Border.all(color: Colori.cenere, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (inCorso) ...[
                  IndicatoreAttivita(colore: testo, piccolo: true),
                  const SizedBox(width: 10),
                ] else if (icona != null) ...[
                  Icon(icona, size: 22, color: testo),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    inCorso ? 'Un attimo…' : etichetta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Testi.pulsante.copyWith(color: testo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnimatedSize(
      duration: Ritmo.medio,
      curve: Ritmo.curva,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pulsante,
          if (motivo != null) ...[
            const SizedBox(height: 8),
            Text(
              motivo!,
              textAlign: TextAlign.center,
              style: Testi.didascalia.copyWith(color: Colori.grafite),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una scelta fra poche: una capsula bianca che diventa d'inchiostro quando
/// è scelta. Per i periodi di un'idea, per i tipi di tappa.
class Gettone extends StatelessWidget {
  const Gettone({
    super.key,
    required this.etichetta,
    required this.scelto,
    required this.onTap,
    this.spunta = false,
  });

  final String etichetta;
  final bool scelto;
  final VoidCallback? onTap;

  /// Una scelta fra tante insieme («Per chi»): scelto, mostra la spunta.
  final bool spunta;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: scelto,
    child: Premibile(
      onTap: onTap,
      scala: 0.94,
      etichetta: etichetta,
      child: AnimatedContainer(
        duration: Ritmo.breve,
        curve: Ritmo.curva,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scelto ? Colori.inchiostro : Colori.bianco,
          border: Border.all(
            color: scelto ? Colori.inchiostro : Colori.cenere,
            width: 2,
          ),
        ),
        // Stretta sul testo: una capsula fra le altre, non una riga intera.
        child: Center(
          widthFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spunta && scelto) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colori.bianco),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  etichetta,
                  style: Testi.secondario.copyWith(
                    color: scelto ? Colori.bianco : Colori.inchiostro,
                    fontWeight: scelto ? FontWeight.w700 : FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Una riga d'avviso, come "Sei offline" della tela: bianca, o rosa quando
/// dice che qualcosa non va.
class Avviso extends StatelessWidget {
  const Avviso({
    super.key,
    required this.icona,
    required this.testo,
    this.colore,
    this.inizio,
    this.azioni = const [],
    this.errore = false,
    this.fondo,
  });

  final IconData icona;
  final String testo;

  /// Il fondo al posto del bianco: dentro un foglio bianco, il grigio dei campi.
  final Color? fondo;

  /// Il colore dell'icona: grafite se non si dice altro.
  final Color? colore;

  /// Le prime parole, in neretto: «Sei offline.»
  final String? inizio;

  /// Pulsanti piccoli sotto il testo: «Riprova», «Scarta».
  final List<Widget> azioni;

  /// Qualcosa non va: fondo rosa, icona rossa.
  final bool errore;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: fondo ?? (errore ? Colori.rosa : Colori.bianco),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                icona,
                color: colore ?? (errore ? Colori.pericolo : Colori.grafite),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (inizio != null)
                      TextSpan(
                        text: '$inizio ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colori.inchiostro,
                        ),
                      ),
                    TextSpan(text: testo),
                  ],
                ),
                style: Testi.secondario.copyWith(
                  color: errore ? Colori.inchiostro : Colori.ardesia,
                ),
              ),
            ),
          ],
        ),
        if (azioni.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: azioni),
          ),
      ],
    ),
  );
}

/// La grande icona in alto di una pagina che spiega prima di chiedere (tela,
/// 58, 59, 100, 101).
class IconaGrande extends StatelessWidget {
  const IconaGrande({
    super.key,
    required this.icona,
    required this.fondo,
    required this.colore,
  });

  final IconData icona;
  final Color fondo;
  final Color colore;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icona, size: 38, color: colore),
      ),
    ),
  );
}

/// Una scheda bianca di righe con un'icona: a che cosa serve, che cosa
/// succede (tela, 58, 100, 101). Nel testo, le parole fra `**` vanno in
/// neretto: «Da **Porto** esci».
class Spiegazione extends StatelessWidget {
  const Spiegazione({
    super.key,
    required this.righe,
    this.colore = Colori.cobalto,
  });

  final List<(IconData, String)> righe;

  /// Il colore delle icone: rosso per quello che si perde.
  final Color colore;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        for (final (i, (simbolo, testo)) in righe.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: i == 0
                ? null
                : const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFEEF0F4), width: 1.5),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(simbolo, size: 20, color: colore),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (final (j, parte) in testo.split('**').indexed)
                          TextSpan(
                            text: parte,
                            style: j.isOdd
                                ? const TextStyle(fontWeight: FontWeight.w700)
                                : null,
                          ),
                      ],
                    ),
                    style: Testi.secondario.copyWith(color: Colori.inchiostro),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Una frase con un rimando dentro: le parole fra `**` si toccano (tela, 1 e
/// 99: «…lo spiega l'**informativa sulla privacy**»). Senza [onTap] il
/// rimando si spegne, e [motivo] dice perché.
class TestoConRimando extends StatefulWidget {
  const TestoConRimando(
    this.testo, {
    super.key,
    required this.onTap,
    this.motivo,
    this.stile,
    this.allineamento = TextAlign.start,
  });

  final String testo;
  final VoidCallback? onTap;
  final String? motivo;
  final TextStyle? stile;
  final TextAlign allineamento;

  @override
  State<TestoConRimando> createState() => _TestoConRimandoState();
}

class _TestoConRimandoState extends State<TestoConRimando> {
  final _tocco = TapGestureRecognizer();

  @override
  void dispose() {
    _tocco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    _tocco.onTap = onTap;
    final base =
        widget.stile ?? Testi.didascalia.copyWith(color: Colori.grafite);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final (i, parte) in widget.testo.split('**').indexed)
            if (i.isOdd)
              TextSpan(
                text: parte,
                recognizer: onTap == null ? null : _tocco,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? Colori.piombo : Colori.cobalto,
                ),
              )
            else
              TextSpan(text: parte),
          if (onTap == null && widget.motivo != null)
            TextSpan(text: ' · ${widget.motivo}'),
        ],
      ),
      textAlign: widget.allineamento,
    );
  }
}

/// «Sei offline», in alto a destra dove di solito c'è il più (tela, 16 e 22).
class SeiOffline extends StatelessWidget {
  const SeiOffline({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colori.bianco,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icona(
            ios: CupertinoIcons.wifi_slash,
            android: Icons.wifi_off_rounded,
          ),
          size: 16,
          color: Colori.ardesia,
        ),
        const SizedBox(width: 8),
        Text(
          'Sei offline',
          style: Testi.didascalia.copyWith(
            color: Colori.ardesia,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Un pulsante piccolo, dentro un avviso o una riga.
class PulsantePiccolo extends StatelessWidget {
  const PulsantePiccolo({
    super.key,
    required this.etichetta,
    required this.onPressed,
    this.pericolo = false,
  });

  final String etichetta;
  final VoidCallback? onPressed;
  final bool pericolo;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onPressed,
    scala: 0.94,
    etichetta: etichetta,
    child: Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colori.foschia,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Una proposta lunga va a capo invece di uscire dal bordo.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  etichetta,
                  style: Testi.secondario.copyWith(
                    color: pericolo ? Colori.pericolo : Colori.cobaltoScuro,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Il nome, come nell'accesso della tela: "Trolley" in Unbounded, bianco.
class Marchio extends StatelessWidget {
  const Marchio({super.key, this.grande = true});

  final bool grande;

  @override
  Widget build(BuildContext context) => Text(
    'Trolley',
    style: (grande ? Testi.marchio : Testi.titoli(34, peso: 800)).copyWith(
      color: Colori.bianco,
    ),
  );
}

class IndicatoreAttivita extends StatelessWidget {
  const IndicatoreAttivita({super.key, this.colore, this.piccolo = false});

  final Color? colore;
  final bool piccolo;

  @override
  Widget build(BuildContext context) => suIOS
      ? CupertinoActivityIndicator(
          color: colore ?? Colori.cobalto,
          radius: piccolo ? 9 : 12,
        )
      : SizedBox.square(
          dimension: piccolo ? 18 : 26,
          child: CircularProgressIndicator(
            strokeWidth: piccolo ? 2.4 : 3,
            color: colore ?? Colori.cobalto,
          ),
        );
}

/// Un messaggio breve in fondo allo schermo.
void mostraMessaggio(
  BuildContext context,
  String testo, {
  bool errore = false,
}) => AdaptiveSnackBar.show(
  context,
  message: testo,
  type: errore ? AdaptiveSnackBarType.error : AdaptiveSnackBarType.info,
);

/// Tiene in vita un elemento di un elenco quando esce dallo schermo, così la
/// sua animazione d'entrata non riparte ogni volta che ci si torna.
class TieniVivo extends StatefulWidget {
  const TieniVivo({super.key, required this.child});

  final Widget child;

  @override
  State<TieniVivo> createState() => _TieniVivoState();
}

class _TieniVivoState extends State<TieniVivo>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
