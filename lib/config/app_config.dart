class AppConfig {
  static const String weatherApiBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String weatherApiKey = String.fromEnvironment(
    'OPEN_WEATHER_API_KEY',
    defaultValue: 'dc6ded16a557e8e60aee592de123e40c',
  );

  static const String vietnamMovieApiBaseUrl = String.fromEnvironment(
    'MOVIE_API_BASE_URL',
    defaultValue: 'https://ophim1.com',
  );
  static const String vietnamMovieApiToken = String.fromEnvironment(
    'MOVIE_API_TOKEN',
  );

  static const String momoMerchantCode = String.fromEnvironment(
    'MOMO_MERCHANT_CODE',
  );
  static const String momoPartnerCode = String.fromEnvironment(
    'MOMO_PARTNER_CODE',
  );
  static const String momoAccessKey = String.fromEnvironment('MOMO_ACCESS_KEY');
  static const String momoSecretKey = String.fromEnvironment('MOMO_SECRET_KEY');
  static const String momoAppScheme = String.fromEnvironment(
    'MOMO_APP_SCHEME',
    defaultValue: 'cinememo',
  );
  static const String momoCallbackHost = String.fromEnvironment(
    'MOMO_CALLBACK_HOST',
    defaultValue: 'payment-callback',
  );
  static const String momoIpnUrl = String.fromEnvironment(
    'MOMO_IPN_URL',
    defaultValue: 'https://example.com/momo-ipn',
  );
  static const bool momoSandboxMode = bool.fromEnvironment(
    'MOMO_SANDBOX_MODE',
    defaultValue: true,
  );
  static const String momoPaymentMode = String.fromEnvironment(
    'MOMO_PAYMENT_MODE',
    defaultValue: 'personal_qr',
  );
  static const String momoPersonalQrPayload = String.fromEnvironment(
    'MOMO_PERSONAL_QR_PAYLOAD',
  );
  static const String momoPersonalName = String.fromEnvironment(
    'MOMO_PERSONAL_NAME',
    defaultValue: 'Chu tai khoan MoMo',
  );
  static const String momoPersonalPhone = String.fromEnvironment(
    'MOMO_PERSONAL_PHONE',
    defaultValue: 'Chua cau hinh',
  );

  static const String ticketEmailSmtpHost = String.fromEnvironment(
    'TICKET_EMAIL_SMTP_HOST',
  );
  static const int ticketEmailSmtpPort = int.fromEnvironment(
    'TICKET_EMAIL_SMTP_PORT',
    defaultValue: 587,
  );
  static const String ticketEmailSmtpUsername = String.fromEnvironment(
    'TICKET_EMAIL_SMTP_USERNAME',
  );
  static const String ticketEmailSmtpPassword = String.fromEnvironment(
    'TICKET_EMAIL_SMTP_PASSWORD',
  );
  static const bool ticketEmailSmtpUseSsl = bool.fromEnvironment(
    'TICKET_EMAIL_SMTP_SSL',
    defaultValue: true,
  );
  static const String ticketEmailSenderName = String.fromEnvironment(
    'TICKET_EMAIL_SENDER_NAME',
    defaultValue: 'CineMemo',
  );
  static const String ticketEmailSenderEmail = String.fromEnvironment(
    'TICKET_EMAIL_SENDER_EMAIL',
  );
  static const String ticketEmailFunctionUrl = String.fromEnvironment(
    'TICKET_EMAIL_FUNCTION_URL',
  );

  static bool get hasTicketEmailFunction =>
      ticketEmailFunctionUrl.trim().isNotEmpty;

  static bool get hasWeatherKey => weatherApiKey.isNotEmpty;

  static bool get hasMovieApi =>
      vietnamMovieApiBaseUrl.isNotEmpty &&
      vietnamMovieApiBaseUrl.startsWith('http');

  static bool get hasMomoPersonalQrPayload =>
      momoPersonalQrPayload.trim().isNotEmpty;

  static bool _isPlaceholderCredential(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized.startsWith('your_') ||
        normalized == 'your_partner_code' ||
        normalized == 'your_access_key' ||
        normalized == 'your_secret_key';
  }

  static String get momoGatewayPartnerCode {
    final partnerCode = momoPartnerCode.trim();
    if (partnerCode.isNotEmpty) {
      return partnerCode;
    }
    return momoMerchantCode.trim();
  }

  static bool get hasMomoGatewayConfig =>
      !_isPlaceholderCredential(momoGatewayPartnerCode) &&
      !_isPlaceholderCredential(momoAccessKey) &&
      !_isPlaceholderCredential(momoSecretKey);

  static bool get useMomoGatewayMode =>
      momoPaymentMode.trim().toLowerCase() == 'gateway';

  static bool get useMomoPersonalQrMode => !useMomoGatewayMode;

  // Trả về true nếu đã cấu hình Cloud Function gửi email hoặc cấu hình đầy đủ SMTP
  static bool get hasTicketEmailConfig {
    final smtpConfigured =
        ticketEmailSmtpHost.trim().isNotEmpty &&
        ticketEmailSmtpUsername.trim().isNotEmpty &&
        ticketEmailSmtpPassword.trim().isNotEmpty;

    return hasTicketEmailFunction || smtpConfigured;
  }
}
