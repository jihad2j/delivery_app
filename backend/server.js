
require('dotenv').config();
const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const socketIo = require('socket.io');
const cors = require('cors');
const connectDB = require('./config/db');
const jwt = require('jsonwebtoken');
const {
  findNearbyDrivers,
  trackDriverLocation
} = require('./services/service_DeliveryService');
const { processOrderDelivery } = require('./services/service_PaymentService');

const authRoutes = require('./routes/route_authRoutes');
const restaurantRoutes = require('./routes/route_restaurantRoutes');
const productRoutes = require('./routes/route_productRoutes');
const orderRoutes = require('./routes/route_orderRoutes');
const adminRoutes = require('./routes/route_adminRoutes');
const promoRoutes = require('./routes/route_promoRoutes');
const orderController = require('./controllers/controller_OrderController');

const { initRedis } = require('./config/redis');
const { createAdapter } = require('@socket.io/redis-adapter');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
    methods: ['GET', 'POST']
  }
});

// Initialize Redis & Socket.IO Redis Adapter
initRedis().then(({ isRedisConnected, pubClient, subClient }) => {
  if (isRedisConnected && pubClient && subClient) {
    io.adapter(createAdapter(pubClient, subClient));
    console.log('[Socket.IO] Redis Adapter initialized for multi-server scaling.');
  }
}).catch(err => {
  console.warn('[Redis] Adapter setup skipped:', err.message);
});

const { getIsRedisConnected } = require('./config/redis');
const { authRateLimiter, apiRateLimiter } = require('./middleware/rateLimiter');
const errorHandler = require('./middleware/errorHandler');

const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
};
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

connectDB();

// Apply General Rate Limiter to /api
app.use('/api', apiRateLimiter);

app.get('/', (req, res) => {
  res.json({ message: 'Delivery App API is running!', version: '1.0.0' });
});

// Comprehensive Health & Monitoring Endpoint
app.get('/api/health', (req, res) => {
  const mongooseState = mongoose.connection.readyState;
  const mongoStatusMap = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting'
  };

  const isRedisConnected = getIsRedisConnected();
  const memoryUsage = process.memoryUsage();

  res.json({
    status: 'UP',
    timestamp: new Date(),
    uptimeSeconds: Math.floor(process.uptime()),
    database: {
      provider: 'MongoDB',
      status: mongoStatusMap[mongooseState] || 'unknown'
    },
    cache: {
      provider: 'Redis',
      status: isRedisConnected ? 'connected' : 'standalone_fallback_mode'
    },
    system: {
      memoryUsedMB: (memoryUsage.heapUsed / 1024 / 1024).toFixed(2),
      totalMemoryAllocatedMB: (memoryUsage.heapTotal / 1024 / 1024).toFixed(2),
      nodeVersion: process.version
    }
  });
});

// Attach io to req for broadcast and other features
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Apply specific rate limiter to Auth routes
app.use('/api/auth/login', authRateLimiter);
app.use('/api/auth/register', authRateLimiter);

app.use('/api/auth', authRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/promos', promoRoutes);

// Global Error Handling Middleware
app.use(errorHandler);

// Set io instance for order controller
orderController.setIoInstance(io);

const connectedDrivers = new Map();

io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error('Authentication required'));

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.user = decoded;
    next();
  } catch (err) {
    next(new Error('Invalid token'));
  }
});

io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id} (${socket.user.role})`);

  socket.on('joinOrderRoom', (orderId) => {
    socket.join(orderId);
    console.log(`${socket.user.role} ${socket.id} joined room: ${orderId}`);
  });

  socket.on('leaveOrderRoom', (orderId) => {
    socket.leave(orderId);
    console.log(`${socket.user.role} ${socket.id} left room: ${orderId}`);
  });
  // تحديث موقع التوصيل
  socket.on('driverLocationUpdate', async (data) => {
    const { orderId, location } = data;
    if (socket.user.role !== 'driver') return;
    io.to(orderId).emit('driverLocation', { orderId, location, timestamp: new Date() });
    try {
      await trackDriverLocation(orderId, socket.user.userId, location);
    } catch (err) {
      console.error('Error saving driver location:', err.message);
    }
  });
  // تحديث حالة التوصيل
  socket.on('orderStatusUpdate', (data) => {
    const { orderId, status } = data;
    io.to(orderId).emit('orderStatus', { status, updatedBy: socket.user.role, timestamp: new Date() });
  });
  // تحديث حالة التوصيل
  socket.on('driverAvailable', async (data) => {
    if (socket.user.role !== 'driver') return;
    const { available, location } = data;
    connectedDrivers.set(socket.user.userId, {
      socketId: socket.id,
      available,
      location
    });
    io.emit('driverAvailability', { driverId: socket.user.userId, available });
  });
  // البحث عن توصيلين
  socket.on('findDrivers', async (data) => {
    const { restaurantLocation } = data;
    const drivers = await findNearbyDrivers(restaurantLocation);
    socket.emit('nearbyDrivers', drivers);
  });
  //رسال رسالة
  socket.on('sendMessage', (data) => {
    const { orderId, message, senderRole } = data;
    io.to(orderId).emit('newMessage', {
      sender: socket.user.userId,
      senderRole,
      message,
      timestamp: new Date()
    });
  });

  // تغلاق الاتصال
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
    connectedDrivers.delete(socket.user.userId);
    io.emit('driverAvailability', { driverId: socket.user.userId, available: false });
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
