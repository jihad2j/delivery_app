
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
    const user = await User.findByIdAndUpdate(req.params.id, { status }, { returnDocument: 'after' }).select('-password');
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
      { upsert: true, returnDocument: 'after' }
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
      { upsert: true, returnDocument: 'after' }
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

// الحصول على قائمة كافة مديرين النظام (Admins) مع صلاحياتهم
exports.getAllAdmins = async (req, res) => {
  try {
    const admins = await User.find({ role: 'admin' }).select('-password');
    res.json(admins);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// تحديث صلاحيات مدير نظام محدد (Admin Permissions)
exports.updateAdminPermissions = async (req, res) => {
  try {
    const { permissions } = req.body; // Array of strings e.g. ['users_management', 'drivers_management']
    if (!Array.isArray(permissions)) {
      return res.status(400).json({ message: 'الصلاحيات يجب أن تكون مصفوفة نصية' });
    }

    const adminUser = await User.findByIdAndUpdate(
      req.params.id,
      { adminPermissions: permissions },
      { returnDocument: 'after' }
    ).select('-password');

    if (!adminUser) return res.status(404).json({ message: 'الأدمن غير موجود' });
    res.json(adminUser);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// طلب ترصيد حساب كابتن من قبل الأدمن (إرسال طلب تأكيد للسائق)
exports.requestDriverSettlement = async (req, res) => {
  try {
    const { driverId, settlementType } = req.body;
    const adminUser = await User.findById(req.user.userId);
    const driver = await User.findById(driverId);

    if (!driver || driver.role !== 'driver') {
      return res.status(404).json({ message: 'عامل التوصيل غير موجود' });
    }

    let amount = 0;
    if (settlementType === 'cash') {
      amount = driver.customerPaymentsWallet || 0;
    } else if (settlementType === 'earnings') {
      amount = driver.driverEarningsWallet || 0;
    } else if (settlementType === 'both') {
      amount = (driver.customerPaymentsWallet || 0) + (driver.driverEarningsWallet || 0);
    } else {
      return res.status(400).json({ message: 'نوع الترصيد غير صالح' });
    }

    if (amount <= 0) {
      return res.status(400).json({ message: 'لا يوجد رصيد قابل للترصيد لهذا الحساب حالياً' });
    }

    const requestId = 'REQ_' + Date.now();
    driver.pendingSettlement = {
      requestId,
      settlementType,
      amount,
      requestedByName: adminUser?.name || 'الأدمن المحاسب',
      requestedAt: new Date()
    };

    await driver.save();

    res.json({
      message: 'تم إرسال طلب الترصيد للسائق بنجاح، بانتظار تأكيد وموافقة السائق',
      driver
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// الحصول على إجمالي خزينة الشركة والسيولة المجمعة من الكاش
exports.getCompanyTreasury = async (req, res) => {
  try {
    let treasurySetting = await Setting.findOne({ key: 'companyTreasury' });
    if (!treasurySetting) {
      treasurySetting = await Setting.create({ key: 'companyTreasury', value: { totalCashCollected: 0 } });
    }
    res.json(treasurySetting.value);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// إرسال إشعار جماعي لجميع المستخدمين عبر Socket.io
// ============================================================
exports.sendBroadcast = async (req, res) => {
  try {
    const { title, message } = req.body;
    
    if (!title || !message) {
      return res.status(400).json({ message: 'العنوان والرسالة مطلوبان' });
    }

    // هنا نحن نفترض وجود إعداد مسبق للـ io في الـ req عبر middleware 
    // أو عبر إرسال حدث. للتبسيط، سنحتاج لربط الـ io بـ req في server.js
    if (req.io) {
      req.io.emit('broadcast_message', {
        title,
        message,
        timestamp: new Date()
      });
      res.json({ message: 'تم إرسال الإشعار لجميع المستخدمين بنجاح' });
    } else {
      res.status(500).json({ message: 'Socket.io غير متصل بالخادم حالياً' });
    }
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
