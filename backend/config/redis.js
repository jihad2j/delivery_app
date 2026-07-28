const Redis = require('ioredis');

let pubClient = null;
let subClient = null;
let redisClient = null;
let isRedisConnected = false;

const redisConfig = {
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: parseInt(process.env.REDIS_PORT, 10) || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  lazyConnect: true,
  maxRetriesPerRequest: 3,
  retryStrategy(times) {
    if (times > 3) {
      console.warn('[Redis] Connection retries exceeded. Operating in standalone in-memory fallback mode.');
      return null; // Stop retrying
    }
    return Math.min(times * 100, 2000);
  }
};

const getRedisUrl = () => process.env.REDIS_URL || null;

async function initRedis() {
  if (redisClient) return { isRedisConnected, redisClient, pubClient, subClient };

  try {
    const connectionOption = getRedisUrl() || redisConfig;
    redisClient = new Redis(connectionOption);
    pubClient = redisClient;
    subClient = redisClient.duplicate();

    redisClient.on('connect', () => {
      isRedisConnected = true;
      console.log('[Redis] Connected successfully for multi-server scaling.');
    });

    const errorHandler = (err) => {
      if (isRedisConnected) {
        console.error('[Redis] Error:', err.message);
      }
      isRedisConnected = false;
    };

    redisClient.on('error', errorHandler);
    subClient.on('error', errorHandler);

    await Promise.all([redisClient.connect(), subClient.connect()]);
    isRedisConnected = true;
  } catch (error) {
    console.warn('[Redis] Unable to connect to Redis server. Falling back to single-instance mode:', error.message);
    isRedisConnected = false;
  }

  return { isRedisConnected, redisClient, pubClient, subClient };
}

/**
 * Distributed Lock helper using Redis SET key value NX PX
 * Fallback to local in-memory lock map if Redis is not connected
 */
const localLocks = new Map();

async function acquireLock(lockKey, ttlMs = 5000) {
  const lockValue = `${Date.now()}_${Math.random()}`;

  if (isRedisConnected && redisClient) {
    try {
      const result = await redisClient.set(lockKey, lockValue, 'PX', ttlMs, 'NX');
      if (result === 'OK') return lockValue;
      return null;
    } catch (err) {
      console.warn('[Redis Lock] Error setting lock in Redis, falling back to local lock:', err.message);
    }
  }

  // Fallback in-memory locking
  const now = Date.now();
  const existingLock = localLocks.get(lockKey);
  if (existingLock && existingLock.expiresAt > now) {
    return null; // Lock held
  }

  localLocks.set(lockKey, { lockValue, expiresAt: now + ttlMs });
  setTimeout(() => {
    const current = localLocks.get(lockKey);
    if (current && current.lockValue === lockValue) {
      localLocks.delete(lockKey);
    }
  }, ttlMs);

  return lockValue;
}

async function releaseLock(lockKey, lockValue) {
  if (!lockValue) return;

  if (isRedisConnected && redisClient) {
    try {
      const luaScript = `
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      `;
      await redisClient.eval(luaScript, 1, lockKey, lockValue);
      return;
    } catch (err) {
      console.warn('[Redis Lock] Error releasing lock in Redis:', err.message);
    }
  }

  // Fallback in-memory unlock
  const current = localLocks.get(lockKey);
  if (current && current.lockValue === lockValue) {
    localLocks.delete(lockKey);
  }
}

module.exports = {
  initRedis,
  acquireLock,
  releaseLock,
  getIsRedisConnected: () => isRedisConnected,
  getPubSubClients: () => ({ pubClient, subClient })
};
