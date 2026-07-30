
const Order = require('../models/model_Order');
const User = require('../models/model_User');
const Product = require('../models/model_Product');
const { findNearbyDrivers } = require('../services/service_DeliveryService');
const { getExchangeRate } = require('../services/service_CurrencyService');
const { processOrderDelivery } = require('../services/service_PaymentService');
const { acquireLock, releaseLock } = require('../config/redis');

// Store io instance globally
let io = null;
exports.setIoInstance = (ioInstance) => {
  io = ioInstance;
};

// ============================================================
// إنشاء طلب جديد
// ============================================================
exports.createOrder = async (req, res) => {
  try {
    const { restaurantId, items, deliveryAddress, paymentMethod, deliveryFee } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'الطلب يجب أن يحتوي على منتجات' });
    }

    let calculatedTotalAmount = 0;
    const verifiedItems = [];

    // التحقق من صحة المنتجات وحساب المجموع
    for (const item of items) {
      const dbProduct = await Product.findById(item.productId);
      if (!dbProduct) {
        return res.status(404).json({ message: `المنتج غير موجود: ${item.productId}` });
      }
      if (!dbProduct.isAvailable) {
        return res.status(400).json({ message: `المنتج غير متوفر حالياً: ${dbProduct.name}` });
      }
      if (dbProduct.restaurantId.toString() !== restaurantId.toString()) {
        return res.status(400).json({ message: `المنتج ${dbProduct.name} لا ينتمي لهذا المطعم` });
      }

      const quantity = parseInt(item.quantity, 10) || 1;
      calculatedTotalAmount += dbProduct.price * quantity;

      verifiedItems.push({
        productId: dbProduct._id,
        name: dbProduct.name,
        quantity: quantity,
        price: dbProduct.price
      });
    }

    const finalDeliveryFee = Number(deliveryFee) || 0;
    const grandTotal = Number(calculatedTotalAmount) + finalDeliveryFee;

    // التحقق من وجود طلب جاري للعميل
    const activeOrder = await Order.findOne({
      customerId: req.user.userId,
      status: { $nin: ['delivered', 'cancelled'] }
    });

    if (activeOrder) {
      return res.status(400).json({ message: 'لديك طلب جاري، لا يمكنك إنشاء طلب جديد حتى ينتهي طلبك الحالي' });
    }
    // نوع الدفع
    const finalPaymentMethod = paymentMethod || 'cash';

    // التحقق من رصيد العميل في حال الدفع بالمحفظة (حجز الرصيد)
    const customer = await User.findById(req.user.userId);
    if (!customer) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    if (finalPaymentMethod === 'wallet') {
      if (customer.balance < grandTotal) {
        return res.status(400).json({ message: 'لا يمكنك الشراء عن طريق المحفظة إلا إذا كان لديك رصيد كافٍ' });
      }
      // حجز الرصيد فوراً من العميل
      customer.balance -= grandTotal;
      await customer.save();
    }

    const orderData = {
      restaurantId,
      items: verifiedItems,
      totalAmount: calculatedTotalAmount,
      deliveryAddress,
      paymentMethod: finalPaymentMethod,
      deliveryFee: finalDeliveryFee,
      customerId: req.user.userId,
      currency: 'SYP',
      status: 'pending',
      paymentStatus: 'unpaid'
    };

    const order = new Order(orderData);
    await order.save();

    // Populate before emitting
    const populatedOrder = await Order.findById(order._id)
      .populate('restaurantId', 'name restaurantInfo.logo address')
      .populate('customerId', 'name phone');

    // إشعار المطعم والسائقين بالطلب الجديد مباشرة عبر الـ Socket
    if (io) {
      io.emit('newOrderAvailable', populatedOrder);
      io.emit('newOrderCreated', populatedOrder);
      io.emit('newOrderForRestaurant', populatedOrder);
    }

    res.status(201).json(populatedOrder);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// الحصول على قائمة الطلبات
// ============================================================
exports.getOrders = async (req, res) => {
  try {
    const { role } = req.user;
    const { status } = req.query;
    const filter = {};

    if (role === 'customer') filter.customerId = req.user.userId;
    else if (role === 'restaurant') {
      filter.restaurantId = req.user.userId;
    } else if (role === 'driver') {
      // السائق يرى الطلبات المتاحة (ready) + طلباته الخاصة
      if (status === 'available') {
        filter.status = 'ready';
        filter.driverId = { $exists: false };
      } else {
        filter.driverId = req.user.userId;
      }
    }

    if (status && status !== 'available') filter.status = status;

    const orders = await Order.find(filter)
      .populate('customerId', 'name phone')
      .populate('restaurantId', 'name restaurantInfo.logo address')
      .populate('driverId', 'name phone driverInfo')
      .sort({ createdAt: -1 })
      .limit(50);

    // أضف مقابل الدولار
    const rate = await getExchangeRate();
    const ordersWithUSD = orders.map(o => {
      const obj = o.toObject();
      obj.exchangeRate = rate;
      obj.totalAmountUSD = rate > 0 ? (obj.totalAmount / rate).toFixed(2) : null;
      obj.deliveryFeeUSD = rate > 0 ? (obj.deliveryFee / rate).toFixed(2) : null;
      return obj;
    });

    res.json(ordersWithUSD);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// الحصول على تفاصيل طلب محدد
// ============================================================
exports.getOrderById = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('customerId', 'name phone address')
      .populate('restaurantId', 'name restaurantInfo.logo address phone')
      .populate('driverId', 'name phone driverInfo');

    if (!order) return res.status(404).json({ message: 'Order not found' });

    const rate = await getExchangeRate();
    const obj = order.toObject();
    obj.exchangeRate = rate;
    obj.totalAmountUSD = rate > 0 ? (obj.totalAmount / rate).toFixed(2) : null;
    obj.deliveryFeeUSD = rate > 0 ? (obj.deliveryFee / rate).toFixed(2) : null;

    res.json(obj);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// تحديث حالة الطلب
// ============================================================
exports.updateOrderStatus = async (req, res) => {
  try {
    const { status, packagedPicture, receivedPicture } = req.body;
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });

    // إذا كانت الحالة المطلوبة مطابقة للحالة الحالية للطلب، فهذا يعني أننا نقوم فقط بتحديث الصور (مثل صورة الاستلام أو صورة التغليف)
    if (order.status === status) {
      const userRole = req.user.role;
      const userId = req.user.userId;
      const isAuthorized =
        (userRole === 'restaurant' && order.restaurantId.toString() === userId.toString()) ||
        (userRole === 'driver' && order.driverId?.toString() === userId.toString()) ||
        (userRole === 'customer' && order.customerId.toString() === userId.toString()) ||
        userRole === 'admin';

      if (!isAuthorized) {
        return res.status(403).json({ message: 'غير مصرح لك بتحديث هذا الطلب' });
      }

      if (packagedPicture !== undefined) order.packagedPicture = packagedPicture;
      if (receivedPicture !== undefined) order.receivedPicture = receivedPicture;
      await order.save();

      const populated = await Order.findById(order._id)
        .populate('customerId', 'name phone address')
        .populate('restaurantId', 'name restaurantInfo.logo address phone')
        .populate('driverId', 'name phone driverInfo');

      return res.json(populated);
    }

    // تقييد الصلاحيات حسب دور المستخدم
    const userRole = req.user.role;
    const userId = req.user.userId;

    if (userRole === 'restaurant') {
      if (order.restaurantId.toString() !== userId.toString()) {
        return res.status(403).json({ message: 'غير مصرح لك بتعديل هذا الطلب' });
      }
      const allowed = ['restaurant_accepted', 'preparing', 'ready', 'cancelled'];
      if (!allowed.includes(status)) {
        return res.status(403).json({ message: 'لا يمكن للمطعم تغيير حالة الطلب إلى ' + status });
      }
    } else if (userRole === 'driver') {
      if (order.driverId?.toString() !== userId.toString()) {
        return res.status(403).json({ message: 'غير مصرح لك بتعديل هذا الطلب' });
      }
      const allowed = ['onTheWay', 'delivered_pending'];
      if (!allowed.includes(status)) {
        return res.status(403).json({ message: 'لا يمكن للسائق تغيير حالة الطلب إلى ' + status });
      }
    } else if (userRole === 'customer') {
      // لا يمكن للعميل إلغاء الطلب إلا إذا كان في حالة pending
      if (status === 'cancelled' && order.status === 'pending') {
        if (order.customerId.toString() !== userId.toString()) {
          return res.status(403).json({ message: 'غير مصرح لك بإلغاء هذا الطلب' });
        }
      } else {
        return res.status(403).json({ message: 'العميل لا يمكنه تغيير حالة الطلب' });
      }
    } else if (userRole !== 'admin') {
      return res.status(403).json({ message: 'غير مصرح لك' });
    }

    const validTransitions = {
      pending: ['restaurant_accepted', 'cancelled'],
      restaurant_accepted: ['preparing', 'cancelled'],
      preparing: ['ready'],
      ready: ['delivery_accepted'],
      delivery_accepted: ['onTheWay'],
      onTheWay: ['delivered_pending'],
      delivered_pending: ['delivered', 'cancelled'],
      delivered: [],
      cancelled: []
    };

    if (!validTransitions[order.status]?.includes(status)) {
      return res.status(400).json({
        message: `لا يمكن الانتقال من ${order.status} إلى ${status}`
      });
    }

    // إعادة حجز الرصيد للعميل إذا تم إلغاء الطلب وكان مدفوعاً عبر المحفظة
    if (status === 'cancelled' && order.paymentMethod === 'wallet' && order.paymentStatus !== 'paid' && order.status !== 'cancelled') {
      const grandTotal = (order.totalAmount || 0) + (order.deliveryFee || 0);
      await User.findByIdAndUpdate(order.customerId, { $inc: { balance: grandTotal } });
    }

    order.status = status;
    if (packagedPicture !== undefined) order.packagedPicture = packagedPicture;
    if (receivedPicture !== undefined) order.receivedPicture = receivedPicture;
    await order.save();

    const populated = await Order.findById(order._id)
      .populate('customerId', 'name phone address')
      .populate('restaurantId', 'name restaurantInfo.logo address phone')
      .populate('driverId', 'name phone driverInfo');

    // إرسال إشعار عبر الـ Socket
    if (io) {
      io.to(order._id.toString()).emit('orderStatus', {
        orderId: order._id,
        status,
        updatedBy: req.user.role,
        timestamp: new Date()
      });
      io.emit('orderStatusChanged', populated);

      // إعلام السائقين بوجود طلب جاهز للتوصيل
      if (status === 'ready') {
        io.emit('newOrderAvailable', populated);
      }
    }

    res.json(populated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// السائق يقبل الطلب
// ============================================================
exports.acceptOrderByDriver = async (req, res) => {
  const lockKey = `lock:order:accept:${req.params.id}`;
  const lockValue = await acquireLock(lockKey, 5000);

  if (!lockValue) {
    return res.status(409).json({ message: 'جاري معالجة هذا الطلب من قبل سائق آخر، يرجى المحاولة مرة أخرى' });
  }

  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });
    if (order.driverId) return res.status(400).json({ message: 'تم قبول هذا الطلب من سائق آخر' });

    // التحقق من أن السائق ليس لديه طلب نشط حالياً
    const activeOrder = await Order.findOne({
      driverId: req.user.userId,
      status: { $in: ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'] }
    });
    if (activeOrder) {
      return res.status(400).json({ message: 'لديك طلب نشط بالفعل، لا يمكنك قبول طلب آخر حتى تنهيه' });
    }

    order.driverId = req.user.userId;
    order.status = 'delivery_accepted';
    await order.save();

    const populated = await Order.findById(order._id)
      .populate('restaurantId', 'name restaurantInfo.logo address')
      .populate('customerId', 'name phone address');

    // Notify all parties
    if (io) {
      io.to(order._id.toString()).emit('orderStatus', {
        orderId: order._id,
        status: 'delivery_accepted',
        driverId: req.user.userId,
        timestamp: new Date()
      });
    }

    res.json(populated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  } finally {
    await releaseLock(lockKey, lockValue);
  }
};

// ============================================================
// السائق يرفض الطلب (يُرجعه للقائمة)
// ============================================================
exports.rejectOrderByDriver = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });
    // Just confirm rejection - order stays available
    res.json({ message: 'تم رفض الطلب' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// تأكيد التوصيل
// ============================================================

exports.confirmDelivery = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });
    if (order.driverId?.toString() !== req.user.userId.toString()) {
      return res.status(403).json({ message: 'غير مصرح' });
    }

    if (order.status !== 'onTheWay') {
      return res.status(400).json({ message: 'الطلب ليس في حالة تسمح بالتوصيل (يجب أن يكون في الطريق)' });
    }

    order.status = 'delivered_pending';
    await order.save();

    const updatedOrder = await Order.findById(order._id)
      .populate('customerId', 'name phone address')
      .populate('restaurantId', 'name restaurantInfo.logo address phone')
      .populate('driverId', 'name phone driverInfo');

    if (io) {
      io.to(order._id.toString()).emit('orderStatus', {
        orderId: order._id,
        status: 'delivered_pending',
        updatedBy: 'driver',
        timestamp: new Date()
      });
    }

    res.json({ message: 'تم تحديث حالة الطلب وبانتظار تأكيد العميل', order: updatedOrder });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.customerConfirmDelivery = async (req, res) => {
  try {
    const { receivedPicture } = req.body;
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });
    if (order.customerId.toString() !== req.user.userId.toString()) {
      return res.status(403).json({ message: 'غير مصرح' });
    }

    if (order.status !== 'delivered_pending') {
      return res.status(400).json({ message: 'الطلب ليس في حالة تسمح بتأكيد الاستلام' });
    }

    if (receivedPicture) {
      order.receivedPicture = receivedPicture;
      await order.save();
    }

    const result = await processOrderDelivery(order._id);
    if (!result.success) {
      return res.status(400).json({ message: result.message });
    }

    const updatedOrder = await Order.findById(order._id)
      .populate('customerId', 'name phone address')
      .populate('restaurantId', 'name restaurantInfo.logo address phone')
      .populate('driverId', 'name phone driverInfo');

    if (io) {
      const payload = {
        orderId: order._id,
        status: 'delivered',
        updatedBy: 'customer',
        deliveryFee: updatedOrder.deliveryFee,
        timestamp: new Date()
      };
      io.to(order._id.toString()).emit('orderStatus', payload);
      io.to(order._id.toString()).emit('deliveryConfirmed', payload);
      io.emit('orderStatus', payload);
      io.emit('deliveryConfirmed', payload);
    }

    res.json({ message: 'تم تأكيد استلام الطلب بنجاح وتوزيع الأرباح', order: updatedOrder });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ============================================================
// الإدمن يعين سائق لطلب
// ============================================================
exports.assignDriver = async (req, res) => {
  try {
    const { driverId } = req.body;
    if (!driverId) {
      return res.status(400).json({ message: 'يجب توفير معرف السائق' });
    }

    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ message: 'الطلب غير موجود' });

    const driver = await User.findOne({ _id: driverId, role: 'driver' });
    if (!driver) {
      return res.status(404).json({ message: 'السائق غير موجود' });
    }

    const activeOrder = await Order.findOne({
      driverId: driverId,
      status: { $in: ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'] }
    });
    if (activeOrder) {
      return res.status(400).json({ message: 'السائق لديه طلب نشط بالفعل' });
    }

    order.driverId = driverId;
    order.status = 'delivery_accepted';
    await order.save();

    const populated = await Order.findById(order._id)
      .populate('restaurantId', 'name restaurantInfo.logo address')
      .populate('customerId', 'name phone address')
      .populate('driverId', 'name phone driverInfo');

    if (io) {
      io.to(order._id.toString()).emit('orderStatus', {
        orderId: order._id,
        status: 'delivery_accepted',
        driverId: driverId,
        updatedBy: 'admin',
        timestamp: new Date()
      });
    }

    res.json(populated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
