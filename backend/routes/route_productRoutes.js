
const express = require('express');
const router = express.Router();
const productController = require('../controllers/controller_ProductController');
const { authenticate, authorize } = require('../middleware/middleware_auth');

router.get('/', productController.getProducts);
router.get('/:id', productController.getProductById);
router.post('/', authenticate, authorize('restaurant', 'admin'), productController.createProduct);
router.put('/:id', authenticate, authorize('restaurant', 'admin'), productController.updateProduct);
router.delete('/:id', authenticate, authorize('restaurant', 'admin'), productController.deleteProduct);

module.exports = router;
