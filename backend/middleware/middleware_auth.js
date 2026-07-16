
const jwt = require('jsonwebtoken');
const User = require('../models/model_User');
// تحقق من تحقق المستخدم
// تحقق من صلاحية المستخدم
// تحقق من حالة المستخدم
const authenticate = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'No token provided' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId);
    if (!user || user.status !== 'active') {
      return res.status(403).json({ message: 'User not found or inactive' });
    }
    req.user = { userId: user._id, role: user.role };
    next();
  } catch (err) {
    return res.status(403).json({ message: 'Invalid or expired token' });
  }
};

const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'Insufficient permissions' });
    }
    next();
  };
};

module.exports = { authenticate, authorize };
