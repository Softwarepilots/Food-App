import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../constants/api_constants.dart';
import '../../firebase_options.dart';

/// Must be a top-level function (not a method) — the platform invokes it in
/// a separate isolate when a push arrives while the app is backgrounded/killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

/// FCM only has real config for Android/iOS in this project (see
/// firebase_options.dart) — Chrome is how every app in this repo gets
/// day-to-day dev testing, so this guards against calling into an
/// unconfigured platform and crashing app startup.
bool get _pushSupportedOnThisPlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Called once from `main()`, before the widget tree exists — no Dio/backend
/// dependency, just Firebase's own SDK setup.
Future<void> initializeFirebaseApp() async {
  if (!_pushSupportedOnThisPlatform) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Dev machine without valid Firebase config for this platform — the
    // rest of the app must keep working without push.
  }
}

class PushNotificationService {
  final Dio _dio;

  PushNotificationService(this._dio);

  /// Call after login: asks for notification permission (no-op if already
  /// granted/denied) and registers this device's token with the backend.
  Future<void> registerDevice() async {
    if (!_pushSupportedOnThisPlatform) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendTokenToBackend(token);

      FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);
    } catch (_) {
      // Best-effort — a customer without working push shouldn't be blocked from using the app.
    }
  }

  /// Call on logout so this device stops receiving pushes meant for the
  /// account that just signed out.
  Future<void> unregisterDevice() async {
    if (!_pushSupportedOnThisPlatform) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _dio.post(ApiConstants.deviceUnregister, data: {'token': token});
    } catch (_) {
      // Logout should never fail because push cleanup failed.
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _dio.post(ApiConstants.deviceRegister, data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Retried on the next app launch/token refresh — not worth surfacing to the user.
    }
  }
}
