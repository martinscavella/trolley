import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../aspetto/elementi.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dominio/valute.dart';

/// Una valuta, da tutto l'elenco: si cerca per codice o per nome, anche senza
/// rete. Restituisce il codice.
class SchermataValuta extends StatefulWidget {
  const SchermataValuta({
    super.key,
    this.titolo = 'Che valuta?',
    this.spiegazione,
    this.scelta,
  });

  final String titolo;
  final String? spiegazione;

  /// Quella scelta adesso, segnata nell'elenco.
  final String? scelta;

  @override
  State<SchermataValuta> createState() => _SchermataValutaState();
}

class _SchermataValutaState extends State<SchermataValuta> {
  final _testo = TextEditingController();

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  void _scegli(Valuta v) => Navigator.of(context).pop(v.codice);

  @override
  Widget build(BuildContext context) {
    final risultati = cercaValute(_testo.text);
    final t = Tavolozza.of(context);
    return Pagina(
      corpo: Builder(
        builder: (context) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.titolo,
                    style: Testi.titoloGrande.copyWith(
                      color: Colori.inchiostro,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Campo(
                  controller: _testo,
                  segnaposto: 'Dollaro, yen, GBP…',
                  icona: icona(
                    ios: CupertinoIcons.search,
                    android: Icons.search,
                  ),
                  correzione: false,
                  azione: TextInputAction.search,
                  onCambia: (_) => setState(() {}),
                  onInvio: (_) {
                    if (risultati.isNotEmpty) _scegli(risultati.first);
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: [
                    if (widget.spiegazione != null && _testo.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                        child: Text(
                          widget.spiegazione!,
                          style: Testi.secondario.copyWith(
                            color: t.testoSecondario,
                          ),
                        ),
                      ),
                    if (risultati.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                        child: Text(
                          'Nessuna valuta con questo nome.',
                          style: Testi.secondario.copyWith(
                            color: t.testoSecondario,
                          ),
                        ),
                      )
                    else
                      Pannello(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: [
                            for (final (i, v) in risultati.indexed) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: 62,
                                  color: t.separatore,
                                ),
                              _RigaValuta(
                                valuta: v,
                                scelta: v.codice == widget.scelta,
                                onTap: () => _scegli(v),
                              ),
                            ],
                          ],
                        ),
                      ).entra(context, da: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RigaValuta extends StatelessWidget {
  const _RigaValuta({
    required this.valuta,
    required this.scelta,
    required this.onTap,
  });

  final Valuta valuta;
  final bool scelta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
    onTap: onTap,
    scala: 0.985,
    etichetta: '${valuta.nome}, ${valuta.codice}${scelta ? ', scelta' : ''}',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                valuta.codice,
                style: Testi.titoli(
                  13,
                  spaziatura: 0,
                  peso: 700,
                ).copyWith(color: Colori.cobalto),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                valuta.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Testi.evidenza.copyWith(color: Colori.inchiostro),
              ),
            ),
            if (scelta)
              Icon(
                icona(
                  ios: CupertinoIcons.checkmark_alt,
                  android: Icons.check_rounded,
                ),
                size: 20,
                color: Colori.cobalto,
              ),
          ],
        ),
      ),
    ),
  );
}
