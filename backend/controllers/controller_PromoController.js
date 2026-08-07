const PromoCode = require('../models/model_PromoCode');

// التحقق من صلاحية كود الخصم (للعملاء)
exports.validatePromoCode = async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) {
      return res.status(400).json({ message: 'الرجاء إدخال كود الخصم' });
    }

    const promo = await PromoCode.findOne({ code: code.toUpperCase() });
    if (!promo) {
      return res.status(404).json({ message: 'كود الخصم غير صحيح' });
    }

    if (!promo.isActive) {
      return res.status(400).json({ message: 'كود الخصم غير فعال حالياً' });
    }

    if (new Date() > promo.validUntil) {
      return res.status(400).json({ message: 'لقد انتهت صلاحية كود الخصم' });
    }

    res.json({
      message: 'كود خصم صحيح',
      promo: {
        code: promo.code,
        discountType: promo.discountType,
        discountValue: promo.discountValue
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// إنشاء كود خصم جديد (للإدارة)
exports.createPromoCode = async (req, res) => {
  try {
    const { code, discountType, discountValue, validUntil } = req.body;
    
    const existing = await PromoCode.findOne({ code: code.toUpperCase() });
    if (existing) {
      return res.status(400).json({ message: 'كود الخصم موجود مسبقاً' });
    }

    const promo = new PromoCode({
      code,
      discountType,
      discountValue,
      validUntil
    });

    await promo.save();
    res.status(201).json({ message: 'تم إنشاء كود الخصم بنجاح', promo });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// الحصول على كل أكواد الخصم (للإدارة)
exports.getAllPromoCodes = async (req, res) => {
  try {
    const promos = await PromoCode.find().sort({ createdAt: -1 });
    res.json(promos);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// تعطيل/تفعيل كود خصم
exports.togglePromoCodeStatus = async (req, res) => {
  try {
    const promo = await PromoCode.findById(req.params.id);
    if (!promo) {
      return res.status(404).json({ message: 'كود الخصم غير موجود' });
    }
    
    promo.isActive = !promo.isActive;
    await promo.save();
    
    res.json({ message: 'تم تحديث حالة كود الخصم', promo });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
