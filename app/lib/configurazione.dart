/// Configurazione dell'ambiente.
///
/// I valori predefiniti puntano al progetto di sviluppo `trolley-db`. La chiave è
/// quella pubblicabile: sta nell'app per definizione, e i dati li proteggono le
/// regole di accesso per riga, non il segreto della chiave. Per un altro ambiente:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_CHIAVE=...`
library;

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://nhdgxlynnudwkmxrrokp.supabase.co',
);

const supabaseChiave = String.fromEnvironment(
  'SUPABASE_CHIAVE',
  defaultValue: 'sb_publishable_zdDxpJcG9bv4I76I8zGZiw_ev1IEIEO',
);

/// Dove torna la persona dopo aver confermato l'email. Va tra gli URL di
/// reindirizzamento consentiti in Supabase (Authentication → URL Configuration).
const redirectAccesso = 'trolley://accesso';

const versioneApp = '0.1.0';
