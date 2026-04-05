/// Backend API base URL.
/// Simulator: localhost. Fiziksel cihaz: makine IP veya production URL.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String apiPrefix = '/api';
}
