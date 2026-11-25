import 'dart:async';

import 'package:trolley/aspetto/mappamondo.dart';

/// Vale per tutte le prove: il globo non gira da solo, perché le prove
/// aspettano che tutto si fermi, e un globo che gira da solo non si ferma.
Future<void> testExecutable(FutureOr<void> Function() prove) async {
  Mappamondo.siGiraDaSolo = false;
  await prove();
}
