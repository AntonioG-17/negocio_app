import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:negocio_app/core/config/twilio_config.dart';
import 'package:negocio_app/core/utils/formatters.dart';

class SmsService {
  static Future<void> sendReminder({
    required String phone,
    required String clientName,
    required String businessName,
    required double debt,
  }) async {
    if (!TwilioConfig.isConfigured) {
      throw Exception(
        'Twilio no configurado. Ver docs/twilio-setup.md',
      );
    }

    final cleanPhone = _normalizePhone(phone);
    final message =
        'Hola $clientName, te recordamos que tienes una deuda pendiente '
        'de ${formatCurrency(debt)} en $businessName. '
        'Por favor comunicate con nosotros para coordinar el pago. Gracias!';

    final credentials = base64Encode(
      utf8.encode('${TwilioConfig.accountSid}:${TwilioConfig.authToken}'),
    );

    final response = await http.post(
      Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/${TwilioConfig.accountSid}/Messages.json',
      ),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'From': TwilioConfig.fromPhone,
        'To': cleanPhone,
        'Body': message,
      },
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Error enviando SMS');
    }
  }

  // Normaliza telefono: agrega +56 si no tiene codigo de pais
  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('56')) return '+$digits';
    return '+56$digits'; // asume Chile por defecto
  }
}
