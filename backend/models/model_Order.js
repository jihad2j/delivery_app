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
  items: [orderItemSchema],
  totalAmount: { type: Number, required: true },
  currency: { type: String, default: 'SYP' },
  deliveryFee: { type: Number, required: true, default: 0},
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
  paymentMethod: { type: String, enum: ['cash', 'wallet'], default: 'cash' },
  paymentStatus: { type: String, enum: ['paid', 'unpaid'], default: 'unpaid' },
  expectedDeliveryTime: { type: Date },
  platformCommission: { type: Number },
  restaurantShare: { type: Number },
  driverShare: { type: Number },
  packagedPicture: { type: String },
  receivedPicture: { type: String }
}, { timestamps: true });

orderSchema.index({ 'deliveryAddress.location': '2dsphere' });

module.exports = mongoose.model('Order', orderSchema);
