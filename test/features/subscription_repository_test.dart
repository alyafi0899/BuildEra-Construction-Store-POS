import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:buildera/features/subscription/repositories/subscription_repository.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SubscriptionRepository repository;

  Future<void> startServer({
    required int status,
    Duration delay = Duration.zero,
  }) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'server error'}));
      try {
        await request.response.close();
      } on SocketException {
        // The repository timeout closes the request before the delayed response.
      }
    });
    client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = SubscriptionRepository(client);
  }

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  Future<PlayVerifyException> invokeAndCapture() async {
    try {
      await repository.verifyPlayPurchase(
        purchaseToken: 'test-token',
        productId: 'buildera_monthly',
      );
      fail('Expected verification to fail');
    } on PlayVerifyException catch (error) {
      return error;
    }
  }

  test('maps 409 FunctionException to account binding message', () async {
    await startServer(status: 409);

    final error = await invokeAndCapture();

    expect(error.statusCode, 409);
    expect(error.message, 'Pembelian ini terikat ke akun toko lain.');
  });

  test('maps 400 FunctionException to verification message', () async {
    await startServer(status: 400);

    final error = await invokeAndCapture();

    expect(error.statusCode, 400);
    expect(error.message, 'Pembelian tidak dapat diverifikasi. Hubungi developer.');
  });

  test('maps 503 FunctionException to temporary service message', () async {
    await startServer(status: 503);

    final error = await invokeAndCapture();

    expect(error.statusCode, 503);
    expect(
      error.message,
      'Layanan verifikasi Google Play sedang tidak tersedia. Silakan coba lagi.',
    );
  });

  test(
    'maps request timeout to 504',
    () async {
      await startServer(
        status: 200,
        delay: const Duration(seconds: 16),
      );

      final error = await invokeAndCapture();

      expect(error.statusCode, 504);
      expect(
        error.message,
        'Layanan verifikasi Google Play sedang tidak tersedia. Silakan coba lagi.',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(seconds: 25)),
  );
}
