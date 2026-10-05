import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dati/acquisizione.dart';
import 'dati/archivio.dart';
import 'dati/database.dart';
import 'dati/documenti.dart';
import 'dati/mappe.dart';
import 'dati/mappe_del_telefono.dart';
import 'dati/posizione.dart';
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
    required this.documenti,
    required this.acquisizione,
    required this.mappe,
    required this.posizione,
    required this.mappeDelTelefono,
    required super.child,
  });

  final DatabaseLocale db;
  final SupabaseClient supabase;
  final Archivio archivio;
  final Misurazione misurazione;
  final IngressoDaInvito ingresso;
  final Rete rete;

  /// I documenti, che stanno solo sul telefono (dati/documenti.dart).
  final CartellaDocumenti documenti;

  /// Da dove arriva un documento nuovo: scansione, foto, file.
  final Acquisizione acquisizione;

  /// Il fornitore di mappe, percorsi e ricerca dei luoghi (ADR-006).
  final Mappe mappe;

  /// Dove si trova il telefono: solo per la mappa, mai fuori (08, regola 7).
  final Posizione posizione;

  /// Le Mappe del telefono, a cui si consegna una tappa.
  final MappeDelTelefono mappeDelTelefono;

  static Servizi of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Servizi>()!;

  @override
  bool updateShouldNotify(Servizi oldWidget) => false;
}
