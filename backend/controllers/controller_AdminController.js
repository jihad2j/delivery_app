
const User = require('../models/model_User');
const Order = require('../models/model_Order');

const Setting = require('../models/model_Setting');
const CurrencyRate = require('../models/model_CurrencyRate');
// الحصول على قائمة المستخدمين
exports.getAllUsers = async (req, res) => {
  try {
    const { role, status } = req.query;
    const filter = {};
    if (role) filter.role = role;
    if (status) filter.status = status;
    const users = await User.find(filter).select('-password');
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// تحديث حالة مستخدم محدد
exports.updateUserStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const user = await User.findByIdAndUpdate(req.params.id, { status }, { new: true }).select('-password');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// الحصول على معلومات الادارة
exports.getDashboardStats = async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalCustomers = await User.countDocuments({ role: 'customer' });
    const totalDrivers = await User.countDocuments({ role: 'driver' });
    const totalRestaurants = await User.countDocuments({ role: 'restaurant' });
    const totalOrders = await Order.countDocuments();
    const activeOrders = await Order.countDocuments({ status: { $nin: ['delivered', 'cancelled'] } });
    const totalRevenue = await Order.aggregate([
      { $match: { status: 'delivered' } },
      { $group: { _id: null, total: { $sum: '$totalAmount' } } }
    ]);

    res.json({
      totalUsers,
      totalCustomers,
      totalDrivers,
      totalRestaurants,
      totalOrders,
      activeOrders,
      totalRevenue: totalRevenue[0]?.total || 0
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// تحديث معلومات الادارة
exports.updateSettings = async (req, res) => {
  try {
    const { key, value } = req.body;
    const setting = await Setting.findOneAndUpdate(
      { key },
      { value },
      { upsert: true, new: true }
    );
    res.json(setting);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// الحصول على اعدادات 
exports.getSettings = async (req, res) => {
  try {
    const settings = await Setting.find();
    res.json(settings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// تحديث سعر الصرف 
exports.updateCurrencyRate = async (req, res) => {
  try {
    const { rate } = req.body;
    const currencyRate = await CurrencyRate.findOneAndUpdate(
      { baseCurrency: 'USD', targetCurrency: 'SYP' },
      { rate, updatedBy: req.user.userId },
      { upsert: true, new: true }
    );
    res.json(currencyRate);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// الحصول على سعر الصرف 
exports.getCurrencyRate = async (req, res) => {
  try {
    const rate = await CurrencyRate.findOne({ baseCurrency: 'USD', targetCurrency: 'SYP' });
    res.json(rate || { rate: 0 });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
