
const mongoose = require('mongoose');

const settingSchema = new mongoose.Schema({
  // حقل القيمة
  key: {
    type: String,
    required: true,
    unique: true
  },
  value: { type: mongoose.Schema.Types.Mixed, required: true }
}, { timestamps: true });

module.exports = mongoose.model('Setting', settingSchema);
