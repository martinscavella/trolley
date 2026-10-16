/// Le notifiche del telefono (14-notifiche.md), dietro un'interfaccia: le
/// prove la sostituiscono, e il giorno delle notifiche dal server (push)
/// si aggiunge qui senza toccare le schermate.
///
/// Per ora solo quelle che il telefono si programma da solo: niente server,
/// niente rete, e quello che dicono non esce dal telefono.
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../dominio/notifiche.dart';

abstract interface class Notifiche {
  /// Prepara il telefono, senza chiedere niente alla persona.
  Future<void> avvia();

  /// Se il telefono le lascia arrivare.
  Future<bool> accese();

  /// Chiede il permesso: iOS lo chiede una volta sola, e dopo un no risponde
  /// no senza mostrare niente. Restituisce se adesso arrivano.
  Future<bool> chiedi();

  /// Toglie quelle in attesa e programma [notifiche] al loro posto. Quelle
  /// già arrivate restano nel Centro notifiche.
  Future<void> programma(List<Notifica> notifiche);

  /// Dove portano quelle toccate, anche quella che ha aperto l'app.
  Stream<DovePorta> get toccate;

  /// Apre le impostazioni delle notifiche dell'app, dove si riaccendono
  /// dopo un no.
  Future<void> apriImpostazioni();
}

/// Il telefono vero, con flutter_local_notifications.
class NotificheDelTelefono implements Notifiche {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _toccate = StreamController<DovePorta>.broadcast();
  DovePorta? _daAprire;
  Future<void>? _avvio;

  @override
  Future<void> avvia() => _avvio ??= _avvia();

  Future<void> _avvia() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Il permesso si chiede quando serve davvero (14, regola 5), non qui.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => _tocca(r.payload),
    );
    final avvio = await _plugin.getNotificationAppLaunchDetails();
    if (avvio?.didNotificationLaunchApp ?? false) {
      _daAprire = leggiDovePorta(avvio!.notificationResponse?.payload);
    }
  }

  void _tocca(String? payload) {
    final dove = leggiDovePorta(payload);
    if (dove != null) _toccate.add(dove);
  }

  @override
  Stream<DovePorta> get toccate async* {
    await avvia();
    final primo = _daAprire;
    _daAprire = null;
    if (primo != null) yield primo;
    yield* _toccate.stream;
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> accese() async {
    await avvia();
    if (_ios case final ios?) {
      final permessi = await ios.checkPermissions();
      return (permessi?.isEnabled ?? false) ||
          (permessi?.isProvisionalEnabled ?? false);
    }
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> chiedi() async {
    await avvia();
    if (_ios case final ios?) {
      return await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> programma(List<Notifica> notifiche) async {
    await avvia();
    await _plugin.cancelAllPendingNotifications();
    for (final n in notifiche) {
      await _plugin.zonedSchedule(
        id: _numero(n.chiave),
        // L'istante, non l'ora sul quadrante: se il telefono cambia fuso,
        // la prossima programmazione lo rimette all'ora giusta.
        scheduledDate: tz.TZDateTime.from(n.quando.toUtc(), tz.UTC),
        title: n.titolo,
        body: n.testo,
        payload: scriviDovePorta(n.dovePorta),
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            threadIdentifier: n.tipo.codice,
            interruptionLevel: InterruptionLevel.active,
          ),
          android: AndroidNotificationDetails(
            n.tipo.codice,
            _canali[n.tipo]!,
            groupKey: n.tipo.codice,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// I nomi dei canali di Android, come le righe delle impostazioni.
  static const _canali = {
    TipoNotifica.primaDiPartire: 'Prima di partire',
    TipoNotifica.tappeDaSegnare: 'Tappe da segnare',
    TipoNotifica.ideaCheScade: 'Idee che scadono',
    TipoNotifica.unAnnoFa: 'Un anno fa',
  };

  @override
  Future<void> apriImpostazioni() async {
    await _plugin.openAppNotificationSettings();
  }

  /// Un numero stabile per chiave: una notifica nuova non sostituisce nel
  /// Centro notifiche un'altra già arrivata.
  static int _numero(String chiave) {
    var h = 0x811c9dc5;
    for (final c in chiave.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }
}
