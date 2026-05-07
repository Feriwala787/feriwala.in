import 'package:amazon_location_flutter/amazon_location_flutter.dart';
import '../config/app_config.dart';

class LocationService {
  static AmazonLocationClient? _client;

  static AmazonLocationClient? get client {
    if (_client != null) return _client;
    if (AppConfig.awsLocationApiKey.isEmpty) return null;
    _client = AmazonLocationClient(
      apiKey: AppConfig.awsLocationApiKey,
      region: AppConfig.awsRegion,
    );
    return _client;
  }

  /// Returns autocomplete suggestions for [query].
  static Future<List<AutocompleteResult>> autocomplete(
    String query, {
    LatLng? biasPosition,
  }) async {
    final c = client;
    if (c == null || query.trim().length < 3) return [];
    try {
      return await c.autocomplete(query, maxResults: 5, biasPosition: biasPosition);
    } catch (_) {
      return [];
    }
  }

  /// Geocodes a [queryText] (e.g. a place label) and returns structured result.
  static Future<GeocodeResult?> geocode(String queryText) async {
    final c = client;
    if (c == null) return null;
    try {
      return await c.geocode(queryText);
    } catch (_) {
      return null;
    }
  }
}
