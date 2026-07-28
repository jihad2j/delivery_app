const Product = require('../models/model_Product');
const User = require('../models/model_User');

// انشاء منتج جديد
exports.createProduct = async (req, res) => {
  try {
    let restaurantUser;
    if (req.user.role === 'admin') {
      if (!req.body.restaurantId || !req.body.restaurantId.match(/^[0-9a-fA-F]{24}$/)) {
        return res.status(400).json({ message: 'Valid restaurantId is required for admin' });
      }
      restaurantUser = await User.findById(req.body.restaurantId);
    } else {
      restaurantUser = await User.findById(req.user.userId);
    }
    
    if (!restaurantUser || restaurantUser.role !== 'restaurant') {
      return res.status(404).json({ message: 'المطعم غير موجود' });
    }
    
    if (restaurantUser._id.toString() !== req.user.userId.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'غير مصرح' });
    }

    // انشاء المنتج - حماية Mass Assignment
    const { name, description, image, price, totalAmount, currency, category, isAvailable } = req.body;
    const product = new Product({
      name,
      description,
      image,
      price,
      totalAmount,
      currency,
      category,
      isAvailable,
      restaurantId: restaurantUser._id,
    });
    await product.save();
    await User.findByIdAndUpdate(restaurantUser._id, { $push: { 'restaurantInfo.menu': product._id } });
    
    res.status(201).json(product);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// الحصول على قائمة المنتجات
exports.getProducts = async (req, res) => {
  try {
    const { restaurantId, category, isAvailable } = req.query;
    const filter = {};
    if (restaurantId) filter.restaurantId = restaurantId;
    if (category) filter.category = category;
    if (isAvailable) filter.isAvailable = isAvailable === 'true';

    const products = await Product.find(filter);
    res.json(products);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// الحصول على منتج محدد
exports.getProductById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ message: 'المنتج غير موجود' });
    res.json(product);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// تحديث منتج محدد
exports.updateProduct = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ message: 'المنتج غير موجود' });

    const restaurantUser = await User.findById(product.restaurantId);
    if (restaurantUser._id.toString() !== req.user.userId.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'غير مصرح' });
    }

    // تحديث المنتج - حماية Mass Assignment
    const { name, description, image, price, totalAmount, currency, category, isAvailable } = req.body;
    const updates = {};
    if (name !== undefined) updates.name = name;
    if (description !== undefined) updates.description = description;
    if (image !== undefined) updates.image = image;
    if (price !== undefined) updates.price = price;
    if (totalAmount !== undefined) updates.totalAmount = totalAmount;
    if (currency !== undefined) updates.currency = currency;
    if (category !== undefined) updates.category = category;
    if (isAvailable !== undefined) updates.isAvailable = isAvailable;

    const updated = await Product.findByIdAndUpdate(req.params.id, updates, { returnDocument: 'after' });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// حذف منتج محدد
exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ message: 'Product not found' });

    const restaurantUser = await User.findById(product.restaurantId);
    if (restaurantUser._id.toString() !== req.user.userId.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Not authorized' });
    }

    await User.findByIdAndUpdate(product.restaurantId, { $pull: { 'restaurantInfo.menu': product._id } });
    await Product.findByIdAndDelete(req.params.id);
    res.json({ message: 'Product deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
