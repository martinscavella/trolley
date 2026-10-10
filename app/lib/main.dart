import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'configurazione.dart';
import 'dati/acquisizione.dart';
import 'dati/archivio.dart';
import 'dati/database.dart';
import 'dati/documenti.dart';
import 'dati/file_del_telefono.dart';
import 'dati/mappe.dart';
import 'dati/mappe_del_telefono.dart';
import 'dati/pagine.dart';
import 'dati/parte_pubblica.dart';
import 'dati/posizione.dart';
import 'dati/rete.dart';
import 'dati/telefono.dart';
import 'invito/ingresso_da_invito.dart';
import 'misurazione/misurazione.dart';
import 'servizi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseChiave,
    postgrestOptions: opzioniDelServer,
  );

  final supabase = Supabase.instance.client;
  final db = DatabaseLocale();
  final rete = ReteDelTelefono();
  // I documenti stanno in Application Support: dentro il backup, mai visibile
  // nell'app File (ADR-008).
  final documenti = CartellaDocumenti(
    db,
    telefono: const FileDelTelefonoNativo(),
    cartellaApp: getApplicationSupportDirectory,
    io: () => supabase.auth.currentUser?.id,
  );
  // Un'aggiunta interrotta a metà non lascia file.
  unawaited(documenti.pulisci().catchError((_) {}));

  final archivio = Archivio(db, supabase, rete: rete);

  runApp(
    Servizi(
      db: db,
      supabase: supabase,
      archivio: archivio,
      misurazione: Misurazione(db, supabase, versioneApp: versioneApp),
      ingresso: IngressoDaLink(),
      rete: rete,
      documenti: documenti,
      acquisizione: const AcquisizioneDelTelefono(),
      mappe: MappeGeoapify(
        indirizzo: indirizzoMappe,
        chiavePubblica: supabaseChiave,
        accesso: () => supabase.auth.currentSession?.accessToken,
      ),
      posizione: const PosizioneDelTelefono(),
      mappeDelTelefono: const MappeDiSistema(),
      pagine: const PagineNelBrowser(),
      partePubblica: PartePubblica(
        supabase,
        rete: rete,
        ricorda: archivio.ricordaCommunity,
      ),
      telefono: VerificaSulServer(
        indirizzo: indirizzoTelefono,
        chiavePubblica: supabaseChiave,
        accesso: () => supabase.auth.currentSession?.accessToken,
        rete: rete,
      ),
      child: const TrolleyApp(),
    ),
  );
}
