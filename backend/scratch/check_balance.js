require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/model_User');

async function check() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/delivery_db');
  console.log('Connected to MongoDB');

  const users = await User.find({ role: 'customer' });
  console.log(`Found ${users.length} customer users:`);
  for (const u of users) {
    console.log(`ID: ${u._id}, Name: ${u.name}, Balance: ${u.balance} (Type: ${typeof u.balance}), Email: ${u.email}`);
  }

  await mongoose.disconnect();
}

check().catch(console.error);
