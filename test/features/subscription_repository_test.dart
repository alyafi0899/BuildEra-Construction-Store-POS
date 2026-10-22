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
    Map<String, dynamic>? body,
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
        ..write(jsonEncode(body ?? {'error': 'server error'}));
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
    await startServer(status: 409, body: {'error': 'bound_other_user', 'code': 'bound_other_user'});

    final error = await invokeAndCapture();

    expect(error.statusCode, 409);
    expect(error.code, 'bound_other_user');
    expect(error.isPermanent, isTrue);
    expect(error.message, contains('Pembelian ini terikat ke akun toko lain'));
    expect(error.message, contains('dikembalikan otomatis oleh Google dalam 3 hari'));
  });

  test('maps 400 FunctionException to verification message', () async {
    await startServer(status: 400, body: {'error': 'bad_request', 'code': 'bad_request'});

    final error = await invokeAndCapture();

    expect(error.statusCode, 400);
    expect(error.code, 'bad_request');
    expect(error.isPermanent, isTrue);
    expect(error.message, contains('Pembelian tidak dapat diverifikasi'));
    expect(error.message, contains('dikembalikan otomatis oleh Google dalam 3 hari'));
  });

  test('maps 503 FunctionException to temporary service message', () async {
    await startServer(status: 503, body: {'error': 'google_unavailable', 'code': 'google_unavailable'});

    final error = await invokeAndCapture();

    expect(error.statusCode, 503);
    expect(error.code, 'google_unavailable');
    expect(error.isPermanent, isFalse);
    expect(
      error.message,
      contains('Layanan verifikasi Google Play sedang tidak tersedia'),
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
      expect(error.code, 'google_unavailable');
      expect(error.isPermanent, isFalse);
      expect(
        error.message,
        contains('Layanan verifikasi Google Play sedang tidak tersedia'),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(seconds: 25)),
  );
}
