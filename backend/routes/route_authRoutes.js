
const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const authController = require('../controllers/controller_AuthController');
const { authenticate } = require('../middleware/middleware_auth');

// Brute-force protection: max 10 requests per 15 minutes per IP
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  limit: 10,
  message: { message: 'Too many authentication attempts from this IP, please try again after 15 minutes' },
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});

router.post('/register', authLimiter, authController.register);
router.post('/login', authLimiter, authController.login);
router.get('/regions', authController.getRegions);
router.get('/profile', authenticate, authController.getProfile);
router.put('/profile', authenticate, authController.updateProfile);
router.post('/settle-driver', authenticate, authController.settleDriverWallet);
router.post('/respond-settlement', authenticate, authController.respondDriverSettlement);

module.exports = router;
