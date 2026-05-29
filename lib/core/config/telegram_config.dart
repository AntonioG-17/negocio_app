// Ver docs/telegram-setup.md para configurar
class TelegramConfig {
  static const String botToken = 'TU_BOT_TOKEN'; // Ej: 7123456789:AAF...

  static bool get isConfigured => botToken != 'TU_BOT_TOKEN';
}
