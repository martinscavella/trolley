import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dati/archivio.dart';
import 'dati/database.dart';
import 'dati/rete.dart';
import 'invito/ingresso_da_invito.dart';
import 'misurazione/misurazione.dart';

/// Ciò che le schermate usano, messo a disposizione dell'albero dei widget.
class Servizi extends InheritedWidget {
  const Servizi({
    super.key,
    required this.db,
    required this.supabase,
    required this.archivio,
    required this.misurazione,
    required this.ingresso,
    required this.rete,
    required super.child,
  });

  final DatabaseLocale db;
  final SupabaseClient supabase;
  final Archivio archivio;
  final Misurazione misurazione;
  final IngressoDaInvito ingresso;
  final Rete rete;

  static Servizi of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Servizi>()!;

  @override
  bool updateShouldNotify(Servizi oldWidget) => false;
}
