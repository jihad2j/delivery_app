
const Order = require('../models/model_Order');
const User = require('../models/model_User');
// البحث عن السائقين القريبين من المطعم
async function findNearbyDrivers(restaurantLocation, radius = 5000) {
  try {
    const drivers = await User.find({
      role: 'driver',
      status: 'active',
      'driverInfo.availability': true,
      'driverInfo.currentLocation': {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [restaurantLocation.coordinates[0], restaurantLocation.coordinates[1]]
          },
          $maxDistance: radius
        }
      }
    });
    return drivers;
  } catch (error) {
    console.error('Error finding nearby drivers:', error);
    return [];
  }
}
// تتبع موقع السائق أثناء التوصيل
async function trackDriverLocation(orderId, driverId, coordinates) {
  try {
    const locationEntry = {
      location: {
        type: 'Point',
        coordinates: [coordinates.lng, coordinates.lat]
      },
      timestamp: new Date()
    };

    await User.findByIdAndUpdate(driverId, {
      'driverInfo.currentLocation': {
        type: 'Point',
        coordinates: [coordinates.lng, coordinates.lat]
      }
    });

    const order = await Order.findByIdAndUpdate(
      orderId,
      { $push: { driverLocationHistory: locationEntry } },
      { returnDocument: 'after' }
    );

    return order;
  } catch (error) {
    console.error('Error tracking driver location:', error);
    throw error;
  }
}

module.exports = { findNearbyDrivers, trackDriverLocation };
