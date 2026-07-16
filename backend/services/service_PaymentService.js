const mongoose = require('mongoose');
const Order = require('../models/model_Order');
const User = require('../models/model_User');
const Setting = require('../models/model_Setting');

async function executeDeliveryLogic(orderId, session) {
  const order = await Order.findById(orderId).session(session);
  if (!order) throw new Error('Order not found');
  if (order.status !== 'delivered_pending') {
    throw new Error('الطلب ليس في حالة انتظار تأكيد العميل');
  }

  const customer = await User.findById(order.customerId).session(session);
  const restaurant = await User.findById(order.restaurantId).session(session);
  const driver = await User.findById(order.driverId).session(session);
  const settings = await Setting.findOne({ key: 'platformSettings' }).session(session);

  if (!customer || !restaurant || !driver) throw new Error('Customer, Restaurant, or Driver not found');

  // Calculate shares
  const platformCommissionRate = settings?.value?.platformCommissionRate || 0.10;
  const driverCommissionRate = settings?.value?.driverCommissionRate || 0.80;
  const orderTotal = order.totalAmount;
  const deliveryFee = order.deliveryFee || 0;
  const grandTotal = orderTotal + deliveryFee;

  const restaurantShare = orderTotal;
  const platformShareFromDelivery = deliveryFee * (1 - driverCommissionRate);
  const driverShare = deliveryFee * driverCommissionRate;

  // Check balance
  if (customer.balance < grandTotal) {
    throw new Error('رصيد العميل غير كافٍ لإتمام عملية الدفع');
  }

  // Deduct from customer
  await User.findByIdAndUpdate(customer._id, { $inc: { balance: -grandTotal } }, { session });

  // Add to restaurant and driver
  await User.findByIdAndUpdate(restaurant._id, { $inc: { balance: restaurantShare } }, { session });
  await User.findByIdAndUpdate(driver._id, { $inc: { balance: driverShare } }, { session });

  // Update order status, shares and payment status
  order.status = 'delivered';
  order.paymentStatus = 'paid';
  order.platformCommission = platformShareFromDelivery;
  order.restaurantShare = restaurantShare;
  order.driverShare = driverShare;
  await order.save({ session });

  return { success: true, message: 'تم الدفع وتوزيع الأرباح بنجاح' };
}
/*
async function executeDeliveryLogicWithManualRollback(orderId) {
  let rolledBack = false;
  let customerBalanceDeducted = 0;
  let restaurantBalanceAdded = 0;
  let driverBalanceAdded = 0;
  let originalOrderStatus = null;
  let orderSaved = false;

  let order, customer, restaurant, driver;

  try {
    order = await Order.findById(orderId);
    if (!order) throw new Error('Order not found');
    if (order.status !== 'delivered_pending') {
      throw new Error('الطلب ليس في حالة انتظار تأكيد العميل');
    }

    originalOrderStatus = order.status;

    customer = await User.findById(order.customerId);
    restaurant = await User.findById(order.restaurantId);
    driver = await User.findById(order.driverId);
    const settings = await Setting.findOne({ key: 'platformSettings' });

    if (!customer || !restaurant || !driver) throw new Error('Customer, Restaurant, or Driver not found');

    const platformCommissionRate = settings?.value?.platformCommissionRate || 0.10;
    const driverCommissionRate = settings?.value?.driverCommissionRate || 0.80;
    const orderTotal = order.totalAmount;
    const deliveryFee = order.deliveryFee || 0;
    const grandTotal = orderTotal + deliveryFee;

    if (customer.balance < grandTotal) {
      throw new Error('رصيد العميل غير كافٍ لإتمام عملية الدفع');
    }

    const restaurantShare = orderTotal;
    const platformShareFromDelivery = deliveryFee * (1 - driverCommissionRate);
    const driverShare = deliveryFee * driverCommissionRate;

    // Deduct from customer
    await User.findByIdAndUpdate(customer._id, { $inc: { balance: -grandTotal } });
    customerBalanceDeducted = grandTotal;

    // Credit restaurant
    await User.findByIdAndUpdate(restaurant._id, { $inc: { balance: restaurantShare } });
    restaurantBalanceAdded = restaurantShare;

    // Credit driver
    await User.findByIdAndUpdate(driver._id, { $inc: { balance: driverShare } });
    driverBalanceAdded = driverShare;

    // Update Order
    order.status = 'delivered';
    order.paymentStatus = 'paid';
    order.platformCommission = platformShareFromDelivery;
    order.restaurantShare = restaurantShare;
    order.driverShare = driverShare;
    await order.save();
    orderSaved = true;

    return { success: true, message: 'تم الدفع وتوزيع الأرباح بنجاح' };
  } catch (error) {
    console.error('Error during payment execution, starting manual rollback:', error.message);
    try {
      if (customerBalanceDeducted !== 0 && customer) {
        await User.findByIdAndUpdate(customer._id, { $inc: { balance: customerBalanceDeducted } });
      }
      if (restaurantBalanceAdded !== 0 && restaurant) {
        await User.findByIdAndUpdate(restaurant._id, { $inc: { balance: -restaurantBalanceAdded } });
      }
      if (driverBalanceAdded !== 0 && driver) {
        await User.findByIdAndUpdate(driver._id, { $inc: { balance: -driverBalanceAdded } });
      }
      if (order && originalOrderStatus && !orderSaved) {
        order.status = originalOrderStatus;
        await order.save();
      }
      rolledBack = true;
    } catch (rollbackError) {
      console.error('CRITICAL: Manual rollback failed!', rollbackError.message);
    }

    return {
      success: false,
      message: `Failed: ${error.message}.${rolledBack ? ' Changes were rolled back.' : ' CRITICAL: Rollback failed!'}`
    };
  }
}
*/
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
    const isNoReplicaSet = error.message.includes('replica set member') || error.message.includes('Transaction numbers');
    if (isNoReplicaSet) {
      console.warn('MongoDB standalone detected. Falling back to non-transactional execution with manual rollback.');
      //return await executeDeliveryLogicWithManualRollback(orderId);
    }

    return { success: false, message: error.message };
  }
}

module.exports = { processOrderDelivery };
