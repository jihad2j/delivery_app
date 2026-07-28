
const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  // ايدي المطعم  
  restaurantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  // اسم المنتج
  name: { type: String, required: true },
  // وصف المنتج
  description: String,
  // صورة المنتج
  image: { type: String, required: true },
  // سعر المنتج
  price: { type: Number, required: true },
  currency: {
    type: String,
    enum: ['SYP'],
  },
  // نوع المنتج
  category: {
    type: String,
    enum: ['mainCourse', 'dessert', 'drink', 'appetizer'],
    default: 'mainCourse'
  },
  // متاح للطلب
  isAvailable: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('Product', productSchema);
