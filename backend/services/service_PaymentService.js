const mongoose = require('mongoose');
const Order = require('../models/model_Order');
const User = require('../models/model_User');
const Setting = require('../models/model_Setting');

async function executeDeliveryLogic(orderId, session = null) {
  const orderQuery = Order.findById(orderId);
  if (session) orderQuery.session(session);
  const order = await orderQuery;

  if (!order) throw new Error('Order not found');
  if (order.status !== 'delivered_pending') {
    throw new Error('الطلب ليس في حالة انتظار تأكيد العميل');
  }

  const custQuery = User.findById(order.customerId);
  if (session) custQuery.session(session);
  const customer = await custQuery;

  const restQuery = User.findById(order.restaurantId);
  if (session) restQuery.session(session);
  const restaurant = await restQuery;

  const driverQuery = User.findById(order.driverId);
  if (session) driverQuery.session(session);
  const driver = await driverQuery;

  const settQuery = Setting.findOne({ key: 'platformSettings' });
  if (session) settQuery.session(session);
  const settings = await settQuery;

  if (!customer || !restaurant || !driver) throw new Error('Customer, Restaurant, or Driver not found');

  // Calculate shares using admin settings
  const driverCommissionRate = settings?.value?.driverCommissionRate !== undefined 
    ? Number(settings.value.driverCommissionRate) 
    : 0.80; // 80% default
  const platformServiceFee = settings?.value?.serviceFee !== undefined 
    ? Number(settings.value.serviceFee) 
    : 0;

  const orderTotal = order.totalAmount;
  const deliveryFee = order.deliveryFee || 0;
  const grandTotal = orderTotal + deliveryFee;

  const restaurantShare = orderTotal;
  const driverShare = deliveryFee * driverCommissionRate;
  const platformShareFromDelivery = (deliveryFee * (1 - driverCommissionRate)) + platformServiceFee;

  const updateOpts = session ? { session } : {};

  if (order.paymentMethod === 'cash') {
    // التسديد كاش ليد الدليفري:
    // 1. يضاف مبلغ الطلب الكلي النظير لاستلام الكاش إلى محفظة مدفوعات الزبائن لدى الدليفري
    await User.findByIdAndUpdate(driver._id, { 
      $inc: { 
        customerPaymentsWallet: grandTotal,
        driverEarningsWallet: driverShare
      } 
    }, updateOpts);

    // 2. يضاف حصة المطعم إلى رصيده
    await User.findByIdAndUpdate(restaurant._id, { $inc: { balance: restaurantShare } }, updateOpts);

  } else {
    // الدفع عبر المحفظة (تم حجز الخصم مسبقاً من رصيد العميل عند إنشاء الطلب):
    // 1. يضاف مربح الدليفري إلى محفظة أرباح الدليفري
    await User.findByIdAndUpdate(driver._id, { 
      $inc: { driverEarningsWallet: driverShare } 
    }, updateOpts);

    // 2. يضاف حصة المطعم إلى رصيده
    await User.findByIdAndUpdate(restaurant._id, { $inc: { balance: restaurantShare } }, updateOpts);
  }

  // Update order status, shares and payment status
  order.status = 'delivered';
  order.paymentStatus = 'paid';
  order.platformCommission = platformShareFromDelivery;
  order.restaurantShare = restaurantShare;
  order.driverShare = driverShare;

  if (session) {
    await order.save({ session });
  } else {
    await order.save();
  }

  return { success: true, message: 'تم الدفع وتوزيع الأرباح بنجاح' };
}

async function processOrderDelivery(orderId) {
  let session;
  try {
    session = await mongoose.startSession();
    session.startTransaction();

    const result = await executeDeliveryLogic(orderId, session);

    await session.commitTransaction();
    session.endSession();
    return result;
  } catch (error) {
    if (session) {
      try {
        await session.abortTransaction();
      } catch (_) { }
      session.endSession();
    }

    // Check if the error is due to MongoDB standalone not supporting transactions
    const isNoReplicaSet = error.message.includes('replica set member') || 
                           error.message.includes('Transaction numbers') ||
                           error.message.includes('Transactions are not supported');
    if (isNoReplicaSet) {
      console.warn('[PaymentService] MongoDB standalone detected. Executing delivery settlement without transaction session.');
      try {
        return await executeDeliveryLogic(orderId, null);
      } catch (fallbackErr) {
        return { success: false, message: fallbackErr.message };
      }
    }

    return { success: false, message: error.message };
  }
}

module.exports = { processOrderDelivery, executeDeliveryLogic };
