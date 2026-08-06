
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
    const incomingStatus = updates.status;
    delete updates.password;
    delete updates.role;
    delete updates.email;
    delete updates.balance;
    delete updates.status;

    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ message: 'لم يتم العثور على المستخدم' });

    const $set = {};

    if (updates.name !== undefined) $set.name = updates.name;
    if (updates.phone !== undefined) $set.phone = updates.phone;
    if (updates.address !== undefined) $set.address = updates.address;
    if (updates.addresses !== undefined) $set.addresses = updates.addresses;
    if (updates.profilePicture !== undefined) $set.profilePicture = updates.profilePicture;

    if (user.role === 'restaurant') {
      const restaurantFields = ['description', 'logo', 'status', 'minOrderAmount', 'deliveryFee', 'cuisineType', 'firebaseNotifications', 'openingTime', 'closingTime'];
      
      const newRestaurantStatus = updates.restaurantInfo?.status || incomingStatus;
      if (newRestaurantStatus && ['open', 'closed', 'busy'].includes(newRestaurantStatus)) {
        $set['restaurantInfo.status'] = newRestaurantStatus;
      }

      if (updates.restaurantInfo && typeof updates.restaurantInfo === 'object') {
        for (const key of restaurantFields) {
          if (updates.restaurantInfo[key] !== undefined) {
            $set[`restaurantInfo.${key}`] = updates.restaurantInfo[key];
          }
        }
      }

      for (const key of restaurantFields) {
        if (updates[key] !== undefined) {
          $set[`restaurantInfo.${key}`] = updates[key];
        }
      }
    }

    if (user.role === 'driver' && updates.driverInfo && typeof updates.driverInfo === 'object') {
      for (const key of Object.keys(updates.driverInfo)) {
        $set[`driverInfo.${key}`] = updates.driverInfo[key];
      }
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.user.userId,
      Object.keys($set).length > 0 ? { $set } : updates,
      { returnDocument: 'after' }
    ).select('-password');

    res.json(updatedUser);
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

    // دمج النتائج وحذف المكرر والقيم الفارغة بعد التهذيب (Trim)
    const cleaned = [...regionsMain, ...regionsSub]
      .filter(Boolean)
      .map(r => (typeof r === 'string' ? r.trim() : String(r)))
      .filter(r => r.length > 0 && r !== 'manual_entry');

    const allRegions = Array.from(new Set(cleaned));

    res.json(allRegions);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ترصيد محفظة السائق (تصفير كاش الزبائن، أو تصفير أرباح التوصيل، أو الاثنين منفصلين)
exports.settleDriverWallet = async (req, res) => {
  try {
    const { settlementType } = req.body; // 'cash' | 'earnings' | 'both'
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'المستخدم غير موجود' });

    const updateFields = {};
    let message = '';
    let cashAmountToAdd = 0;

    if (settlementType === 'cash') {
      cashAmountToAdd = user.customerPaymentsWallet || 0;
      updateFields.customerPaymentsWallet = 0;
      message = 'تم ترصيد وتصفير ذمة كاش الزبائن بنجاح';
    } else if (settlementType === 'earnings') {
      updateFields.driverEarningsWallet = 0;
      message = 'تم ترصيد وتصفير أرباح التوصيل بنجاح';
    } else if (settlementType === 'both') {
      cashAmountToAdd = user.customerPaymentsWallet || 0;
      updateFields.customerPaymentsWallet = 0;
      updateFields.driverEarningsWallet = 0;
      message = 'تم ترصيد وتصفير كامل حسابات السائق بنجاح';
    } else {
      return res.status(400).json({ message: 'نوع الترصيد غير صالح' });
    }

    updateFields.pendingSettlement = null;

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $set: updateFields },
      { returnDocument: 'after' }
    ).select('-password');

    // تحويل كاش الزبائن المستلم إلى خزينة الشركة المركزية
    if (cashAmountToAdd > 0) {
      const Setting = require('../models/model_Setting');
      let treasury = await Setting.findOne({ key: 'companyTreasury' });
      const currentVal = treasury?.value?.totalCashCollected || 0;
      await Setting.findOneAndUpdate(
        { key: 'companyTreasury' },
        { value: { totalCashCollected: currentVal + cashAmountToAdd, updatedAt: new Date() } },
        { upsert: true }
      );
    }

    res.json({
      message,
      user: updatedUser
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// إجابة السائق على طلب الترصيد (موافقة أو رفض)
exports.respondDriverSettlement = async (req, res) => {
  try {
    const { approved } = req.body;
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (!user || !user.pendingSettlement || !user.pendingSettlement.requestId) {
      return res.status(400).json({ message: 'لا يوجد طلب ترصيد معلّق حالياً' });
    }

    if (!approved) {
      user.pendingSettlement = null;
      await user.save();
      return res.json({ message: 'تم رفض طلب الترصيد', user });
    }

    const { settlementType } = user.pendingSettlement;
    let cashAmountToAdd = 0;
    const updateFields = {};

    if (settlementType === 'cash') {
      cashAmountToAdd = user.customerPaymentsWallet || 0;
      updateFields.customerPaymentsWallet = 0;
    } else if (settlementType === 'earnings') {
      updateFields.driverEarningsWallet = 0;
    } else if (settlementType === 'both') {
      cashAmountToAdd = user.customerPaymentsWallet || 0;
      updateFields.customerPaymentsWallet = 0;
      updateFields.driverEarningsWallet = 0;
    }

    updateFields.pendingSettlement = null;

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $set: updateFields },
      { returnDocument: 'after' }
    ).select('-password');

    // تحويل كاش الزبائن المستلم إلى خزينة الشركة المركزية
    if (cashAmountToAdd > 0) {
      const Setting = require('../models/model_Setting');
      let treasury = await Setting.findOne({ key: 'companyTreasury' });
      const currentVal = treasury?.value?.totalCashCollected || 0;
      await Setting.findOneAndUpdate(
        { key: 'companyTreasury' },
        { value: { totalCashCollected: currentVal + cashAmountToAdd, updatedAt: new Date() } },
        { upsert: true }
      );
    }

    res.json({
      message: 'تم تأكيد الترصيد وتصفير الحساب بنجاح',
      user: updatedUser
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
