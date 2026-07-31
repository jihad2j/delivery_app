
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  phone: { type: String, required: true, unique: true },
  role: {
    type: String,
    enum: ['customer', 'driver', 'restaurant', 'admin'],
    required: true
  },
  status: {
    type: String,
    enum: ['active', 'inactive', 'blocked'],
    default: 'active'
  },
  // صورة الملف الشخصي
  profilePicture: { type: String },
  //عنوان المستخدم
  address: {
    governorate: String, // المحافظة
    region: String, // المنطقة
    details: String, // التفاصيل (الحارة - اسم الشارع - بيت أبوخليل...)
    street: String,
    city: String,
    zipCode: String,
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] }
    }
  },
  // قائمة المواقع المخزنة (خاص بالعملاء)
  addresses: [{
    label: { type: String, required: true }, // بيتي - محلي - إلخ
    governorate: String,
    region: String,
    details: String,
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] }
    }
  }],
  // معلومات المطعم (في حال كان المستخدم مطعم)
  restaurantInfo: {
    description: String,
    logo: { type: String, default: 'https://via.placeholder.com/150' },
    status: {
      type: String,
      enum: ['open', 'closed', 'busy'],
      default: 'open'
    },
    minOrderAmount: { type: Number, default: 0 },
    deliveryFee: { type: Number, default: 0 },
    cuisineType: { type: String, default: 'مشاوي' },
    firebaseNotifications: { type: Boolean, default: true },
    menu: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Product' }]
  },
  // معلومات التوصيل
  driverInfo: { 
    vehicleType: String,
    licenseNumber: String,
    // حالة التوصيل
    availability: { type: Boolean, default: false },
    // الموقع الحالي
    currentLocation: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] }
    }
  },
  // رصيد المستخدم العام (للزبائن والمطاعم)
  balance: { type: Number, default: 0 },
  // محفظة مدفوعات الزبائن النقدية (خاصة بالسائق)
  customerPaymentsWallet: { type: Number, default: 0 },
  // محفظة أرباح التوصيل (خاصة بالسائق)
  driverEarningsWallet: { type: Number, default: 0 },
  // صلاحيات الأدمن المخصصة
  adminPermissions: {
    type: [String],
    default: [
      'users_management',
      'drivers_management',
      'restaurants_management',
      'orders_management',
      'balances_management',
      'permissions_management'
    ]
  },
  // طلب ترصيد معلّق بانتظار تأكيد السائق
  pendingSettlement: {
    requestId: String,
    settlementType: { type: String, enum: ['cash', 'earnings', 'both'] },
    amount: { type: Number, default: 0 },
    requestedByName: { type: String, default: 'الإدارة' },
    requestedAt: Date
  }
}, { timestamps: true });
// معلومات المستخدم
userSchema.index({ 'address.location': '2dsphere' });
// معلومات التوصيل
userSchema.index({ 'driverInfo.currentLocation': '2dsphere' });

module.exports = mongoose.model('User', userSchema);
