import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../models/subscription_history.dart';

class PlayVerifyException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;
  final String? serverMessage;

  const PlayVerifyException({
    this.statusCode,
    required this.message,
    this.code,
    this.serverMessage,
  });

  bool get isPermanent {
    if (code != null) {
      const permanentCodes = {
        'server_config_missing',
        'server_config_json',
        'google_auth',
        'google_package_mismatch',
        'bad_request',
        'product_mismatch',
        'not_bound',
        'bound_other_user',
      };
      return permanentCodes.contains(code);
    }
    return const {400, 403, 409}.contains(statusCode);
  }

  @override
  String toString() => message;
}

class SubscriptionRepository {
  final SupabaseClient _client;

  SubscriptionRepository(this._client);

  Future<Subscription?> getSubscription(String userId) async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Subscription.fromMap(response);
  }

  Future<List<SubscriptionHistory>> getHistory(String userId) async {
    final response = await _client
        .from('subscription_history')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((m) => SubscriptionHistory.fromMap(m))
        .toList();
  }

  /// Calls the Supabase Edge Function to verify Google Play Purchase
  Future<Map<String, dynamic>> verifyPlayPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-play-purchase',
        body: {
          'purchaseToken': purchaseToken,
          'productId': productId,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status != 200) {
        throw _mapVerifyError(response.status, response.data);
      }

      return response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      throw _mapVerifyError(e.status, e.details);
    } catch (e) {
      if (e is TimeoutException) {
        throw const PlayVerifyException(
          statusCode: 504,
          code: 'google_unavailable',
          message: 'Layanan verifikasi Google Play sedang tidak tersedia. Silakan coba lagi.',
        );
      }
      rethrow;
    }
  }

  PlayVerifyException _mapVerifyError(int status, [dynamic details]) {
    String? code;
    String? serverMsg;

    if (details is Map) {
      if (details['code'] is String) {
        code = details['code'] as String;
      }
      if (details['error'] is String) {
        serverMsg = details['error'] as String;
      }
    }

    final message = buildUserFriendlyMessage(status, code, serverMsg);

    return PlayVerifyException(
      statusCode: status,
      message: message,
      code: code,
      serverMessage: serverMsg,
    );
  }

  static String buildUserFriendlyMessage(int status, String? code, String? serverMsg) {
    final suffix = code != null ? ' (kode: $code)' : '';

    String mainMsg;
    bool isPermanent = false;

    switch (code) {
      case 'server_config_missing':
      case 'server_config_json':
        mainMsg = 'Konfigurasi server pembayaran Google Play bermasalah$suffix. Silakan hubungi developer.';
        isPermanent = true;
        break;
      case 'google_auth':
        mainMsg = 'Izin akses Google Play di server belum sesuai$suffix. Hubungi developer.';
        isPermanent = true;
        break;
      case 'google_package_mismatch':
        mainMsg = 'Aplikasi tidak terdaftar dengan benar di Google Play Console$suffix. Hubungi developer.';
        isPermanent = true;
        break;
      case 'bad_request':
      case 'product_mismatch':
        mainMsg = 'Pembelian tidak dapat diverifikasi karena data produk tidak sesuai$suffix. Hubungi developer.';
        isPermanent = true;
        break;
      case 'not_bound':
      case 'bound_other_user':
        mainMsg = 'Pembelian ini terikat ke akun toko lain$suffix.';
        isPermanent = true;
        break;
      case 'google_unavailable':
        mainMsg = 'Layanan verifikasi Google Play sedang tidak tersedia$suffix. Silakan coba lagi.';
        break;
      case 'db_persist':
        mainMsg = 'Pembayaran sudah diterima Google tetapi belum bisa diaktifkan$suffix. Coba lagi nanti atau hubungi developer.';
        break;
      default:
        if (status == 403 || status == 409) {
          mainMsg = 'Pembelian ini terikat ke akun toko lain$suffix.';
          isPermanent = true;
        } else if (status == 400) {
          mainMsg = 'Pembelian tidak dapat diverifikasi$suffix. Hubungi developer.';
          isPermanent = true;
        } else if (status >= 500) {
          mainMsg = 'Layanan verifikasi Google Play sedang tidak tersedia$suffix. Silakan coba lagi.';
        } else {
          mainMsg = serverMsg ?? 'Gagal memverifikasi langganan Google Play$suffix. Silakan coba lagi.';
        }
    }

    if (isPermanent) {
      return '$mainMsg Jika tidak terverifikasi, pembelian dikembalikan otomatis oleh Google dalam 3 hari.';
    }

    return mainMsg;
  }

  /// Calls the Supabase Edge Function to create a Xendit Invoice
  Future<Map<String, dynamic>> createPaymentInvoice({
    required String userId,
    required PlanType plan,
    required String email,
    String? method,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-payment',
        body: {
          'userId': userId,
          'planType': plan.toString().split('.').last,
          'email': email,
          'method': method,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status != 200) {
        final errorMsg =
            response.data?['error'] ?? 'Gagal membuat invoice pembayaran';
        throw Exception(errorMsg);
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
            'Koneksi server terputus (Timeout). Silakan coba lagi.');
      }
      rethrow;
    }
  }
}
