import 'dart:async';
import 'package:flutter/services.dart';

class NotificationBridge {
  static const MethodChannel _methods =
      MethodChannel('gasto_azul/notification_methods');
  static const EventChannel _events =
      EventChannel('gasto_azul/notification_events');

  Stream<Map<String, dynamic>> get notifications =>
      _events.receiveBroadcastStream().map((event) {
        return Map<String, dynamic>.from(event as Map);
      });

  Future<void> openNotificationAccessSettings() async {
    await _methods.invokeMethod<void>('openNotificationAccessSettings');
  }

  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    final result = await _methods.invokeListMethod<dynamic>(
      'getPendingNotifications',
    );
    if (result == null) return const [];
    return result
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
