const express = require('express');
const router = express.Router();
const promoController = require('../controllers/controller_PromoController');
const { authenticate, authorize } = require('../middleware/middleware_auth');

// Customer Route
router.post('/validate', authenticate, promoController.validatePromoCode);

// Admin Routes
router.post('/', authenticate, authorize('admin'), promoController.createPromoCode);
router.get('/', authenticate, authorize('admin'), promoController.getAllPromoCodes);
router.put('/:id/toggle', authenticate, authorize('admin'), promoController.togglePromoCodeStatus);

module.exports = router;
