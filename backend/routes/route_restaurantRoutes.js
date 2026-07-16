
const express = require('express');
const router = express.Router();
const restaurantController = require('../controllers/controller_RestaurantController');
const { authenticate, authorize } = require('../middleware/middleware_auth');

router.get('/nearby', restaurantController.getNearbyRestaurants);
router.get('/', restaurantController.getRestaurants);
router.get('/:id', restaurantController.getRestaurantById);
router.post('/', authenticate, authorize('restaurant', 'admin'), restaurantController.createRestaurant);
router.put('/:id', authenticate, authorize('restaurant', 'admin'), restaurantController.updateRestaurant);

module.exports = router;
