function errorHandler(err, req, res, next) {
  console.error('[Global Error Handler]:', err);

  // Mongoose Validation Error
  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map((e) => e.message);
    return res.status(400).json({
      message: 'خطأ في البيانات المدخلة',
      errors
    });
  }

  // Mongoose Cast Error (Invalid ObjectId)
  if (err.name === 'CastError') {
    return res.status(400).json({
      message: `معرف غير صالح: ${err.value}`
    });
  }

  // Mongoose Duplicate Key Error
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue || {})[0] || 'الحقل';
    return res.status(400).json({
      message: `قيمة مُكررة لحقل ${field}، يرجى إدخال قيمة أخرى`
    });
  }

  // JSON Web Token Errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ message: 'رمز المصادقة غير صالح' });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ message: 'انتهت صلاحية رمز المصادقة، يرجى إعادة الدخول' });
  }

  // Generic Internal Server Error
  const statusCode = res.statusCode !== 200 ? res.statusCode : 500;
  res.status(statusCode).json({
    message: err.message || 'حدث خطأ غير متوقع في السيرفر',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
}

module.exports = errorHandler;
