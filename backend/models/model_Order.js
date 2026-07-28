const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  name: { type: String, required: true },
  quantity: { type: Number, required: true, default: 1 },
  price: { type: Number, required: true }
});

const orderSchema = new mongoose.Schema({
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  restaurantId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  driverId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  // قائمة المنتجات
  items: [orderItemSchema],
  // مبلغ الطلب الكلي
  totalAmount: { type: Number, required: true },
  // العملة
  currency: { type: String, default: 'SYP' },
  // رسوم التوصيل
  deliveryFee: { type: Number, required: true, default: 0 },
  status: {
    type: String,
    enum: [
      'pending',
      'restaurant_accepted',
      'preparing',
      'ready',
      'delivery_accepted',
      'onTheWay',
      'delivered_pending',
      'delivered',
      'cancelled'
    ],
    default: 'pending'
  },
  // عنوان التوصيل
  deliveryAddress: {
    label: String,
    governorate: String,
    region: String,
    details: String,
    street: String,
    city: String,
    zipCode: String,
    houseDoorPicture: String,
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] }
    }
  },
  paymentMethod: { type: String, enum: ['cash', 'wallet'], default: 'cash' }, // تحدد مسبقا عن شراء العميل للطلب
  paymentStatus: { type: String, enum: ['paid', 'unpaid'], default: 'unpaid' },//  تم الدفع ام لم يتم الدفع
  expectedDeliveryTime: { type: Date }, // الوقت المقدر
  platformCommission: { type: Number },//  رسوم الخدمة
  restaurantShare: { type: Number }, // سعر الوجبة من المطعم
  driverShare: { type: Number }, // رسوم التوصيل
  packagedPicture: { type: String },// صورة تغليف الطلب
  receivedPicture: { type: String } // صورة استلام الطلب
}, { timestamps: true });// تاريخ الطلب

orderSchema.index({ 'deliveryAddress.location': '2dsphere' });

module.exports = mongoose.model('Order', orderSchema);
