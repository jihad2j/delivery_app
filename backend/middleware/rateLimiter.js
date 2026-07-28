const rateLimit = require('express-rate-limit');

// Rate limiter for Authentication endpoints (login, register)
const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // limit each IP to 15 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'تم تجاوز عدد محاولات الدخول المسموح بها، يرجى الانتظار 15 دقيقة قبل المحاولة مرة أخرى'
  }
});

// General Rate limiter for API routes
const apiRateLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 120, // limit each IP to 120 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message: 'تم تجاوز معدل الطلبات المسموح به، يرجى الانتظار دقيقة واحدة'
  }
});

module.exports = {
  authRateLimiter,
  apiRateLimiter
};
