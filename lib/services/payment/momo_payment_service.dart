import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:momo_payment_flutter/momo_payment_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';

enum MomoPaymentStatus { success, failed, cancelled, pending }

class MomoPaymentRequest {
  const MomoPaymentRequest({
    required this.orderId,
    required this.amount,
    required this.description,
  });

  final String orderId;
  final double amount;
  final String description;
}

class MomoPaymentResult {
  const MomoPaymentResult({
    required this.status,
    required this.orderId,
    this.transactionId,
    this.message,
  });

  final MomoPaymentStatus status;
  final String orderId;
  final String? transactionId;
  final String? message;
}

class MomoPaymentService {
  MomoPaymentService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  bool get isConfigured => AppConfig.hasMomoGatewayConfig;

  static const Duration _callbackTimeout = Duration(minutes: 5);

  Future<MomoPaymentResult> pay(MomoPaymentRequest request) async {
    if (kIsWeb) {
      return MomoPaymentResult(
        status: MomoPaymentStatus.pending,
        orderId: request.orderId,
        message: 'Thanh toán MoMo chưa hỗ trợ trên Web.',
      );
    }

    if (!isConfigured) {
      return MomoPaymentResult(
        status: MomoPaymentStatus.failed,
        orderId: request.orderId,
        message:
            'Thiếu cấu hình MoMo. Cần MOMO_PARTNER_CODE (hoặc MOMO_MERCHANT_CODE), MOMO_ACCESS_KEY, MOMO_SECRET_KEY.',
      );
    }

    final momoClient = MomoPayment(
      partnerCode: AppConfig.momoGatewayPartnerCode,
      accessKey: AppConfig.momoAccessKey,
      secretKey: AppConfig.momoSecretKey,
      isTestMode: AppConfig.momoSandboxMode,
      isDebug: kDebugMode,
    );

    final requestId = const Uuid().v4();
    final callbackUri = buildCallbackUri(request.orderId);

    try {
      final createResponse = await momoClient.createPayment(
        MomoPaymentInfo(
          orderId: request.orderId,
          orderInfo: request.description,
          amount: request.amount.round(),
          redirectUrl: callbackUri.toString(),
          ipnUrl: AppConfig.momoIpnUrl,
          requestId: requestId,
          requestType: 'payWithMethod',
          lang: 'vi',
        ),
      );

      if ((createResponse.resultCode ?? -1) != 0) {
        return MomoPaymentResult(
          status: _mapStatus(
            createResponse.resultCode,
            fallbackMessage: createResponse.message,
          ),
          orderId: request.orderId,
          message:
              createResponse.message ??
              'Khởi tạo thanh toán MoMo thất bại (${createResponse.resultCode}).',
        );
      }

      final paymentUrls = <String>{
        if (createResponse.qrCodeUrl != null) createResponse.qrCodeUrl!.trim(),
        if (createResponse.payUrl != null) createResponse.payUrl!.trim(),
        if (createResponse.deeplink != null) createResponse.deeplink!.trim(),
        if (createResponse.deeplinkMiniApp != null)
          createResponse.deeplinkMiniApp!.trim(),
      }.where((url) => url.isNotEmpty).toList();

      if (paymentUrls.isEmpty) {
        return MomoPaymentResult(
          status: MomoPaymentStatus.failed,
          orderId: request.orderId,
          message: 'Không nhận được đường dẫn thanh toán MoMo.',
        );
      }

      Uri? callbackUriResult;
      Object? openPaymentError;

      for (final paymentUrl in paymentUrls) {
        try {
          await momoClient.openPaymentPage(paymentUrl);
          callbackUriResult = await _waitForCallback(orderId: request.orderId);
          openPaymentError = null;
          break;
        } catch (error) {
          openPaymentError = error;
        }
      }

      if (openPaymentError != null) {
        return MomoPaymentResult(
          status: MomoPaymentStatus.failed,
          orderId: request.orderId,
          message:
              'Không thể mở trang thanh toán MoMo. Vui lòng cài app MoMo hoặc thử lại trên thiết bị thật.',
        );
      }

      try {
        final statusResponse = await momoClient.checkStatus(
          orderId: request.orderId,
          requestId: requestId,
        );

        final status = _mapStatus(
          statusResponse.resultCode,
          fallbackMessage: statusResponse.message,
        );

        return MomoPaymentResult(
          status: status,
          orderId: request.orderId,
          transactionId: _extractTransactionId(
            callbackUriResult,
            statusResponse.requestId,
          ),
          message:
              statusResponse.message ??
              callbackUriResult?.queryParameters['message'],
        );
      } catch (_) {
        final resultCodeRaw =
            callbackUriResult?.queryParameters['resultCode'] ??
            callbackUriResult?.queryParameters['errorCode'] ??
            '';
        final resultCode = int.tryParse(resultCodeRaw);

        return MomoPaymentResult(
          status: _mapStatus(
            resultCode,
            fallbackMessage: callbackUriResult?.queryParameters['message'],
          ),
          orderId: request.orderId,
          transactionId: _extractTransactionId(callbackUriResult, null),
          message:
              callbackUriResult?.queryParameters['message'] ??
              'Không thể kiểm tra trạng thái giao dịch MoMo.',
        );
      }
    } catch (error) {
      return MomoPaymentResult(
        status: MomoPaymentStatus.failed,
        orderId: request.orderId,
        message:
            'Không thể khởi tạo thanh toán MoMo sandbox. ${error.toString()}',
      );
    }
  }

  Uri buildCallbackUri(String orderId) {
    return Uri(
      scheme: AppConfig.momoAppScheme,
      host: AppConfig.momoCallbackHost,
      queryParameters: {'orderId': orderId},
    );
  }

  Future<Uri?> _waitForCallback({required String orderId}) async {
    final completer = Completer<Uri?>();
    StreamSubscription<Uri>? subscription;

    Future<void> completeIfMatched(Uri? uri) async {
      if (uri == null || completer.isCompleted) {
        return;
      }
      if (!_isCallbackUri(uri, orderId)) {
        return;
      }
      completer.complete(uri);
      await subscription?.cancel();
    }

    try {
      final initial = await _appLinks.getInitialLink();
      await completeIfMatched(initial);
    } catch (_) {
      // Ignore malformed initial deep links.
    }

    subscription = _appLinks.uriLinkStream.listen(
      (uri) => completeIfMatched(uri),
      onError: (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      cancelOnError: true,
    );

    try {
      return await completer.future.timeout(
        _callbackTimeout,
        onTimeout: () {
          return null;
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  bool _isCallbackUri(Uri uri, String orderId) {
    final sameScheme =
        uri.scheme.toLowerCase() == AppConfig.momoAppScheme.toLowerCase();
    if (!sameScheme) {
      return false;
    }

    final expectedHost = AppConfig.momoCallbackHost.trim().toLowerCase();
    if (expectedHost.isNotEmpty) {
      final host = uri.host.trim().toLowerCase();
      final path = uri.path.trim().toLowerCase();
      final hostMatches = host == expectedHost;
      final pathMatches =
          path == expectedHost ||
          path == '/$expectedHost' ||
          path.endsWith('/$expectedHost');
      final hostIsOmitted =
          host.isEmpty && (path.isEmpty || path == '/' || pathMatches);

      if (!hostMatches && !pathMatches && !hostIsOmitted) {
        return false;
      }
    }

    final callbackOrderId = uri.queryParameters['orderId'];
    if (callbackOrderId == null || callbackOrderId.trim().isEmpty) {
      return true;
    }

    return callbackOrderId.trim() == orderId;
  }

  MomoPaymentStatus _mapStatus(int? resultCode, {String? fallbackMessage}) {
    if (resultCode == 0) {
      return MomoPaymentStatus.success;
    }

    if (resultCode == 1006) {
      return MomoPaymentStatus.cancelled;
    }

    final message = fallbackMessage?.toLowerCase() ?? '';
    if (message.contains('cancel') || message.contains('huy')) {
      return MomoPaymentStatus.cancelled;
    }

    if (resultCode == null) {
      return MomoPaymentStatus.pending;
    }

    return MomoPaymentStatus.failed;
  }

  String? _extractTransactionId(Uri? callbackUri, String? fallback) {
    final fromCallback =
        callbackUri?.queryParameters['transId'] ??
        callbackUri?.queryParameters['requestId'];
    if (fromCallback != null && fromCallback.trim().isNotEmpty) {
      return fromCallback.trim();
    }
    return fallback;
  }
}
