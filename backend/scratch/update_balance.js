require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/model_User');

async function update() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/delivery_db');
  console.log('Connected to MongoDB');

  // Update all users to have 150,000 balance
  const result = await User.updateMany({}, { $set: { balance: 150000 } });
  console.log(`Updated ${result.modifiedCount} users to have 150,000 balance.`);

  const users = await User.find({});
  for (const u of users) {
    console.log(`Name: ${u.name}, Role: ${u.role}, Balance: ${u.balance}`);
  }

  await mongoose.disconnect();
}

update().catch(console.error);
