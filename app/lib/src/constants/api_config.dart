class ApiConfig {
  // TODO: Update this to your actual API URL
  // For local development, use: 'http://localhost:8000'
  // For production, use your deployed API URL
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';
  
  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}

