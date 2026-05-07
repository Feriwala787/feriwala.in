const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const awsLocation = require('../services/awsLocationService');
const Shop = require('../models/pg/Shop');
const DeliveryAgentProfile = require('../models/mongo/DeliveryAgentProfile');

/**
 * 1A. INSTANT SERVICEABILITY CHECK
 * POST /api/location/serviceability
 * Check if customer location is within serviceable geofence
 */
router.post('/serviceability', authenticate, authorize('customer'), [
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
  body('shopId').isInt(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { latitude, longitude, shopId } = req.body;

    const shop = await Shop.findByPk(shopId);
    if (!shop || !shop.isActive) {
      return res.status(404).json({ success: false, message: 'Shop not found' });
    }

    // Try AWS Location Service geofence check first
    const geofenceCheck = await awsLocation.checkServiceability({
      latitude,
      longitude,
      shopId,
    });

    if (geofenceCheck) {
      return res.json({
        success: true,
        data: {
          serviceable: geofenceCheck.serviceable,
          method: 'geofence',
          message: geofenceCheck.message,
        },
      });
    }

    // Fallback: Validate delivery feasibility with routing
    const feasibility = await awsLocation.validateDeliveryFeasibility({
      shopLocation: {
        latitude: Number(shop.latitude),
        longitude: Number(shop.longitude),
      },
      customerLocation: { latitude, longitude },
    });

    res.json({
      success: true,
      data: {
        serviceable: feasibility.feasible,
        method: 'routing',
        distanceKm: feasibility.distanceKm,
        estimatedMinutes: feasibility.estimatedMinutes,
        withinRadius: feasibility.withinRadius,
        withinSLA: feasibility.withinSLA,
        message: feasibility.reason,
        maxRadiusKm: awsLocation.MAX_DELIVERY_RADIUS_KM,
        targetDeliveryMinutes: awsLocation.TARGET_DELIVERY_TIME_MINUTES,
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * 1B. REVERSE GEOCODING
 * POST /api/location/reverse-geocode
 * Convert coordinates to formatted address
 */
router.post('/reverse-geocode', authenticate, [
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { latitude, longitude } = req.body;

    const address = await awsLocation.reverseGeocode({ latitude, longitude });

    if (!address) {
      return res.status(404).json({
        success: false,
        message: 'Address not found for coordinates',
      });
    }

    res.json({ success: true, data: address });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * 1C. FORWARD GEOCODING / PLACE SEARCH
 * POST /api/location/search
 * Search for places and get coordinates
 */
router.post('/search', authenticate, [
  body('query').isString().isLength({ min: 3 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { query, biasLatitude, biasLongitude } = req.body;

    const biasPosition = biasLatitude && biasLongitude
      ? { latitude: biasLatitude, longitude: biasLongitude }
      : null;

    const results = await awsLocation.forwardGeocode({
      text: query,
      biasPosition,
    });

    res.json({ success: true, data: results });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * 2A. CALCULATE ROUTE (TURN-BY-TURN)
 * POST /api/location/route
 * Get optimal route between two points
 */
router.post('/route', authenticate, [
  body('origin').isObject(),
  body('origin.latitude').isFloat(),
  body('origin.longitude').isFloat(),
  body('destination').isObject(),
  body('destination.latitude').isFloat(),
  body('destination.longitude').isFloat(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { origin, destination, departureTime } = req.body;

    const route = await awsLocation.calculateRoute({
      origin,
      destination,
      departureTime: departureTime ? new Date(departureTime) : null,
    });

    if (!route) {
      return res.status(404).json({
        success: false,
        message: 'Route not found',
      });
    }

    res.json({ success: true, data: route });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * 2C. MULTI-STOP BATCH ROUTING (TSP)
 * POST /api/location/optimize-route
 * Calculate optimal sequence for multiple deliveries
 */
router.post('/optimize-route', authenticate, authorize('delivery_agent', 'admin'), [
  body('origin').isObject(),
  body('destinations').isArray({ min: 1, max: 10 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { origin, destinations } = req.body;

    const optimizedRoute = await awsLocation.calculateOptimalRoute({
      origin,
      destinations,
    });

    if (!optimizedRoute) {
      return res.status(500).json({
        success: false,
        message: 'Route optimization failed',
      });
    }

    res.json({ success: true, data: optimizedRoute });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * 3A. FIND NEAREST RIDER
 * POST /api/location/nearest-rider
 * Find closest available rider to shop
 */
router.post('/nearest-rider', authenticate, authorize('shop_admin', 'admin'), [
  body('shopId').isInt(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { shopId } = req.body;

    const shop = await Shop.findByPk(shopId);
    if (!shop) {
      return res.status(404).json({ success: false, message: 'Shop not found' });
    }

    // Get available riders
    const availableRiders = await DeliveryAgentProfile.find({
      isOnline: true,
      isAvailable: true,
      'currentLocation.latitude': { $exists: true },
    });

    if (availableRiders.length === 0) {
      return res.json({
        success: true,
        data: null,
        message: 'No available riders',
      });
    }

    const riderLocations = availableRiders.map((rider) => ({
      riderId: rider.userId.toString(),
      latitude: rider.currentLocation.latitude,
      longitude: rider.currentLocation.longitude,
    }));

    const nearestRider = await awsLocation.findNearestRider({
      shopLocation: {
        latitude: Number(shop.latitude),
        longitude: Number(shop.longitude),
      },
      riderLocations,
    });

    res.json({ success: true, data: nearestRider });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * UPDATE RIDER LOCATION (Real-time tracking)
 * POST /api/location/rider/update
 * Update rider's current location in AWS Tracker
 */
router.post('/rider/update', authenticate, authorize('delivery_agent'), [
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { latitude, longitude } = req.body;
    const riderId = req.user._id.toString();

    // Update in MongoDB
    await DeliveryAgentProfile.findOneAndUpdate(
      { userId: riderId },
      {
        currentLocation: { latitude, longitude },
        lastLocationUpdate: new Date(),
      }
    );

    // Update in AWS Location Tracker
    const result = await awsLocation.updateRiderLocation({
      riderId,
      latitude,
      longitude,
    });

    // Emit socket event for real-time tracking
    const io = req.app.get('io');
    if (io) {
      io.to(`rider_${riderId}`).emit('location_updated', {
        latitude,
        longitude,
        timestamp: new Date(),
      });
    }

    res.json({ success: true, data: result });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * GET RIDER HISTORY (Dispute resolution)
 * GET /api/location/rider/:riderId/history
 * Get historical location data for a rider
 */
router.get('/rider/:riderId/history', authenticate, authorize('admin', 'shop_admin'), async (req, res) => {
  try {
    const { riderId } = req.params;
    const { startTime, endTime } = req.query;

    if (!startTime || !endTime) {
      return res.status(400).json({
        success: false,
        message: 'startTime and endTime are required',
      });
    }

    const history = await awsLocation.getRiderHistory({
      riderId,
      startTime: new Date(startTime),
      endTime: new Date(endTime),
    });

    res.json({ success: true, data: history });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * CREATE/UPDATE SHOP GEOFENCE
 * POST /api/location/geofence/shop
 * Create or update geofence for a shop
 */
router.post('/geofence/shop', authenticate, authorize('admin'), [
  body('shopId').isInt(),
  body('radiusMeters').optional().isInt({ min: 100, max: 10000 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { shopId, radiusMeters = 5000 } = req.body;

    const shop = await Shop.findByPk(shopId);
    if (!shop) {
      return res.status(404).json({ success: false, message: 'Shop not found' });
    }

    if (!shop.latitude || !shop.longitude) {
      return res.status(400).json({
        success: false,
        message: 'Shop coordinates not set',
      });
    }

    const result = await awsLocation.createShopGeofence({
      shopId,
      latitude: Number(shop.latitude),
      longitude: Number(shop.longitude),
      radiusMeters,
    });

    res.json({ success: true, data: result });
  } catch (error) {
    routeError(res, error);
  }
});

/**
 * BATCH CREATE GEOFENCES FOR ALL SHOPS
 * POST /api/location/geofence/batch-create
 * Create geofences for all active shops
 */
router.post('/geofence/batch-create', authenticate, authorize('admin'), async (req, res) => {
  try {
    const shops = await Shop.findAll({
      where: { isActive: true },
    });

    const results = [];
    for (const shop of shops) {
      if (shop.latitude && shop.longitude) {
        const result = await awsLocation.createShopGeofence({
          shopId: shop.id,
          latitude: Number(shop.latitude),
          longitude: Number(shop.longitude),
          radiusMeters: 5000, // 5km radius
        });
        results.push({ shopId: shop.id, ...result });
      }
    }

    res.json({
      success: true,
      data: {
        total: shops.length,
        created: results.filter((r) => r.success).length,
        failed: results.filter((r) => !r.success).length,
        results,
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
