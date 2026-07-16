
const User = require('../models/model_User');
const Product = require('../models/model_Product');
// انشاء مطعم جديد
exports.createRestaurant = async (req, res) => {
  try {
    const { name, description, logo, phone, email, address, status, minOrderAmount, deliveryFee } = req.body;
    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    
    user.restaurantInfo = {
      description,
      logo: logo || 'https://via.placeholder.com/150',
      status: status || 'open',
      minOrderAmount: minOrderAmount || 0,
      deliveryFee: deliveryFee || 0,
      menu: user.restaurantInfo ? user.restaurantInfo.menu : []
    };
    if (name) user.name = name;
    if (phone) user.phone = phone;
    if (email) user.email = email;
    if (address) user.address = address;
    user.role = 'restaurant';
    
    await user.save();
    res.status(201).json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// الحصول على قائمة المطعمين
exports.getRestaurants = async (req, res) => {
  try {
    const { status, city } = req.query;
    const filter = { role: 'restaurant' };
    if (status) filter['restaurantInfo.status'] = status;
    if (city) filter['address.city'] = city;

    const restaurants = await User.find(filter).populate('restaurantInfo.menu');
    res.json(restaurants);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// الحصول على مطعم محدد
exports.getRestaurantById = async (req, res) => {
  try {
    const restaurant = await User.findOne({ _id: req.params.id, role: 'restaurant' }).populate('restaurantInfo.menu');
    if (!restaurant) return res.status(404).json({ message: 'Restaurant not found' });
    res.json(restaurant);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// تحديث مطعم محدد
exports.updateRestaurant = async (req, res) => {
  try {
    const restaurant = await User.findOne({ _id: req.params.id, role: 'restaurant' });
    if (!restaurant) return res.status(404).json({ message: 'Restaurant not found' });
    if (restaurant._id.toString() !== req.user.userId.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Not authorized' });
    }
    
    // Construct updates for User and restaurantInfo (protecting against Mass Assignment)
    const updates = req.body;
    const mappedUpdates = {};
    
    if (updates.name !== undefined) mappedUpdates.name = updates.name;
    if (updates.phone !== undefined) mappedUpdates.phone = updates.phone;
    if (updates.email !== undefined) mappedUpdates.email = updates.email;
    if (updates.address !== undefined) mappedUpdates.address = updates.address;

    const restaurantFields = ['description', 'logo', 'status', 'minOrderAmount', 'deliveryFee', 'cuisineType', 'firebaseNotifications'];
    for (const key of restaurantFields) {
      if (updates[key] !== undefined) {
        mappedUpdates[`restaurantInfo.${key}`] = updates[key];
      }
    }

    const updated = await User.findByIdAndUpdate(req.params.id, { $set: mappedUpdates }, { new: true });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// الحصول على قائمة المطعمين محددة

exports.getNearbyRestaurants = async (req, res) => {
  try {
    const { lng, lat, radius = 5000 } = req.query;
    const restaurants = await User.find({
      role: 'restaurant',
      'address.location': {
        $near: {
          $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
          $maxDistance: parseInt(radius)
        }
      },
      'restaurantInfo.status': 'open'
    });
    res.json(restaurants);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
