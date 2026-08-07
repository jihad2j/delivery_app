
const express = require('express');
const router = express.Router();
const adminController = require('../controllers/controller_AdminController');
const { authenticate, authorize } = require('../middleware/middleware_auth');

router.get('/currency-rate', adminController.getCurrencyRate);

router.use(authenticate, authorize('admin'));

router.get('/users', adminController.getAllUsers);
router.put('/users/:id/status', adminController.updateUserStatus);
router.get('/dashboard', adminController.getDashboardStats);
router.get('/settings', adminController.getSettings);
router.put('/settings', adminController.updateSettings);
router.put('/currency-rate', adminController.updateCurrencyRate);
router.get('/admins', adminController.getAllAdmins);
router.put('/admins/:id/permissions', adminController.updateAdminPermissions);
router.post('/request-settlement', adminController.requestDriverSettlement);
router.get('/treasury', adminController.getCompanyTreasury);
router.post('/broadcast', adminController.sendBroadcast);

module.exports = router;
