/// I pezzi con cui sono fatte le schermate.
library;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'formati.dart';
import 'movimento.dart';
import 'piattaforma.dart';
import 'tavolozza.dart';
import 'testi.dart';

/// Un pannello: il contenitore dei contenuti, pieno e con gli angoli continui
/// di iOS. Il vetro no: quello è per la navigazione, non per i contenuti.
class Pannello extends StatelessWidget {
  const Pannello({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.colore,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colore ?? t.superficie,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        shadows: t.scuro
            ? null
            : const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class TitoloSezione extends StatelessWidget {
  const TitoloSezione(this.testo, {super.key});

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Text(
      testo,
      style: Testi.titoloSezione.copyWith(color: Tavolozza.of(context).testo),
    ),
  );
}

/// Le iniziali in un cerchio colorato. Il colore dipende dal nome: la stessa
/// persona ha lo stesso colore in tutti i viaggi.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.nome,
    this.dimensione = 36,
    this.bordo,
  });

  final String nome;
  final double dimensione;
  final Color? bordo;

  @override
  Widget build(BuildContext context) {
    final colore = coloreAvatar(nome);
    return Container(
      width: dimensione,
      height: dimensione,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colore, Colors.white, 0.18)!,
            Color.lerp(colore, Colors.black, 0.12)!,
          ],
        ),
        border: bordo == null ? null : Border.all(color: bordo!, width: 2),
      ),
      child: Text(
        iniziali(nome),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: dimensione * 0.38,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Fino a tre avatar sovrapposti, poi `+N`.
class PilaAvatar extends StatelessWidget {
  const PilaAvatar({
    super.key,
    required this.nomi,
    this.dimensione = 30,
    this.bordo = Colors.white,
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
                  color: const Color(0x55000000),
                  border: Border.all(color: bordo, width: 2),
                ),
                child: Text(
                  '+$altri',
                  style: TextStyle(
                    color: Colors.white,
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

/// Un'etichetta a capsula. Sulle copertine è bianca e traslucida.
class Pillola extends StatelessWidget {
  const Pillola(this.testo, {super.key, this.icona, this.suCopertina = false});

  final String testo;
  final IconData? icona;
  final bool suCopertina;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final colore = suCopertina ? Colors.white : t.accento;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: suCopertina
            ? const Color(0x33FFFFFF)
            : t.accento.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icona != null) ...[
              Icon(icona, size: 13, color: colore),
              const SizedBox(width: 4),
            ],
            Text(testo, style: Testi.etichetta.copyWith(color: colore)),
          ],
        ),
      ),
    );
  }
}

/// Un'icona in un tondo tinto: apre le righe dei pannelli.
class IconaTonda extends StatelessWidget {
  const IconaTonda(this.icona, {super.key, this.colore, this.dimensione = 40});

  final IconData icona;
  final Color? colore;
  final double dimensione;

  @override
  Widget build(BuildContext context) {
    final c = colore ?? Tavolozza.of(context).accento;
    return Container(
      width: dimensione,
      height: dimensione,
      decoration: ShapeDecoration(
        color: c.withValues(alpha: 0.14),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(dimensione * 0.32),
        ),
      ),
      child: Icon(icona, color: c, size: dimensione * 0.52),
    );
  }
}

/// Un campo di testo: Cupertino su iOS, Material su Android, stesso aspetto.
class Campo extends StatelessWidget {
  const Campo({
    super.key,
    required this.controller,
    required this.segnaposto,
    this.icona,
    this.tastiera,
    this.oscura = false,
    this.suggerimenti,
    this.maiuscole = TextCapitalization.none,
    this.correzione = true,
    this.azione,
    this.onInvio,
  });

  final TextEditingController controller;
  final String segnaposto;
  final IconData? icona;
  final TextInputType? tastiera;
  final bool oscura;
  final Iterable<String>? suggerimenti;
  final TextCapitalization maiuscole;
  final bool correzione;
  final TextInputAction? azione;
  final ValueChanged<String>? onInvio;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final stile = Testi.corpo.copyWith(color: t.testo);
    if (suIOS) {
      return CupertinoTextField(
        controller: controller,
        placeholder: segnaposto,
        placeholderStyle: stile.copyWith(color: t.testoTerziario),
        style: stile,
        prefix: icona == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(icona, size: 20, color: t.testoSecondario),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: t.riempimento,
          borderRadius: BorderRadius.circular(14),
        ),
        keyboardType: tastiera,
        obscureText: oscura,
        autofillHints: suggerimenti,
        textCapitalization: maiuscole,
        autocorrect: correzione,
        textInputAction: azione,
        onSubmitted: onInvio,
      );
    }
    return TextField(
      controller: controller,
      style: stile,
      decoration: InputDecoration(
        hintText: segnaposto,
        prefixIcon: icona == null ? null : Icon(icona),
        filled: true,
        fillColor: t.riempimento,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: tastiera,
      obscureText: oscura,
      autofillHints: suggerimenti,
      textCapitalization: maiuscole,
      autocorrect: correzione,
      textInputAction: azione,
      onSubmitted: onInvio,
    );
  }
}

/// Una riga che sembra un campo ma si tocca per scegliere (per esempio una data).
class CampoScelta extends StatelessWidget {
  const CampoScelta({
    super.key,
    required this.simbolo,
    required this.segnaposto,
    required this.valore,
    required this.onTap,
  });

  final IconData simbolo;
  final String segnaposto;
  final String? valore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return Premibile(
      onTap: onTap,
      scala: 0.985,
      etichetta: valore ?? segnaposto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: t.riempimento,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(simbolo, size: 20, color: t.testoSecondario),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: Ritmo.breve,
                child: Text(
                  valore ?? segnaposto,
                  key: ValueKey(valore),
                  style: Testi.corpo.copyWith(
                    color: valore == null ? t.testoTerziario : t.testo,
                  ),
                ),
              ),
            ),
            Icon(
              icona(
                ios: CupertinoIcons.chevron_down,
                android: Icons.expand_more,
              ),
              size: 16,
              color: t.testoTerziario,
            ),
          ],
        ),
      ),
    );
  }
}

/// Il pulsante principale di una schermata, largo quanto lo spazio. Su iOS 26
/// è un pulsante di sistema.
class PulsanteGrande extends StatelessWidget {
  const PulsanteGrande({
    super.key,
    required this.etichetta,
    required this.onPressed,
    this.secondario = false,
    this.inCorso = false,
  });

  final String etichetta;
  final VoidCallback? onPressed;
  final bool secondario;

  /// Mentre l'azione è in corso il pulsante si spegne e lo dice.
  final bool inCorso;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    return SizedBox(
      width: double.infinity,
      child: AdaptiveButton(
        label: inCorso ? 'Un attimo…' : etichetta,
        onPressed: inCorso ? null : onPressed,
        enabled: !inCorso && onPressed != null,
        style: secondario
            ? AdaptiveButtonStyle.plain
            : AdaptiveButtonStyle.filled,
        size: AdaptiveButtonSize.large,
        color: t.accento,
        textColor: secondario ? t.accento : t.suAccento,
        useSmoothRectangleBorder: false,
      ),
    );
  }
}

/// Una riga d'avviso dentro un pannello: offline, invito in attesa, errori.
class Avviso extends StatelessWidget {
  const Avviso({
    super.key,
    required this.icona,
    required this.testo,
    this.colore,
  });

  final IconData icona;
  final String testo;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final t = Tavolozza.of(context);
    final c = colore ?? t.accento;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.withValues(alpha: 0.12),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icona, color: c, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                testo,
                style: Testi.secondario.copyWith(color: t.testo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il marchio provvisorio: un'icona e il nome in codice.
class Marchio extends StatelessWidget {
  const Marchio({super.key, this.grande = true});

  final bool grande;

  @override
  Widget build(BuildContext context) {
    final lato = grande ? 64.0 : 48.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: lato,
          height: lato,
          decoration: ShapeDecoration(
            color: const Color(0x2EFFFFFF),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(lato * 0.3),
              side: const BorderSide(color: Color(0x4DFFFFFF)),
            ),
          ),
          child: Icon(
            Icons.luggage_rounded,
            color: Colors.white,
            size: lato * 0.52,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Trolley',
          style: TextStyle(
            color: Colors.white,
            fontSize: grande ? 40 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class IndicatoreAttivita extends StatelessWidget {
  const IndicatoreAttivita({super.key, this.colore});

  final Color? colore;

  @override
  Widget build(BuildContext context) => suIOS
      ? CupertinoActivityIndicator(color: colore, radius: 12)
      : SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 3, color: colore),
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
