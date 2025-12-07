class ApiConfig {
  // Public Railway API URL - Update this with your actual Railway deployment URL
  // Example: 'https://your-api.railway.app' or 'https://archipelago-production.up.railway.app'
  static const String publicApiUrl = 'https://archipelago-production.up.railway.app'; // TODO: Replace with your Railway API URL
  
  static const String apiPrefix = '/api/v1';
  
  static String get baseUrl => publicApiUrl;
  
  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}

