/// La chiusura di un viaggio (fase 4.1; 10-chiusura-e-ricordo.md), dal
/// telefono di chi la vede: chiudere sul server, riprendere l'ultima versione
/// del viaggio, dire se è verificato per sé, prendere i traguardi, misurare.
///
/// Le regole sono nel dominio (chiusura, verifica, traguardi); qui c'è
/// l'ordine in cui si fanno. Richiede la rete: senza, il viaggio resta da
/// chiudere e ci si riprova alla prossima apertura.
library;

import '../dominio/calendario.dart';
import '../dominio/chiusura.dart';
import '../dominio/tappe.dart';
import '../dominio/traguardi.dart';
import '../dominio/verifica.dart';
import '../misurazione/misurazione.dart';
import 'archivio.dart';
import 'database.dart';
import 'errori.dart';
import 'lettura.dart';

/// Com'è andata la chiusura, per il riepilogo.
class EsitoChiusura {
  const EsitoChiusura({required this.verifica, required this.nuovi});

  final EsitoVerifica verifica;

  /// I traguardi presi con questo viaggio adesso.
  final Set<Traguardo> nuovi;
}

/// I propri viaggi da chiudere, il più recente prima: quelli finiti che il
/// server dice ancora definiti, e quelli chiusi senza ancora la propria
/// verifica (chiusi da un compagno, o a metà per la rete). Mai gli importati.
Future<List<Viaggio>> viaggiDaChiudere(Archivio archivio, DateTime oggi) async {
  final da = [
    for (final (p, v) in await archivio.mieiViaggi())
      if (p.stato == 'attivo' &&
          v.eliminatoIl == null &&
          !v.importato &&
          (daChiudereDaSolo(registrato: v.stato, fine: v.fine, oggi: oggi) ||
              (v.stato == 'chiuso' && p.verificato == null)))
        v,
  ];
  return da..sort((a, b) => (b.fine ?? b.creato).compareTo(a.fine ?? a.creato));
}

/// Chiude il viaggio per chi ha il telefono in mano. [aMano]: lo chiude chi ne
/// è responsabile prima della fine (tela, 63).
Future<EsitoChiusura> chiudiIlViaggio({
  required String viaggioId,
  required Archivio archivio,
  required Misurazione misurazione,
  bool aMano = false,
}) async {
  final prima = await archivio.leggiViaggio(viaggioId);
  if (prima == null) {
    throw const ErroreTrolley('Questo viaggio non è sul telefono.');
  }
  if (prima.stato != 'chiuso') await archivio.chiudiViaggio(viaggioId);
  // L'ultima versione, con i gesti in coda già arrivati: la verifica guarda
  // le tappe di tutti.
  await archivio.aggiornaCopia(viaggioId: viaggioId);
  final viaggio = (await archivio.leggiViaggio(viaggioId))!;
  final giorni = await archivio.leggiGiorni(viaggioId);
  final tappe = await archivio.leggiTappe(viaggioId);
  final presenti = await archivio.leggiPresenti(viaggioId);
  var mia = await archivio.miaPartecipazione(viaggioId);

  final esito = verificaDelViaggio(
    giorni: [for (final g in giorni) g.id],
    tappe: [
      for (final t in tappe)
        (
          giornoId: t.giornoId,
          stato: t.statoTappa,
          duranteIlViaggio: t.marcataDuranteIlViaggio,
        ),
    ],
    sulPosto: mia?.sulPostoIl != null,
    importato: viaggio.importato,
    perDeroga: viaggio.verificaPerDeroga,
  );
  if (mia?.verificato == null) {
    await archivio.segnaVerifica(viaggioId, verificato: esito.verificato);
    mia = await archivio.miaPartecipazione(viaggioId);
  }
  // Se l'aveva già scritta un altro telefono della stessa persona, vale
  // quella.
  final verificato = mia?.verificato ?? esito.verificato;

  var nuovi = <Traguardo>{};
  if (verificato) {
    final presi = {
      for (final t in await archivio.leggiTraguardi()) ?Traguardo.leggi(t.tipo),
    };
    final verificati = [
      for (final (p, v) in await archivio.mieiViaggi())
        if (p.verificato == true || v.id == viaggioId) ?_perTraguardi(v),
    ];
    final questo = _perTraguardi(
      viaggio,
      persone: presenti.length,
      responsabile: mia?.ruolo == 'creatore',
      fattePerGiorno: [
        for (final g in giorni)
          tappe
              .where(
                (t) =>
                    t.giornoId == g.id && t.statoTappa == StatoTappa.completata,
              )
              .length,
      ],
    );
    if (questo != null) {
      nuovi = traguardiNuovi(
        questo: questo,
        verificati: verificati,
        presi: presi,
      );
      if (nuovi.isNotEmpty) {
        await archivio.prendiTraguardi(viaggioId, [
          for (final t in nuovi) t.codice,
        ]);
      }
    }
  }

  final giorniIds = {for (final g in giorni) g.id};
  final contate = [
    for (final t in tappe)
      if (giorniIds.contains(t.giornoId)) t,
  ];
  await misurazione.registraUnaVolta(
    'chiuso:$viaggioId',
    Eventi.viaggioChiuso,
    {
      'viaggio_id': viaggioId,
      'verificato': verificato,
      'mancate': [for (final c in esito.mancanti) _codice(c)],
      'punti_viaggio': puntiViaggio(giorni.length),
      'per_deroga': viaggio.verificaPerDeroga,
      'a_mano': aMano,
      'tappe': contate.length,
      'segnate_durante': contate
          .where((t) => t.statoTappa.segnata && t.marcataDuranteIlViaggio)
          .length,
    },
  );
  return EsitoChiusura(
    verifica: verificato == esito.verificato
        ? esito
        : EsitoVerifica(verificato ? const {} : esito.mancanti),
    nuovi: nuovi,
  );
}

String _codice(CondizioneVerifica c) => switch (c) {
  CondizioneVerifica.unaTappaPerGiorno => 'una_tappa_per_giorno',
  CondizioneVerifica.sulPosto => 'sul_posto',
  CondizioneVerifica.tappeSegnate => 'tappe_segnate',
};

/// Un viaggio come lo guardano i traguardi. Per quelli già chiusi bastano
/// meta e date: persone, ruolo e tappe contano solo per quello che si chiude.
ViaggioVerificato? _perTraguardi(
  Viaggio v, {
  int persone = 1,
  bool responsabile = false,
  List<int> fattePerGiorno = const [],
}) {
  final (inizio, fine) = (v.inizio, v.fine);
  if (inizio == null || fine == null) return null;
  return (
    id: v.id,
    inizio: soloData(inizio),
    fine: soloData(fine),
    paese: v.destinazionePaese,
    citta: v.destinazioneCitta,
    persone: persone,
    responsabile: responsabile,
    fattePerGiorno: fattePerGiorno,
  );
}
