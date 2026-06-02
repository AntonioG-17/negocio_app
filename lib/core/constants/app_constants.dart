class AppConstants {
  static const String appName = 'NegocioApp';
  // Versión visible al usuario.
  static const String appVersion = 'v1.2.5';
  // Identificador interno de build (NO visible). Se sube cuando solo cambian
  // archivos web/ (p. ej. scanner_bridge.js) para forzar un serviceWorkerVersion
  // nuevo y que el navegador baje el archivo fresco sin cambiar appVersion.
  static const String buildTag = 'b3';

  // CEO — la única cuenta con acceso total. Crear una vez en Firebase Console.
  static const String ceoEmail = 'antonio.geldes1701@gmail.com';

  // Firestore collections
  static const String colBusinesses = 'businesses';
  static const String colProducts = 'products';
  static const String colSales = 'sales';
  static const String colClients = 'clients';
  static const String colPayments = 'fiado_payments';
  static const String colUsers = 'users';

  static const int defaultMinStock = 5;
}
