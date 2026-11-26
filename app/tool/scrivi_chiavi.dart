// Scrive le chiavi degli SDK di Google per iOS e Android dove le leggono le
// due app native, da `chiavi.json` (ADR-014). Tutti e tre i file sono
// ignorati da git: il repository è pubblico.
//
//   dart run tool/scrivi_chiavi.dart
//
// - `ios/Flutter/Chiavi.xcconfig`: GOOGLE_MAPS_CHIAVE_IOS, che Info.plist
//   passa all'app come `GMSApiKey`;
// - `android/local.properties`: google.maps.chiave, che il manifesto passa
//   come `com.google.android.geo.API_KEY`.
//
// Le chiavi delle API web (Places, Routes) non passano di qui: stanno nei
// segreti delle funzioni di Supabase.
import 'dart:convert';
import 'dart:io';

void main() {
  final chiavi = jsonDecode(
    File('chiavi.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final ios = chiavi['GOOGLE_MAPS_IOS'] as String?;
  final android = chiavi['GOOGLE_MAPS_ANDROID'] as String?;
  if (ios == null || android == null) {
    stderr.writeln(
      'In chiavi.json mancano GOOGLE_MAPS_IOS o GOOGLE_MAPS_ANDROID.',
    );
    exit(1);
  }
  File('ios/Flutter/Chiavi.xcconfig').writeAsStringSync(
    '// Scritto da tool/scrivi_chiavi.dart: non si committa.\n'
    'GOOGLE_MAPS_CHIAVE_IOS = $ios\n',
  );
  final proprieta = File('android/local.properties');
  final righe = proprieta.existsSync()
      ? proprieta
            .readAsLinesSync()
            .where((r) => !r.startsWith('google.maps.chiave='))
            .toList()
      : <String>[];
  righe.add('google.maps.chiave=$android');
  proprieta.writeAsStringSync('${righe.join('\n')}\n');
  stdout.writeln('Chiavi scritte per iOS e Android.');
}
