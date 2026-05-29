// Credenciales de Twilio — ver docs/twilio-setup.md para configurar
// IMPORTANTE: nunca subas credenciales reales a git en produccion
class TwilioConfig {
  static const String accountSid = 'TU_ACCOUNT_SID';
  static const String authToken = 'TU_AUTH_TOKEN';
  static const String fromPhone = '+1234567890'; // Tu numero Twilio con codigo de pais

  static bool get isConfigured =>
      accountSid != 'TU_ACCOUNT_SID' && authToken != 'TU_AUTH_TOKEN';
}
