/// La parte pubblica e la sua sicurezza, sul server (5.1; sicurezza.sql): il
/// proprio profilo pubblico, chi si è bloccato, le proprie segnalazioni.
///
/// Tutto richiede la rete, e niente sta nella copia del telefono: la parte
/// pubblica è fatta di altre persone, e si guarda com'è adesso (11, 12). Chi
/// può fare che cosa lo decide il server; qui si traducono i suoi no.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/parte_pubblica.dart';
import 'errori.dart';
import 'rete.dart';

class PartePubblica {
  PartePubblica(this._supabase, {this.rete});

  final SupabaseClient _supabase;
  final Rete? rete;

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
    return riga == null ? null : StatoPartePubblica.daServer(riga);
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
}
