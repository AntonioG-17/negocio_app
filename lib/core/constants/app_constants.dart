class AppConstants {
  static const String appName = 'NegocioApp';

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
