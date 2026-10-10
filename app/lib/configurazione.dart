/// Configurazione dell'ambiente.
///
/// I valori predefiniti puntano al progetto di sviluppo `trolley-db`. La chiave è
/// quella pubblicabile: sta nell'app per definizione, e i dati li proteggono le
/// regole di accesso per riga, non il segreto della chiave. Per un altro ambiente:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_CHIAVE=...`
library;

import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://nhdgxlynnudwkmxrrokp.supabase.co',
);

const supabaseChiave = String.fromEnvironment(
  'SUPABASE_CHIAVE',
  defaultValue: 'sb_publishable_zdDxpJcG9bv4I76I8zGZiw_ev1IEIEO',
);

/// Dove rispondono le mappe (ADR-006, U.2): la funzione `mappe` del server,
/// che tiene la chiave di Geoapify e il tetto. Nell'app la chiave non c'è.
const indirizzoMappe = '$supabaseUrl/functions/v1/mappe';

/// Dove si verifica il numero di telefono (5.1, ADR-011): la funzione
/// `telefono` del server, che tiene le chiavi di Twilio e il tetto.
const indirizzoTelefono = '$supabaseUrl/functions/v1/telefono';

/// Dove torna la persona dopo aver confermato l'email. Va tra gli URL di
/// reindirizzamento consentiti in Supabase (Authentication → URL Configuration).
const redirectAccesso = 'trolley://accesso';

const versioneApp = '0.1.0';

/// Le richieste al server non si ripetono da sole: una che fallisce lo dice
/// subito, e a riprovare è l'app nei momenti giusti — quando torna la rete,
/// quando si riapre, quando si tira giù l'elenco. Una richiesta ferma si
/// interrompe presto: "timeout breve, si torna offline senza insistere"
/// (02-sincronizzazione-e-offline.md).
const opzioniDelServer = PostgrestClientOptions(
  retryEnabled: false,
  requestTimeout: Duration(seconds: 10),
);
