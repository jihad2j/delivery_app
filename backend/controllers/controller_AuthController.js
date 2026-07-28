
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/model_User');
// تسجيل حساب جديد
exports.register = async (req, res) => {
  try {
    const { name, email, password, phone, role, driverInfo, cuisineType, address } = req.body;

    const allowedRoles = ['customer', 'driver', 'restaurant'];
    if (!allowedRoles.includes(role)) {
      return res.status(400).json({ message: 'Invalid or restricted role' });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { phone }] });
    if (existingUser) {
      return res.status(400).json({ message: 'البريد الالكتروني او رقم الهاتف مسجل مسبقا' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ name, email, password: hashedPassword, phone, role, driverInfo, address });

    if (role === 'restaurant') {
      user.restaurantInfo = {
        logo: 'https://via.placeholder.com/150',
        status: 'open',
        minOrderAmount: 0,
        deliveryFee: 0,
        cuisineType: cuisineType || 'مشاوي',
        firebaseNotifications: true,
        menu: []
      };
    }

    await user.save();

    const token = jwt.sign(
      { userId: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '900d' }
    );

    res.status(201).json({
      token,
      user: { id: user._id, name: user.name, email: user.email, role: user.role, phone: user.phone }
    });
  } catch (error) {
    res.status(500).json({ message: 'فشل التسجيل', error: error.message });
  }
};

// تسجيل دخول
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ message: 'اسم المستخدم او كلمة المرور غير صحيحة' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ message: 'اسم المستخدم او كلمة المرور غير صحيحة' });

    if (user.status !== 'active') return res.status(403).json({ message: 'الحساب غير نشط' });

    const token = jwt.sign(
      { userId: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        status: user.status
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'فشل تسجيل الدخول', error: error.message });
  }
};

// الحصول على بيانات المستخدم
// الحصول على ملف تعريف المستخدم
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('-password');
    if (!user) return res.status(404).json({ message: 'لم يتم العثور على العميل' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// تحديث بيانات المستخدم
// تحديث ملف تعريف المستخدم
exports.updateProfile = async (req, res) => {
  try {
    const updates = req.body;
    delete updates.password;
    delete updates.role;
    delete updates.email;
    delete updates.balance;
    delete updates.status;

    const user = await User.findByIdAndUpdate(req.user.userId, updates, { returnDocument: 'after' }).select('-password');
    if (!user) return res.status(404).json({ message: 'لم يتم العثور على العميل' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// الحصول على المناطق المخزنة سابقاً بناءً على المحافظة
exports.getRegions = async (req, res) => {
  try {
    const { governorate } = req.query;
    
    // فلتر للموقع الرئيسي
    const filterMain = {};
    if (governorate) {
      filterMain['address.governorate'] = governorate;
    }
    const regionsMain = await User.distinct('address.region', filterMain);

    // فلتر للمواقع الإضافية للعملاء
    const filterSub = {};
    if (governorate) {
      filterSub['addresses.governorate'] = governorate;
    }
    const regionsSub = await User.distinct('addresses.region', filterSub);

    // دمج النتائج وحذف المكرر والقيم الفارغة
    const allRegions = Array.from(new Set([...regionsMain, ...regionsSub]))
      .filter(Boolean)
      .map(r => r.trim());

    res.json(allRegions);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
