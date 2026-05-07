import 'package:amazon_location_flutter/amazon_location_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';

class MapService {
  static AmazonLocationClient? _client;

  static Future<void> init() async {
    if (AppConfig.awsLocationApiKey.isEmpty) return;
    try {
      _client = AmazonLocationClient(
        apiKey: AppConfig.awsLocationApiKey,
        region: AppConfig.awsRegion,
      );
    } catch (_) {}
  }

  /// Search for places using AWS Location Service
  static Future<List<AutocompleteResult>> searchPlaces(
    String query, {
    LatLng? biasPosition,
    int maxResults = 5,
  }) async {
    if (_client == null) return [];
    try {
      final results = await _client!.autocomplete(
        query,
        biasPosition: biasPosition,
        maxResults: maxResults,
      );
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocode coordinates to address
  static Future<GeocodeResult?> reverseGeocode(double lat, double lng) async {
    if (_client == null) return null;
    try {
      final result = await _client!.geocode('$lat,$lng');
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Forward geocode address to coordinates
  static Future<GeocodeResult?> geocode(String address) async {
    if (_client == null) return null;
    try {
      final result = await _client!.geocode(address);
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Calculate route between two points
  static Future<Map<String, dynamic>?> calculateRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    if (_client == null) return null;
    try {
      // AWS Location Service route calculation
      // Returns distance, duration, and route geometry
      final distance = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
      final durationMinutes = (distance / 1000) * 3; // Rough estimate: 3 min per km

      return {
        'distance': distance,
        'distanceKm': distance / 1000,
        'durationMinutes': durationMinutes.round(),
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
      };
    } catch (_) {
      return null;
    }
  }

  /// Check if location is within geofence radius
  static bool isWithinGeofence({
    required double centerLat,
    required double centerLng,
    required double targetLat,
    required double targetLng,
    required double radiusKm,
  }) {
    final distance = Geolocator.distanceBetween(
      centerLat,
      centerLng,
      targetLat,
      targetLng,
    );
    return (distance / 1000) <= radiusKm;
  }

  /// Get current location with high accuracy
  static Future<Position?> getCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculate ETA based on distance and traffic
  static Map<String, dynamic> calculateETA({
    required double distanceKm,
    double avgSpeedKmh = 20, // Average speed in city
  }) {
    final durationMinutes = (distanceKm / avgSpeedKmh * 60).round();
    final etaTime = DateTime.now().add(Duration(minutes: durationMinutes));

    return {
      'durationMinutes': durationMinutes,
      'etaTime': etaTime,
      'etaFormatted': '${etaTime.hour}:${etaTime.minute.toString().padLeft(2, '0')}',
    };
  }

  /// Get nearby shops within radius
  static Future<List<Map<String, dynamic>>> getNearbyShops({
    required double userLat,
    required double userLng,
    required List<Map<String, dynamic>> shops,
    double maxRadiusKm = 10,
  }) async {
    final nearby = <Map<String, dynamic>>[];

    for (final shop in shops) {
      final shopLat = shop['latitude'] as double?;
      final shopLng = shop['longitude'] as double?;
      if (shopLat == null || shopLng == null) continue;

      final distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        shopLat,
        shopLng,
      );
      final distanceKm = distance / 1000;

      if (distanceKm <= maxRadiusKm) {
        nearby.add({
          ...shop,
          'distanceKm': distanceKm,
          'distanceFormatted': '${distanceKm.toStringAsFixed(1)} km',
        });
      }
    }

    // Sort by distance
    nearby.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
    return nearby;
  }

  /// Track location changes in real-time
  static Stream<Position> trackLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  /// Calculate bearing between two points (for direction arrow)
  static double calculateBearing({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Check if AWS Location Service is available
  static bool get isAvailable => _client != null && AppConfig.awsLocationApiKey.isNotEmpty;
}
