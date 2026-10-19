import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../models/subscription_history.dart';

class PlayVerifyException implements Exception {
  final int? statusCode;
  final String message;

  const PlayVerifyException({this.statusCode, required this.message});

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
        throw PlayVerifyException(
          statusCode: 504,
          message: 'Layanan verifikasi Google Play sedang tidak tersedia. Silakan coba lagi.',
        );
      }
      rethrow;
    }
  }

  PlayVerifyException _mapVerifyError(int status, [dynamic details]) {
    if (status == 403 || status == 409) {
      return PlayVerifyException(
        statusCode: status,
        message: 'Pembelian ini terikat ke akun toko lain.',
      );
    }
    if (status == 400) {
      return PlayVerifyException(
        statusCode: status,
        message: 'Pembelian tidak dapat diverifikasi. Hubungi developer.',
      );
    }
    if (status >= 500) {
      return PlayVerifyException(
        statusCode: status,
        message:
            'Layanan verifikasi Google Play sedang tidak tersedia. Silakan coba lagi.',
      );
    }

    final errorMessage = details is Map ? details['error'] : null;
    return PlayVerifyException(
      statusCode: status,
      message: errorMessage is String
          ? errorMessage
          : 'Gagal memverifikasi langganan Google Play. Silakan coba lagi.',
    );
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
