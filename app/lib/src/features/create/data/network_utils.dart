import 'package:archipelago/src/constants/api_config.dart';

class NetworkUtils {
  /// Formats network error messages with helpful connection troubleshooting.
  static String formatNetworkError(dynamic error) {
    String errorMessage = 'Network error: ${error.toString()}';
    
    final errorStr = error.toString();
    if (errorStr.contains('Connection refused') || 
        errorStr.contains('Failed host lookup') ||
        errorStr.contains('SocketException')) {
      final baseUrl = ApiConfig.baseUrl;
      errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
          'Please ensure:\n'
          '• The API server is running\n'
          '• You are using the correct API URL for your platform';
    }
    
    return errorMessage;
  }

  /// Parses error response from API and returns a formatted error message.
  static String parseErrorResponse(dynamic error) {
    if (error is Map<String, dynamic>) {
      if (error.containsKey('detail')) {
        final detail = error['detail'];
        if (detail is String) {
          return detail;
        } else if (detail is List) {
          // If detail is a list of validation errors, format them
          final errors = detail.map((e) {
            if (e is Map) {
              final loc = e['loc'] as List?;
              final msg = e['msg'] as String?;
              if (loc != null && msg != null) {
                return '${loc.join('.')}: $msg';
              }
            }
            return e.toString();
          }).join(', ');
          return 'Validation error: $errors';
        } else {
          return detail.toString();
        }
      }
    }
    return 'Failed to process request';
  }
}

