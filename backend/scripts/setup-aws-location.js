#!/usr/bin/env node

/**
 * AWS Location Service Setup Script
 * Creates all required resources for Feriwala quick commerce
 */

const {
  LocationClient,
  CreatePlaceIndexCommand,
  CreateRouteCalculatorCommand,
  CreateGeofenceCollectionCommand,
  CreateTrackerCommand,
  CreateMapCommand,
} = require('@aws-sdk/client-location');

const client = new LocationClient({
  region: process.env.AWS_REGION || 'ap-south-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

const resources = [
  {
    name: 'Place Index',
    command: new CreatePlaceIndexCommand({
      IndexName: 'feriwala-places',
      DataSource: 'Esri',
      PricingPlan: 'RequestBasedUsage',
      Description: 'Place index for address search and geocoding',
    }),
  },
  {
    name: 'Route Calculator',
    command: new CreateRouteCalculatorCommand({
      CalculatorName: 'feriwala-routes',
      DataSource: 'Esri',
      PricingPlan: 'RequestBasedUsage',
      Description: 'Route calculator for turn-by-turn navigation and ETAs',
    }),
  },
  {
    name: 'Geofence Collection',
    command: new CreateGeofenceCollectionCommand({
      CollectionName: 'feriwala-geofences',
      PricingPlan: 'RequestBasedUsage',
      Description: 'Geofence collection for shop service areas',
    }),
  },
  {
    name: 'Tracker',
    command: new CreateTrackerCommand({
      TrackerName: 'feriwala-tracker',
      PricingPlan: 'RequestBasedUsage',
      PositionFiltering: 'TimeBased',
      Description: 'Tracker for real-time rider location tracking',
    }),
  },
  {
    name: 'Map',
    command: new CreateMapCommand({
      MapName: 'feriwala-map',
      Configuration: {
        Style: 'VectorEsriStreets',
      },
      PricingPlan: 'RequestBasedUsage',
      Description: 'Map for customer and rider apps',
    }),
  },
];

async function setupAWSLocation() {
  console.log('🚀 Setting up AWS Location Service resources...\n');

  for (const resource of resources) {
    try {
      console.log(`Creating ${resource.name}...`);
      await client.send(resource.command);
      console.log(`✅ ${resource.name} created successfully\n`);
    } catch (error) {
      if (error.name === 'ConflictException') {
        console.log(`⚠️  ${resource.name} already exists\n`);
      } else {
        console.error(`❌ Failed to create ${resource.name}:`, error.message, '\n');
      }
    }
  }

  console.log('✅ AWS Location Service setup complete!\n');
  console.log('📝 Add these to your .env file:');
  console.log('AWS_PLACE_INDEX_NAME=feriwala-places');
  console.log('AWS_ROUTE_CALCULATOR_NAME=feriwala-routes');
  console.log('AWS_GEOFENCE_COLLECTION_NAME=feriwala-geofences');
  console.log('AWS_TRACKER_NAME=feriwala-tracker');
  console.log('AWS_MAP_NAME=feriwala-map');
}

setupAWSLocation().catch(console.error);
