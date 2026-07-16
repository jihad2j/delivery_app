
const mongoose = require('mongoose');

// جدول سعر العملات
const currencyRateSchema = new mongoose.Schema({
  // العملة الأساسية
  baseCurrency: {
    type: String,
    enum: ['USD'],
    default: 'USD'
  },
  // العملة المستهدفة
  targetCurrency: {
    type: String,
    enum: ['SYP'],
    default: 'SYP'
  },
  // سعر الصرف
  rate: { type: Number, required: true },
  // معلومات المستخدم الذي قام بتحديث السعر
  updatedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, { timestamps: true });

module.exports = mongoose.model('CurrencyRate', currencyRateSchema);
