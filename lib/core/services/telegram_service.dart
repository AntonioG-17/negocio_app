import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:negocio_app/core/config/telegram_config.dart';
import 'package:negocio_app/core/utils/formatters.dart';

class TelegramService {
  static Future<void> sendReminder({
    required String chatId,
    required String clientName,
    required String businessName,
    required double debt,
  }) async {
    if (!TelegramConfig.isConfigured) {
      throw Exception('Telegram no configurado. Ver docs/telegram-setup.md');
    }

    final message = '👋 Hola *$clientName*\n\n'
        'Te recordamos que tienes una deuda pendiente de '
        '*${formatCurrency(debt)}* en *$businessName*.\n\n'
        'Por favor comunícate con nosotros para coordinar el pago.\n\n'
        '¡Muchas gracias! 🙏';

    final response = await http.post(
      Uri.parse('https://api.telegram.org/bot${TelegramConfig.botToken}/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chat_id': chatId,
        'text': message,
        'parse_mode': 'Markdown',
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['description'] ?? 'Error enviando mensaje');
    }
  }
}
