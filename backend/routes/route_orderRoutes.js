const express = require('express');
const router = express.Router();
const orderController = require('../controllers/controller_OrderController');
const { authenticate, authorize } = require('../middleware/middleware_auth');

// POST /api/orders (Create order)
router.post('/', authenticate, orderController.createOrder);

// GET /api/orders (Get orders list / available orders)
router.get('/', authenticate, orderController.getOrders);

// GET /api/orders/:id (Get order details)
router.get('/:id', authenticate, orderController.getOrderById);

// PUT /api/orders/:id/status (Update order status)
router.put('/:id/status', authenticate, orderController.updateOrderStatus);

// PUT /api/orders/:id/accept (Accept order by driver)
router.put('/:id/accept', authenticate, authorize('driver', 'admin'), orderController.acceptOrderByDriver);

// PUT /api/orders/:id/reject (Reject order by driver)
router.put('/:id/reject', authenticate, authorize('driver', 'admin'), orderController.rejectOrderByDriver);

// PUT /api/orders/:id/deliver (Driver marks arrived / delivered_pending)
router.put('/:id/deliver', authenticate, authorize('driver', 'admin'), orderController.confirmDelivery);

// PUT /api/orders/:id/customer-confirm (Customer confirms delivery / delivered)
router.put('/:id/customer-confirm', authenticate, authorize('customer', 'admin'), orderController.customerConfirmDelivery);

// PUT /api/orders/:id/rate (Customer rates order)
router.put('/:id/rate', authenticate, authorize('customer', 'admin'), orderController.rateOrder);

// PUT /api/orders/:id/assign (Admin assigns driver)
router.put('/:id/assign', authenticate, authorize('admin'), orderController.assignDriver);

module.exports = router;
