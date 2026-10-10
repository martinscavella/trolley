/// La parte pubblica e la sua sicurezza, sul server (5.1; sicurezza.sql): il
/// proprio profilo pubblico, chi si è bloccato, le proprie segnalazioni. Con
/// la 5.3 (profilo_pubblico.sql) i profili degli altri, la ricerca, i gusti e
/// i viaggi sul profilo.
///
/// Tutto richiede la rete, e niente sta nella copia del telefono: la parte
/// pubblica è fatta di altre persone, e si guarda com'è adesso (11, 12). Chi
/// può fare che cosa lo decide il server; qui si traducono i suoi no.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/itinerario.dart';
import '../dominio/parte_pubblica.dart';
import '../dominio/profilo_pubblico.dart';
import 'errori.dart';
import 'rete.dart';

class PartePubblica {
  PartePubblica(this._supabase, {this.rete, this.ricorda});

  final SupabaseClient _supabase;
  final Rete? rete;

  /// Chiamata ogni volta che si sa se per questa persona la parte pubblica
  /// c'è (aperta, o per il team) ed è maggiorenne: il telefono lo ricorda,
  /// per mettere Community nella barra anche senza rete (5.3).
  final Future<void> Function(bool)? ricorda;

  /// Come in Archivio: `rest`, perché applica le opzioni del client.
  PostgrestClient get _server => _supabase.rest;

  Future<T> _alServer<T>(
    Future<T> Function() chiamata, {
    Map<String, String> messaggi = const {},
  }) => alServer(chiamata, messaggi: messaggi, rete: rete);

  /// Com'è la parte pubblica per chi è dentro. `null` senza profilo.
  Future<StatoPartePubblica?> stato() async {
    final riga = await _alServer(
      () => _server.rpc<Map<String, dynamic>?>('la_mia_parte_pubblica'),
    );
    final stato = riga == null ? null : StatoPartePubblica.daServer(riga);
    await ricorda?.call(stato != null && stato.visibile && stato.maggiorenne);
    return stato;
  }

  /// Accende il profilo pubblico, accettando le condizioni d'uso nella
  /// versione [condizioni] (dati/pagine.dart).
  Future<void> accendi({required String condizioni}) => _alServer(
    () => _server.rpc<dynamic>(
      'attiva_profilo_pubblico',
      params: {'p_condizioni': condizioni},
    ),
    messaggi: const {
      CodiciServer.partePubblicaChiusa:
          'Per ora la parte pubblica non accoglie profili nuovi: riprova tra '
          'qualche giorno.',
      CodiciServer.profiloSospeso: 'Il tuo profilo pubblico è sospeso.',
      CodiciServer.nonPermesso:
          'Servono il numero di telefono verificato e 18 anni compiuti.',
    },
  );

  /// Lo spegne: si sparisce dalla parte pubblica.
  Future<void> spegni() =>
      _alServer(() => _server.rpc<dynamic>('spegni_profilo_pubblico'));

  /// Blocca [utenteId]: non vi vedete più, e non lo sa (12, regole 3 e 4).
  Future<void> blocca(String utenteId) => _alServer(
    () => _server.rpc<dynamic>('blocca', params: {'p_utente': utenteId}),
    messaggi: const {
      CodiciServer.nonTrovato: 'Questa persona non c\'è più su Trolley.',
    },
  );

  Future<void> sblocca(String utenteId) => _alServer(
    () => _server.rpc<dynamic>('sblocca', params: {'p_utente': utenteId}),
  );

  /// Chi si è bloccato, dal più recente.
  Future<List<PersonaBloccata>> personeBloccate() async {
    final righe = await _alServer(
      () => _server.rpc<List<dynamic>>('persone_bloccate'),
    );
    return [
      for (final r in righe.cast<Map<String, dynamic>>())
        (
          id: r['utente_id'] as String,
          nome: r['nome'] as String? ?? '',
          dal: DateTime.parse(r['dal'] as String),
        ),
    ];
  }

  /// Segnala [oggettoId] — un profilo, un messaggio — di tipo [tipo]. L'[id]
  /// nasce qui: rimandata dopo una risposta persa, non arriva due volte. Con
  /// [blocca] blocca anche chi è segnalato. [misurazione] è la scelta della
  /// persona, che sta sul telefono: l'evento lo scrive il server.
  Future<void> segnala({
    required String id,
    required TipoSegnalato tipo,
    required String oggettoId,
    required MotivoSegnalazione motivo,
    required bool blocca,
    required bool misurazione,
    String? nota,
  }) => _alServer(
    () => _server.rpc<dynamic>(
      'segnala',
      params: {
        'p_id': id,
        'p_tipo': tipo.name,
        'p_oggetto': oggettoId,
        'p_motivo': motivo.name,
        'p_nota': nota?.trim().isEmpty ?? true ? null : nota!.trim(),
        'p_blocca': blocca,
        'p_misurazione': misurazione,
      },
    ),
    messaggi: const {
      CodiciServer.nonTrovato: 'Questo profilo non c\'è più su Trolley.',
      CodiciServer.tettoMappe:
          'Hai mandato molte segnalazioni oggi. Per un\'urgenza scrivi a chi '
          'modera.',
    },
  );

  /// Le proprie segnalazioni, dalla più recente, con il loro stato.
  Future<List<Segnalazione>> leMieSegnalazioni() async {
    final righe = await _alServer(
      () => _server.rpc<List<dynamic>>('le_mie_segnalazioni'),
    );
    return [
      for (final r in righe.cast<Map<String, dynamic>>())
        Segnalazione.daServer(r),
    ];
  }

  // ─── Il profilo pubblico e la ricerca (5.3) ──────────────────────────────

  static const _nonSiVede = {
    CodiciServer.nonTrovato: 'Questo profilo non è più nella parte pubblica.',
    CodiciServer.nonPermesso:
        'Per vedere gli altri serve il tuo profilo pubblico acceso.',
  };

  /// Il proprio profilo com'è per gli altri, con tutti i viaggi che ci
  /// possono stare e la scelta per ciascuno (tela, 75 e 109).
  Future<ProfiloPubblico?> ilMioProfilo() async {
    final riga = await _alServer(
      () => _server.rpc<Map<String, dynamic>?>('il_mio_profilo_pubblico'),
    );
    return riga == null ? null : ProfiloPubblico.daServer(riga);
  }

  /// Il profilo di [utenteId], se si può vedere (tela, 73). Se non si può —
  /// spento, sospeso, bloccato — il server dice solo che non c'è.
  Future<ProfiloPubblico> profiloDi(String utenteId) async =>
      ProfiloPubblico.daServer(
        await _alServer(
          () => _server.rpc<Map<String, dynamic>>(
            'profilo_pubblico',
            params: {'p_utente': utenteId},
          ),
          messaggi: _nonSiVede,
        ),
      );

  /// Chi risponde a [ricerca], al più trenta (tela, 74). Senza meta né gusti
  /// non si chiede niente.
  Future<List<ProfiloPubblico>> cerca(Ricerca ricerca) async {
    if (ricerca.vuota) return const [];
    final righe = await _alServer(
      () => _server.rpc<List<dynamic>>(
        'cerca_viaggiatori',
        params: {
          'p_paese': ricerca.paese,
          'p_citta': ricerca.citta,
          'p_gusti': [for (final g in ricerca.gusti) codiceGusto(g)],
        },
      ),
      messaggi: {
        ..._nonSiVede,
        CodiciServer.tettoMappe: 'Per oggi hai cercato molto: riprova domani.',
      },
    );
    return [
      for (final r in righe.cast<Map<String, dynamic>>())
        ProfiloPubblico.daServer(r),
    ];
  }

  /// Sceglie che cosa piace in viaggio; restituisce i gusti come li ha
  /// salvati il server.
  Future<List<Interesse>> scegliGusti(Set<Interesse> scelti) async => gustiDa(
    await _alServer(
      () => _server.rpc<List<dynamic>>(
        'scegli_gusti',
        params: {
          'p_gusti': [for (final g in scelti) codiceGusto(g)],
        },
      ),
    ),
  );

  /// Mette o toglie un viaggio dal proprio profilo pubblico (tela, 109).
  Future<void> mostraSulProfilo(String viaggioId, {required bool mostra}) =>
      _alServer(
        () => _server.rpc<dynamic>(
          'mostra_sul_profilo',
          params: {'p_viaggio': viaggioId, 'p_mostra': mostra},
        ),
        messaggi: const {
          CodiciServer.nonTrovato: 'Non sei più in questo viaggio.',
        },
      );
}
