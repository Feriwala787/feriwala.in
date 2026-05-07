import '../services/api_service.dart';

String mapApiError(Object error) {
  if (error is ApiException) {
    // Always show the actual server message first — it's specific and useful
    if (error.message.isNotEmpty) return error.message;
    switch (error.statusCode) {
      case 401:
        return 'Please login again to continue.';
      case 403:
        return 'You do not have permission for this action.';
      case 404:
        return 'Requested resource was not found.';
      case 409:
        return 'This action was already processed.';
      case 500:
      case 502:
      case 503:
        return 'Server is busy right now. Please try again.';
    }
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}
