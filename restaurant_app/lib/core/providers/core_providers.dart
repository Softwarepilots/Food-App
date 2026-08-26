import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';
import 'session_provider.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return createDioClient(
    storageService: storage,
    onSessionExpired: () async {
      ref.read(sessionExpiredProvider.notifier).notify();
    },
  );
});
