class AppConfig {
  static const String appName = 'Feriwala';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.feriwala.in/api',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://api.feriwala.in',
  );
  static const String awsRegion = 'ap-south-1';
  static const String awsAccessKeyId = String.fromEnvironment('AWS_ACCESS_KEY_ID', defaultValue: '');
  static const String awsSecretAccessKey = String.fromEnvironment('AWS_SECRET_ACCESS_KEY', defaultValue: '');
  static const String awsMapName = 'feriwala-map';
  static const String awsPlaceIndexName = 'feriwala-places';
}
