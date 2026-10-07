/// I tuoi dati e chiudere l'account (U.1, prima dell'ondata 1; 06, «Diritti
/// delle persone»; tela, 99–102). Dal profilo, sotto Privacy.
///
/// Scaricare e chiudere richiedono la rete: senza, il pulsante si spegne e
/// lo dice. Scaricare si misura (07: `dati_esportati`); chiudere lo misura il
/// server, che è l'ultimo a sapere della persona (`account_chiuso`).
library;

import 'dart:async';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../aspetto/elementi.dart';
import '../aspetto/formati.dart';
import '../aspetto/movimento.dart';
import '../aspetto/pagina.dart';
import '../aspetto/piattaforma.dart';
import '../aspetto/tavolozza.dart';
import '../aspetto/testi.dart';
import '../dati/account.dart';
import '../dati/database.dart';
import '../dati/errori.dart';
import '../dominio/chiusura_account.dart';
import '../misurazione/misurazione.dart';
import '../servizi.dart';
import 'con_la_rete.dart';

/// Consegna il file dei dati: `true` se è uscito, `false` se il foglio si è
/// chiuso senza scegliere niente.
typedef Consegna = Future<bool> Function(File file, Rect? origine);

/// Il foglio di condivisione del telefono: lo si salva in File, o lo si manda.
Future<bool> consegnaCondividendo(File file, Rect? origine) async {
  final esito = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      sharePositionOrigin: origine,
    ),
  );
  return esito.status != ShareResultStatus.dismissed;
}

/// Scarica i propri dati e li consegna. Il file vive il tempo della
/// consegna: contiene tutto, e non resta in giro sul telefono.
Future<void> scaricaIMieiDati(
  BuildContext context, {
  required Future<Directory> Function() cartella,
  required Consegna consegna,
}) async {
  final servizi = Servizi.of(context);
  final scatola = context.findRenderObject() as RenderBox?;
  final origine = scatola == null
      ? null
      : scatola.localToGlobal(Offset.zero) & scatola.size;
  File? file;
  try {
    file = await scriviIMieiDati(
      servizi.archivio,
      cartella: await cartella(),
      oggi: DateTime.now(),
    );
    if (await consegna(file, origine)) {
      await servizi.misurazione.registra(Eventi.datiEsportati);
      unawaited(servizi.misurazione.invia());
    }
  } on ErroreTrolley catch (e) {
    if (context.mounted) mostraMessaggio(context, e.messaggio, errore: true);
  } finally {
    try {
      await file?.delete();
    } on FileSystemException {
      // È nella cartella temporanea: il telefono la svuota da sé.
    }
  }
}

/// «I tuoi dati» (tela, 100): scaricarli, e la porta per chiudere l'account.
class SchermataITuoiDati extends StatefulWidget {
  const SchermataITuoiDati({
    super.key,
    this.cartella = getTemporaryDirectory,
    this.consegna = consegnaCondividendo,
  });

  /// Dove nasce il file, il tempo di consegnarlo.
  final Future<Directory> Function() cartella;
  final Consegna consegna;

  @override
  State<SchermataITuoiDati> createState() => _SchermataITuoiDatiState();
}

class _SchermataITuoiDatiState extends State<SchermataITuoiDati> {
  bool _inCorso = false;

  Future<void> _scarica(BuildContext daDove) async {
    setState(() => _inCorso = true);
    await scaricaIMieiDati(
      daDove,
      cartella: widget.cartella,
      consegna: widget.consegna,
    );
    if (mounted) setState(() => _inCorso = false);
  }

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          IconaGrande(
            icona: icona(
              ios: CupertinoIcons.arrow_down_doc,
              android: Icons.download_rounded,
            ),
            fondo: Colori.cobaltoChiaro,
            colore: Colori.cobalto,
          ).entra(context),
          const SizedBox(height: 18),
          const TitoloPagina(
            'I tuoi dati',
            sottotitolo:
                "Sono tuoi: puoi portarli via quando vuoi, gratis, e chiudere "
                "l'account da qui.",
          ).entra(context),
          Spiegazione(
            righe: [
              (
                icona(
                  ios: CupertinoIcons.doc_text,
                  android: Icons.description_outlined,
                ),
                'Un file con il profilo, i viaggi come li vedi tu, le tappe, '
                    'le spese, le liste, i traguardi e le azioni misurate.',
              ),
              (
                icona(ios: CupertinoIcons.lock, android: Icons.lock_outline),
                'I documenti non ci sono: stanno solo su questo telefono, e '
                    'restano tuoi anche così.',
              ),
            ],
          ).entra(context, ritardo: Ritmo.passo),
          const SizedBox(height: 24),
          ConLaRete(
            builder: (context, rete) => Builder(
              builder: (daDove) => PulsanteGrande(
                etichetta: 'Scarica i tuoi dati',
                inCorso: _inCorso,
                motivo: rete ? null : motivoSenzaRete,
                onPressed: rete && !_inCorso ? () => _scarica(daDove) : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si apre la condivisione: lo salvi in File o lo mandi dove vuoi.',
            textAlign: TextAlign.center,
            style: Testi.didascalia.copyWith(color: Colori.grafite),
          ),
          const SizedBox(height: 26),
          const EtichettaSezione("Chiudere l'account"),
          RigaScheda(
            simbolo: icona(
              ios: CupertinoIcons.square_arrow_left,
              android: Icons.logout_rounded,
            ),
            titolo: "Chiudi l'account",
            sottotitolo: 'Prima ti diciamo cosa succede',
            pericolo: true,
            onTap: () => apri<void>(
              context,
              SchermataChiudiAccount(
                cartella: widget.cartella,
                consegna: widget.consegna,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Che cosa si perde, con i numeri veri (tela, 101).
typedef _Conto = ({
  ChiusuraAccount<Viaggio> viaggi,
  int documenti,
  int nonArrivati,
});

/// «Chiudere l'account?» (tela, 101 e 102): che cosa succede, poi il dialogo
/// di sistema. Non si torna indietro.
class SchermataChiudiAccount extends StatefulWidget {
  const SchermataChiudiAccount({
    super.key,
    this.cartella = getTemporaryDirectory,
    this.consegna = consegnaCondividendo,
  });

  final Future<Directory> Function() cartella;
  final Consegna consegna;

  @override
  State<SchermataChiudiAccount> createState() => _SchermataChiudiAccountState();
}

class _SchermataChiudiAccountState extends State<SchermataChiudiAccount> {
  Future<_Conto>? _conto;
  bool _inCorso = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_conto != null) return;
    _conto = _conta();
    // Dalla copia subito; con la rete, di nuovo dopo averla aggiornata: è
    // quello che il server farà.
    final servizi = Servizi.of(context);
    if (servizi.rete.disponibile) {
      unawaited(
        servizi.archivio.aggiornaCopia().then((_) {
          if (!mounted) return;
          // Un blocco, non una freccia: l'assegnazione varrebbe il Future, e
          // setState non lo accetta.
          setState(() {
            _conto = _conta();
          });
        }, onError: (_) {}),
      );
    }
  }

  Future<_Conto> _conta() async {
    final servizi = Servizi.of(context);
    final archivio = servizi.archivio;
    return (
      viaggi: cosaSuccede(await archivio.viaggiDaChiudereConLAccount()),
      documenti: await servizi.documenti.osservaQuanti().first,
      nonArrivati: await archivio.coda.quante(),
    );
  }

  Future<void> _conferma() => AdaptiveAlertDialog.show(
    context: context,
    title: "Chiudere l'account?",
    message:
        'Non si può annullare: il tuo account, i viaggi in cui sei da solo e '
        'i documenti su questo telefono non si recuperano.',
    actions: [
      AlertAction(
        title: 'Annulla',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Chiudi',
        style: AlertActionStyle.destructive,
        onPressed: _chiudi,
      ),
    ],
  );

  /// Prima il server: se non chiude, il telefono resta com'è. Poi i propri
  /// documenti, la copia e l'accesso; l'app torna all'accesso da sola.
  Future<void> _chiudi() async {
    final servizi = Servizi.of(context);
    final io = servizi.supabase.auth.currentUser?.id;
    if (io == null) return;
    setState(() => _inCorso = true);
    try {
      await chiudiLAccountSulServer(
        archivio: servizi.archivio,
        misurazione: servizi.misurazione,
      );
    } on ErroreTrolley catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      mostraMessaggio(context, e.messaggio, errore: true);
      return;
    }
    try {
      await servizi.documenti.eliminaQuelliDi(io);
    } on Object {
      // L'account è chiuso comunque: un file che non si cancella resta nella
      // cartella dell'app, e se ne va con lei.
    }
    await lasciaIlTelefono(
      archivio: servizi.archivio,
      accesso: servizi.supabase.auth,
    );
  }

  List<(IconData, String)> _righe(_Conto conto) {
    final ChiusuraAccount(:cancellati, :lasciati, :passaggi) = conto.viaggi;
    return [
      (
        icona(ios: CupertinoIcons.person, android: Icons.person_outline),
        "Il tuo profilo e l'accesso si cancellano: il nome, l'email, la data "
            'di nascita.',
      ),
      if (cancellati.length == 1)
        (
          icona(ios: CupertinoIcons.trash, android: Icons.delete_outline),
          '**Un viaggio** in cui sei da solo si cancella, con quello che '
              'c\'è dentro.',
        )
      else if (cancellati.isNotEmpty)
        (
          icona(ios: CupertinoIcons.trash, android: Icons.delete_outline),
          '**${cancellati.length} viaggi** in cui sei da solo, con le idee e '
              'il passaporto, si cancellano.',
        ),
      if (lasciati.isNotEmpty) ...[
        (
          icona(ios: CupertinoIcons.person_2, android: Icons.group_outlined),
          'Da ${_mete(lasciati)} esci: quello che hai aggiunto resta, senza '
              'il tuo nome.',
        ),
        (
          icona(
            ios: CupertinoIcons.creditcard,
            android: Icons.payments_outlined,
          ),
          "Le spese restano nei saldi: chiudere l'account non cancella un "
              'debito.',
        ),
      ],
      for (final (viaggio, erede) in passaggi)
        (
          icona(ios: CupertinoIcons.star, android: Icons.star_outline_rounded),
          'A **${titoloViaggio(viaggio)}** eri responsabile: il ruolo passa a '
              '**${erede.nome}**.',
        ),
      if (conto.documenti > 0)
        (
          icona(
            ios: CupertinoIcons.doc,
            android: Icons.insert_drive_file_outlined,
          ),
          conto.documenti == 1
              ? '**Il documento** su questo telefono si cancella.'
              : '**I ${conto.documenti} documenti** su questo telefono si '
                    'cancellano.',
        ),
      if (conto.nonArrivati > 0)
        (
          icona(
            ios: CupertinoIcons.wifi_slash,
            android: Icons.wifi_off_rounded,
          ),
          conto.nonArrivati == 1
              ? '**Una cosa** fatta senza rete non è arrivata: si perde.'
              : '**${conto.nonArrivati} cose** fatte senza rete non sono '
                    'arrivate: si perdono.',
        ),
    ];
  }

  /// «**Porto** e **Berlino**»; oltre tre, «**Porto**, **Lisbona** e altri 2».
  static String _mete(List<Viaggio> viaggi) {
    final nomi = [for (final v in viaggi) '**${titoloViaggio(v)}**'];
    if (nomi.length <= 3) return insieme(nomi);
    return insieme([...nomi.take(2), 'altri ${nomi.length - 2}']);
  }

  @override
  Widget build(BuildContext context) => Pagina(
    corpo: Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          IconaGrande(
            icona: icona(
              ios: CupertinoIcons.square_arrow_left,
              android: Icons.logout_rounded,
            ),
            fondo: Colori.rosa,
            colore: Colori.pericolo,
          ).entra(context),
          const SizedBox(height: 18),
          const TitoloPagina(
            "Chiudere l'account?",
            sottotitolo: 'Non si torna indietro. Ecco cosa succede.',
          ).entra(context),
          FutureBuilder<_Conto>(
            future: _conto,
            builder: (context, conto) => conto.hasData
                ? Spiegazione(
                    righe: _righe(conto.data!),
                    colore: Colori.pericolo,
                  ).entra(context, ritardo: Ritmo.passo)
                : const SizedBox(height: 120),
          ),
          const SizedBox(height: 24),
          ConLaRete(
            builder: (context, rete) => PulsanteGrande(
              etichetta: "Chiudi l'account",
              pericolo: true,
              inCorso: _inCorso,
              motivo: rete ? null : motivoSenzaRete,
              onPressed: rete && !_inCorso ? _conferma : null,
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (daDove) => ConLaRete(
              builder: (context, rete) => PulsanteGrande(
                etichetta: 'Scarica prima i tuoi dati',
                secondario: true,
                onPressed: rete && !_inCorso
                    ? () => scaricaIMieiDati(
                        daDove,
                        cartella: widget.cartella,
                        consegna: widget.consegna,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
