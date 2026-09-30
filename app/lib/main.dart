import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'configurazione.dart';
import 'dati/archivio.dart';
import 'dati/database.dart';
import 'invito/ingresso_da_invito.dart';
import 'misurazione/misurazione.dart';
import 'servizi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseChiave);

  final supabase = Supabase.instance.client;
  final db = DatabaseLocale();

  runApp(
    Servizi(
      db: db,
      supabase: supabase,
      archivio: Archivio(db, supabase),
      misurazione: Misurazione(db, supabase, versioneApp: versioneApp),
      ingresso: IngressoDaLink(),
      child: const TrolleyApp(),
    ),
  );
}
