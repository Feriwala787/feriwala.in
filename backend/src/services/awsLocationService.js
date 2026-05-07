const {
  LocationClient,
  SearchPlaceIndexForPositionCommand,
  SearchPlaceIndexForTextCommand,
  CalculateRouteCommand,
  CalculateRouteMatrixCommand,
  CreateGeofenceCollectionCommand,
  PutGeofenceCommand,
  BatchEvaluateGeofencesCommand,
  CreateTrackerCommand,
  BatchUpdateDevicePositionCommand,
  GetDevicePositionHistoryCommand,
} = require('@aws-sdk/client-location');

const client = new LocationClient({
  region: process.env.AWS_REGION || 'ap-south-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

const PLACE_INDEX_NAME = process.env.AWS_PLACE_INDEX_NAME || 'feriwala-places';
const ROUTE_CALCULATOR_NAME = process.env.AWS_ROUTE_CALCULATOR_NAME || 'feriwala-routes';
const GEOFENCE_COLLECTION_NAME = process.env.AWS_GEOFENCE_COLLECTION_NAME || 'feriwala-geofences';
const TRACKER_NAME = process.env.AWS_TRACKER_NAME || 'feriwala-tracker';

// Maximum delivery radius in km (quick commerce standard)
const MAX_DELIVERY_RADIUS_KM = 5;
const TARGET_DELIVERY_TIME_MINUTES = 30;

/**
 * 1A. INSTANT SERVICEABILITY CHECK (GEOFENCING)
 * Check if customer location is within serviceable geofence
 */
async function checkServiceability({ latitude, longitude, shopId }) {
  try {
    const command = new BatchEvaluateGeofencesCommand({
      CollectionName: GEOFENCE_COLLECTION_NAME,
      DevicePositionUpdates: [
        {
          DeviceId: `temp-check-${Date.now()}`,
          Position: [longitude, latitude],
          SampleTime: new Date(),
        },
      ],
    });

    const response = await client.send(command);
    const geofences = response.Errors?.length === 0 ? response.Errors : [];
    
    // Check if point is inside shop's geofence
    const isServiceable = geofences.some(
      (gf) => gf.GeofenceId === `shop-${shopId}`
    );

    return {
      serviceable: isServiceable,
      geofenceId: isServiceable ? `shop-${shopId}` : null,
      message: isServiceable
        ? 'Location is serviceable'
        : 'Location is outside delivery zone',
    };
  } catch (error) {
    console.error('Serviceability check error:', error);
    // Fallback to simple radius check
    return null;
  }
}

/**
 * 1B. AUTO-DETECT LOCATION & REVERSE GEOCODING
 * Convert coordinates to formatted address
 */
async function reverseGeocode({ latitude, longitude }) {
  try {
    const command = new SearchPlaceIndexForPositionCommand({
      IndexName: PLACE_INDEX_NAME,
      Position: [longitude, latitude],
      MaxResults: 1,
    });

    const response = await client.send(command);
    
    if (response.Results && response.Results.length > 0) {
      const place = response.Results[0].Place;
      return {
        label: place.Label,
        street: place.Street,
        neighborhood: place.Neighborhood,
        municipality: place.Municipality,
        subRegion: place.SubRegion,
        region: place.Region,
        country: place.Country,
        postalCode: place.PostalCode,
        addressNumber: place.AddressNumber,
        geometry: {
          latitude: place.Geometry.Point[1],
          longitude: place.Geometry.Point[0],
        },
      };
    }
    return null;
  } catch (error) {
    console.error('Reverse geocode error:', error);
    return null;
  }
}

/**
 * 1C. FORWARD GEOCODING
 * Convert address text to coordinates
 */
async function forwardGeocode({ text, biasPosition = null }) {
  try {
    const command = new SearchPlaceIndexForTextCommand({
      IndexName: PLACE_INDEX_NAME,
      Text: text,
      MaxResults: 5,
      ...(biasPosition && {
        BiasPosition: [biasPosition.longitude, biasPosition.latitude],
      }),
    });

    const response = await client.send(command);
    
    return response.Results?.map((result) => ({
      label: result.Place.Label,
      geometry: {
        latitude: result.Place.Geometry.Point[1],
        longitude: result.Place.Geometry.Point[0],
      },
      relevance: result.Relevance,
    })) || [];
  } catch (error) {
    console.error('Forward geocode error:', error);
    return [];
  }
}

/**
 * 2A. TURN-BY-TURN ROUTING & ETAs
 * Calculate optimal route between two points
 */
async function calculateRoute({ origin, destination, departureTime = null }) {
  try {
    const command = new CalculateRouteCommand({
      CalculatorName: ROUTE_CALCULATOR_NAME,
      DeparturePosition: [origin.longitude, origin.latitude],
      DestinationPosition: [destination.longitude, destination.latitude],
      TravelMode: 'Motorcycle', // Two-wheeler optimized
      ...(departureTime && { DepartNow: false, DepartureTime: departureTime }),
      IncludeLegGeometry: true,
    });

    const response = await client.send(command);
    const leg = response.Legs[0];

    return {
      distanceKm: leg.Distance / 1000,
      durationMinutes: leg.DurationSeconds / 60,
      geometry: leg.Geometry.LineString, // For map rendering
      steps: leg.Steps?.map((step) => ({
        distance: step.Distance,
        duration: step.DurationSeconds,
        startPosition: step.StartPosition,
        endPosition: step.EndPosition,
      })),
      summary: response.Summary,
    };
  } catch (error) {
    console.error('Route calculation error:', error);
    return null;
  }
}

/**
 * 2C. MULTI-STOP BATCH ORDER ROUTING (TSP)
 * Calculate optimal sequence for multiple deliveries
 */
async function calculateOptimalRoute({ origin, destinations }) {
  try {
    // Build matrix of all points
    const allPositions = [
      [origin.longitude, origin.latitude],
      ...destinations.map((d) => [d.longitude, d.latitude]),
    ];

    const command = new CalculateRouteMatrixCommand({
      CalculatorName: ROUTE_CALCULATOR_NAME,
      DeparturePositions: allPositions,
      DestinationPositions: allPositions,
      TravelMode: 'Motorcycle',
    });

    const response = await client.send(command);
    
    // Simple greedy TSP solver
    const visited = new Set([0]); // Start at origin
    const sequence = [0];
    let current = 0;

    while (visited.size < allPositions.length) {
      let nearest = null;
      let minDuration = Infinity;

      for (let i = 0; i < allPositions.length; i++) {
        if (!visited.has(i)) {
          const routeData = response.RouteMatrix[current][i];
          if (routeData && routeData.DurationSeconds < minDuration) {
            minDuration = routeData.DurationSeconds;
            nearest = i;
          }
        }
      }

      if (nearest !== null) {
        visited.add(nearest);
        sequence.push(nearest);
        current = nearest;
      } else {
        break;
      }
    }

    // Build optimized route details
    const optimizedRoute = [];
    let totalDistance = 0;
    let totalDuration = 0;

    for (let i = 0; i < sequence.length - 1; i++) {
      const from = sequence[i];
      const to = sequence[i + 1];
      const routeData = response.RouteMatrix[from][to];

      if (routeData) {
        optimizedRoute.push({
          from: from === 0 ? 'origin' : `destination-${from - 1}`,
          to: to === 0 ? 'origin' : `destination-${to - 1}`,
          distanceKm: routeData.Distance / 1000,
          durationMinutes: routeData.DurationSeconds / 60,
        });
        totalDistance += routeData.Distance;
        totalDuration += routeData.DurationSeconds;
      }
    }

    return {
      sequence: sequence.slice(1).map((i) => i - 1), // Remove origin, adjust indices
      route: optimizedRoute,
      totalDistanceKm: totalDistance / 1000,
      totalDurationMinutes: totalDuration / 60,
      withinSLA: totalDuration / 60 <= TARGET_DELIVERY_TIME_MINUTES,
    };
  } catch (error) {
    console.error('Route matrix calculation error:', error);
    return null;
  }
}

/**
 * 3A. SUB-SECOND RIDER ASSIGNMENT
 * Find nearest available rider using route matrix
 */
async function findNearestRider({ shopLocation, riderLocations }) {
  try {
    if (riderLocations.length === 0) return null;

    const shopPos = [shopLocation.longitude, shopLocation.latitude];
    const riderPositions = riderLocations.map((r) => [r.longitude, r.latitude]);

    const command = new CalculateRouteMatrixCommand({
      CalculatorName: ROUTE_CALCULATOR_NAME,
      DeparturePositions: riderPositions,
      DestinationPositions: [shopPos],
      TravelMode: 'Motorcycle',
    });

    const response = await client.send(command);

    // Find rider with shortest travel time
    let nearestRider = null;
    let minDuration = Infinity;

    riderLocations.forEach((rider, index) => {
      const routeData = response.RouteMatrix[index][0];
      if (routeData && routeData.DurationSeconds < minDuration) {
        minDuration = routeData.DurationSeconds;
        nearestRider = {
          ...rider,
          distanceKm: routeData.Distance / 1000,
          etaMinutes: routeData.DurationSeconds / 60,
        };
      }
    });

    return nearestRider;
  } catch (error) {
    console.error('Nearest rider calculation error:', error);
    return null;
  }
}

/**
 * GEOFENCE MANAGEMENT
 * Create/update geofences for shops
 */
async function createShopGeofence({ shopId, latitude, longitude, radiusMeters = 5000 }) {
  try {
    // Create circular geofence around shop
    const command = new PutGeofenceCommand({
      CollectionName: GEOFENCE_COLLECTION_NAME,
      GeofenceId: `shop-${shopId}`,
      Geometry: {
        Circle: {
          Center: [longitude, latitude],
          Radius: radiusMeters,
        },
      },
    });

    await client.send(command);
    return { success: true, geofenceId: `shop-${shopId}` };
  } catch (error) {
    console.error('Create geofence error:', error);
    return { success: false, error: error.message };
  }
}

/**
 * TRACKER MANAGEMENT
 * Update rider location in tracker
 */
async function updateRiderLocation({ riderId, latitude, longitude }) {
  try {
    const command = new BatchUpdateDevicePositionCommand({
      TrackerName: TRACKER_NAME,
      Updates: [
        {
          DeviceId: `rider-${riderId}`,
          Position: [longitude, latitude],
          SampleTime: new Date(),
        },
      ],
    });

    await client.send(command);
    return { success: true };
  } catch (error) {
    console.error('Update rider location error:', error);
    return { success: false, error: error.message };
  }
}

/**
 * HISTORICAL TRACKING
 * Get rider position history for dispute resolution
 */
async function getRiderHistory({ riderId, startTime, endTime }) {
  try {
    const command = new GetDevicePositionHistoryCommand({
      TrackerName: TRACKER_NAME,
      DeviceId: `rider-${riderId}`,
      StartTimeInclusive: startTime,
      EndTimeExclusive: endTime,
    });

    const response = await client.send(command);
    
    return response.DevicePositions?.map((pos) => ({
      latitude: pos.Position[1],
      longitude: pos.Position[0],
      timestamp: pos.SampleTime,
      accuracy: pos.Accuracy,
    })) || [];
  } catch (error) {
    console.error('Get rider history error:', error);
    return [];
  }
}

/**
 * VALIDATE DELIVERY FEASIBILITY
 * Check if delivery can be completed within SLA
 */
async function validateDeliveryFeasibility({ shopLocation, customerLocation }) {
  try {
    const route = await calculateRoute({
      origin: shopLocation,
      destination: customerLocation,
    });

    if (!route) return { feasible: false, reason: 'Route calculation failed' };

    const distanceCheck = route.distanceKm <= MAX_DELIVERY_RADIUS_KM;
    const timeCheck = route.durationMinutes <= TARGET_DELIVERY_TIME_MINUTES;

    return {
      feasible: distanceCheck && timeCheck,
      distanceKm: route.distanceKm,
      estimatedMinutes: route.durationMinutes,
      withinRadius: distanceCheck,
      withinSLA: timeCheck,
      reason: !distanceCheck
        ? `Distance ${route.distanceKm.toFixed(1)}km exceeds ${MAX_DELIVERY_RADIUS_KM}km limit`
        : !timeCheck
        ? `Estimated time ${route.durationMinutes.toFixed(0)}min exceeds ${TARGET_DELIVERY_TIME_MINUTES}min SLA`
        : 'Delivery is feasible',
    };
  } catch (error) {
    console.error('Validate delivery feasibility error:', error);
    return { feasible: false, reason: 'Validation failed' };
  }
}

module.exports = {
  // Customer features
  checkServiceability,
  reverseGeocode,
  forwardGeocode,
  validateDeliveryFeasibility,
  
  // Rider features
  calculateRoute,
  calculateOptimalRoute,
  updateRiderLocation,
  getRiderHistory,
  
  // Admin features
  findNearestRider,
  createShopGeofence,
  
  // Constants
  MAX_DELIVERY_RADIUS_KM,
  TARGET_DELIVERY_TIME_MINUTES,
};
