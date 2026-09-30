# Trolley — app

L'app Flutter. Cosa deve fare sta in [`../docs/prodotto/`](../docs/prodotto/), come è fatta in [`../docs/tecnico/`](../docs/tecnico/); le regole per chi ci lavora in [`../CLAUDE.md`](../CLAUDE.md).

```sh
flutter pub get
flutter test
flutter run                          # punta al progetto Supabase di sviluppo
dart run build_runner build          # dopo aver toccato lib/dati/database.dart
```

Con l'account Apple gratuito l'app si installa sul proprio iPhone da Xcode (`open ios/Runner.xcworkspace`, scegliere il proprio team in *Signing & Capabilities*) e va reinstallata ogni sette giorni.
