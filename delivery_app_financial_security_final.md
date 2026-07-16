# أنظمة مالية وأمنية متقدمة لتطبيق التوصيل

تعتبر العمليات المالية وأمان البيانات من أهم الجوانب في أي تطبيق توصيل. هذا المستند يقدم مقترحاً مفصلاً لضمان موثوقية هذه الأنظمة، بما في ذلك نظام تحويل الأموال، المصادقة والتشفير، وتوزيع الأرباح، بالإضافة إلى مراقبة وقت التوصيل.

## 1. نظام التحويلات المالية الموثوق (Robust Transaction System)

لضمان عدم ضياع أي مبلغ مالي حتى في حال انقطاع الخادم أو حدوث أخطاء أثناء عملية التحويل، سنعتمد على **MongoDB Transactions** (العمليات المتعددة المستندات) في Node.js. هذا يضمن أن جميع التحديثات المتعلقة بطلب معين تتم كخطوة واحدة ذرية (Atomic)، إما أن تنجح كلها أو تفشل كلها.

### أ. هيكلية البيانات الإضافية المطلوبة

لإدارة الأرصدة، سنحتاج إلى تحديثات بسيطة في `Users` Collection وإضافة `PlatformAccount`:

*   **`Users` Collection:**
    *   `balance`: Number (الرصيد الحالي للمستخدم، للسائقين والمطاعم). القيمة الافتراضية 0.
*   **`Settings` Collection:**
    *   `platformCommissionRate`: Number (نسبة عمولة المنصة، يحددها المدير). القيمة الافتراضية 0.10 (10%).
    *   `driverCommissionRate`: Number (نسبة عمولة السائق، يحددها المدير). القيمة الافتراضية 0.80 (80% من رسوم التوصيل).

### ب. آلية التحويل المالي (بعد تأكيد العميل استلام الطلب)

عندما يضغط العميل على زر "تم استلام الطلب"، يتم تشغيل عملية تحويل معقدة على الخادم (Node.js) تضمن توزيع الأموال بشكل صحيح. هذه العملية يجب أن تتم ضمن **MongoDB Transaction**.

1.  **بدء الجلسة والعملية (Session & Transaction):** يتم إنشاء جلسة MongoDB وبدء عملية متعددة المستندات.
2.  **التحقق من حالة الطلب:** التأكد من أن الطلب في حالة تسمح بالتحويل (مثلاً `onTheWay`).
3.  **حساب النسب:** يتم حساب حصة المطعم، حصة السائق، وحصة المنصة بناءً على إجمالي مبلغ الطلب ورسوم التوصيل والنسب المحددة من قبل المدير.
4.  **تحديث أرصدة الأطراف:**
    *   زيادة رصيد المطعم (`balance`) بقيمة حصته.
    *   زيادة رصيد السائق (`balance`) بقيمة حصته (رسوم التوصيل - عمولة المنصة على رسوم التوصيل).
    *   تسجيل عمولة المنصة.
5.  **تحديث حالة الطلب:** تغيير حالة الطلب إلى `delivered`.
6.  **الالتزام بالعملية (Commit Transaction):** إذا نجحت جميع الخطوات، يتم الالتزام بالعملية وتصبح التغييرات دائمة.
7.  **التراجع عن العملية (Abort Transaction):** إذا فشلت أي خطوة لأي سبب (مثل انقطاع الاتصال، خطأ في الحسابات)، يتم التراجع عن العملية بأكملها، وتعود قاعدة البيانات إلى حالتها الأصلية قبل بدء العملية، مما يضمن عدم ضياع أي أموال أو حدوث تناقض في البيانات.

### ج. مثال على سكريبت Node.js لعملية التحويل

```javascript
const mongoose = require("mongoose");
const Order = require("./models/Order");
const User = require("./models/User");
const Setting = require("./models/Setting"); // For platformCommissionRate, driverCommissionRate

// تأكد من أنك متصل بـ MongoDB قبل استدعاء هذه الوظيفة
// mongoose.connect("mongodb://localhost:27017/delivery_app", { useNewUrlParser: true, useUnifiedTopology: true });

async function processOrderDelivery(orderId) {
    const session = await mongoose.startSession();
    session.startTransaction();

    try {
        const order = await Order.findById(orderId).session(session);
        if (!order) {
            throw new Error("Order not found.");
        }
        if (order.status !== "onTheWay") {
            throw new Error("Order is not in a deliverable state.");
        }

        const restaurant = await User.findById(order.restaurantId).session(session);
        const driver = await User.findById(order.driverId).session(session);
        const settings = await Setting.findOne({ key: "platformSettings" }).session(session); // Assume one settings document

        if (!restaurant || !driver || !settings) {
            throw new Error("Required entities (restaurant, driver, settings) not found.");
        }

        const platformCommissionRate = settings.value.platformCommissionRate || 0.10; // 10%
        const driverCommissionRate = settings.value.driverCommissionRate || 0.80; // 80% of delivery fee

        const orderTotal = order.totalAmount; // إجمالي مبلغ الطلب (سعر الوجبات)
        const deliveryFee = order.deliveryFee; // رسوم التوصيل

        // حساب حصص الأطراف
        const restaurantShare = orderTotal; // المطعم يحصل على إجمالي سعر الوجبات
        const platformShareFromDelivery = deliveryFee * (1 - driverCommissionRate); // عمولة المنصة من رسوم التوصيل
        const driverShare = deliveryFee * driverCommissionRate; // حصة السائق من رسوم التوصيل

        // تحديث أرصدة المطعم والسائق
        await User.findByIdAndUpdate(restaurant._id, { $inc: { balance: restaurantShare } }, { session });
        await User.findByIdAndUpdate(driver._id, { $inc: { balance: driverShare } }, { session });

        // تحديث حالة الطلب وتسجيل عمولة المنصة
        order.status = "delivered";
        order.platformCommission = platformShareFromDelivery; // يمكن إضافة هذا الحقل لـ Order Schema
        order.restaurantShare = restaurantShare; // يمكن إضافة هذا الحقل لـ Order Schema
        order.driverShare = driverShare; // يمكن إضافة هذا الحقل لـ Order Schema
        await order.save({ session });

        await session.commitTransaction();
        session.endSession();
        console.log(`Order ${orderId} successfully processed and funds distributed.`);
        return { success: true, message: "Order processed successfully." };

    } catch (error) {
        await session.abortTransaction();
        session.endSession();
        console.error(`Transaction for order ${orderId} aborted:`, error.message);
        return { success: false, message: `Transaction failed: ${error.message}` };
    }
}

// مثال على كيفية استدعاء الوظيفة:
// processOrderDelivery("someOrderId").then(result => console.log(result));
```

**شرح السكريبت:**
*   يستخدم `mongoose.startSession()` و `session.startTransaction()` لبدء عملية MongoDB. هذا يضمن أن جميع عمليات القراءة والكتابة داخل `try` بلوك تتم كجزء من عملية واحدة.
*   إذا حدث أي خطأ داخل `try` بلوك، يتم استدعاء `session.abortTransaction()` للتراجع عن جميع التغييرات التي تمت داخل العملية، مما يحافظ على اتساق البيانات.
*   إذا نجحت جميع العمليات، يتم استدعاء `session.commitTransaction()` لجعل التغييرات دائمة.
*   **ملاحظة:** يجب أن تكون `Order`, `User`, و `Setting` نماذج Mongoose معرفة مسبقاً. كما يجب إضافة حقول `balance` في `User` و `platformCommissionRate`, `driverCommissionRate` في `Setting` (أو أي مكان مناسب لإعدادات المدير) كما هو موضح في هيكلية البيانات الإضافية.

### د. تحديد السعر والنسب من قبل المدير

يجب أن توفر واجهة الإدارة (Admin Panel) القدرة للمدير على تحديد وتعديل النسب التالية:

*   **`platformCommissionRate`:** نسبة عمولة المنصة من إجمالي رسوم التوصيل (مثلاً 20%).
*   **`driverCommissionRate`:** نسبة حصة السائق من إجمالي رسوم التوصيل (مثلاً 80%).
*   **`currencyExchangeRate`:** سعر صرف العملة (دولار مقابل ليرة سورية).

يتم تخزين هذه القيم في `Settings` Collection في MongoDB، ويتم جلبها واستخدامها في السكريبتات الخلفية للحسابات المالية. هذا يضمن مرونة كاملة للمدير في تعديل هذه النسب دون الحاجة لتعديل الكود البرمجي.

## 2. نظام المصادقة والتشفير (Authentication & Encryption)

لضمان أمان الاتصال والبيانات بين السيرفر والتطبيق، يجب اتباع أفضل الممارسات في المصادقة والتشفير.

### أ. المصادقة (Authentication)

سنستخدم **JSON Web Tokens (JWT)** للمصادقة، وهي طريقة آمنة وفعالة لإدارة جلسات المستخدمين.

1.  **تسجيل الدخول:**
    *   يرسل المستخدم (عميل، سائق، مطعم، مدير) بيانات الاعتماد (البريد الإلكتروني/رقم الهاتف وكلمة المرور) إلى الخادم عبر اتصال HTTPS آمن.
    *   يقوم الخادم بالتحقق من صحة بيانات الاعتماد (بعد فك تشفير كلمة المرور المخزنة).
    *   إذا كانت البيانات صحيحة، يقوم الخادم بإنشاء JWT يحتوي على معرف المستخدم ودوره (role) وتاريخ انتهاء الصلاحية.
    *   يتم إرسال JWT هذا إلى التطبيق، ويقوم التطبيق بتخزينه بشكل آمن (مثلاً في `SharedPreferences` لـ Flutter).
2.  **الوصول إلى الموارد المحمية:**
    *   في كل طلب لاحق إلى الخادم يتطلب مصادقة، يقوم التطبيق بإرسال JWT في رأس `Authorization` (بصيغة `Bearer Token`).
    *   يقوم الخادم بالتحقق من صحة JWT (التوقيع، تاريخ انتهاء الصلاحية، وما إذا كان المستخدم لا يزال نشطاً).
    *   إذا كان JWT صالحاً، يتم السماح للمستخدم بالوصول إلى المورد المطلوب بناءً على دوره (Authorization).

### ب. التشفير (Encryption)

1.  **تشفير كلمات المرور (Password Hashing):**
    *   يجب عدم تخزين كلمات المرور كنص عادي في قاعدة البيانات. بدلاً من ذلك، يجب استخدام دوال تجزئة (Hashing Functions) قوية مثل **Bcrypt**.
    *   عند تسجيل المستخدم، يتم تجزئة كلمة المرور قبل تخزينها. عند تسجيل الدخول، يتم تجزئة كلمة المرور المدخلة ومقارنتها بالتجزئة المخزنة.
2.  **تشفير الاتصال (HTTPS/WSS):**
    *   يجب أن يتم جميع الاتصال بين التطبيق والخادم عبر بروتوكول **HTTPS** لـ REST API و **WSS (WebSocket Secure)** لـ WebSockets.
    *   هذا يضمن تشفير جميع البيانات المرسلة والمستقبلة، مما يحميها من التنصت والعبث.
    *   يتطلب ذلك تثبيت شهادة SSL/TLS على الخادم.
3.  **تشفير البيانات الحساسة (Data at Rest Encryption):**
    *   لزيادة الأمان، يمكن النظر في تشفير البيانات الحساسة المخزنة في قاعدة البيانات (MongoDB) على مستوى القرص أو باستخدام ميزات التشفير المتاحة في MongoDB Enterprise أو حلول التشفير على مستوى التطبيق إذا كانت هناك متطلبات أمنية صارمة جداً.

### ج. مثال على سكريبت Node.js للمصادقة (JWT & Bcrypt)

```javascript
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const User = require("./models/User"); // Mongoose User Model

const JWT_SECRET = process.env.JWT_SECRET || "supersecretjwtkey"; // يجب أن يكون سراً قوياً

// وظيفة لتسجيل مستخدم جديد
async function registerUser(name, email, password, role) {
    try {
        const hashedPassword = await bcrypt.hash(password, 10); // 10 rounds of hashing
        const newUser = new User({
            name,
            email,
            password: hashedPassword,
            role,
            // ... other user fields
        });
        await newUser.save();
        return { success: true, message: "User registered successfully." };
    } catch (error) {
        console.error("Registration error:", error);
        return { success: false, message: "Registration failed." };
    }
}

// وظيفة لتسجيل الدخول وإنشاء JWT
async function loginUser(email, password) {
    try {
        const user = await User.findOne({ email });
        if (!user) {
            throw new Error("Invalid credentials.");
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            throw new Error("Invalid credentials.");
        }

        const token = jwt.sign(
            { userId: user._id, role: user.role },
            JWT_SECRET,
            { expiresIn: "1h" } // Token expires in 1 hour
        );

        return { success: true, token, user: { id: user._id, name: user.name, role: user.role } };
    } catch (error) {
        console.error("Login error:", error);
        return { success: false, message: error.message };
    }
}

// Middleware للتحقق من JWT في الطلبات المحمية
function authenticateToken(req, res, next) {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (token == null) return res.sendStatus(401); // No token

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403); // Invalid token
        req.user = user; // Attach user payload to request
        next();
    });
}

// مثال على استخدام Middleware في Express.js
// app.get("/protected-route", authenticateToken, (req, res) => {
//     res.json({ message: `Welcome ${req.user.role} ${req.user.userId}` });
// });
```

**شرح السكريبت:**
*   يستخدم `bcrypt.hash` لتشفير كلمة المرور قبل تخزينها في قاعدة البيانات.
*   يستخدم `bcrypt.compare` لمقارنة كلمة المرور المدخلة مع كلمة المرور المشفرة المخزنة.
*   يستخدم `jwt.sign` لإنشاء رمز JWT عند تسجيل الدخول بنجاح.
*   يستخدم `jwt.verify` للتحقق من صحة الرمز في كل طلب لاحق إلى المسارات المحمية.
*   `JWT_SECRET` يجب أن يكون سراً قوياً ويتم تخزينه كمتغير بيئة (Environment Variable) وليس في الكود مباشرة.

## 3. آلية توزيع الأموال ونظام مراقبة وقت التوصيل

### أ. آلية توزيع الأموال (Fund Distribution Logic)

كما هو موضح في قسم نظام التحويلات المالية الموثوق، يتم توزيع الأموال تلقائياً بعد تأكيد العميل استلام الطلب ضمن عملية MongoDB Transaction.

*   **المطعم:** يحصل على إجمالي سعر الوجبات التي تم طلبها.
*   **السائق:** يحصل على نسبة محددة من رسوم التوصيل (يحددها المدير).
*   **المنصة:** تحصل على نسبة متبقية من رسوم التوصيل كعمولة.

**تحديد النسب من قبل المدير:**
يجب أن تكون هناك واجهة في لوحة تحكم الإدارة تسمح للمدير بتحديد وتعديل النسب المئوية لعمولة المنصة وحصة السائق من رسوم التوصيل. هذه النسب يتم تخزينها في `Settings` Collection في MongoDB ويتم جلبها ديناميكياً عند كل عملية حساب.

### ب. نظام مراقبة وقت التوصيل وتنبيهات الإدارة

لضمان جودة الخدمة، يجب مراقبة وقت التوصيل وتنبيه الإدارة في حال تجاوز السائق للوقت المحدد.

1.  **تحديد وقت التوصيل المتوقع:**
    *   عند قبول المطعم للطلب، يمكن تقدير وقت التوصيل المتوقع بناءً على عوامل مثل المسافة بين المطعم والعميل، متوسط سرعة السائقين، ووقت تحضير الوجبة.
    *   يتم تخزين هذا الوقت (مثلاً `expectedDeliveryTime`: Date) في `Orders` Collection.
2.  **مراقبة الوقت في الواجهة الخلفية (Node.js Scheduler):**
    *   يمكن استخدام مكتبة مثل `node-cron` أو `agenda` في Node.js لتشغيل مهمة مجدولة (Scheduled Task) كل فترة زمنية (مثلاً كل 5 دقائق).
    *   تقوم هذه المهمة بالبحث في `Orders` Collection عن الطلبات التي حالتها `onTheWay` والتي تجاوز فيها `expectedDeliveryTime` الوقت الحالي.
3.  **إرسال التنبيهات للإدارة:**
    *   عند اكتشاف طلب متأخر، يتم إرسال تنبيه فوري إلى المدير.
    *   يمكن أن يكون التنبيه عبر البريد الإلكتروني، أو رسالة SMS، أو إشعار داخل لوحة تحكم الإدارة (باستخدام WebSockets لإشعار لحظي).
    *   يجب أن يتضمن التنبيه تفاصيل الطلب (رقم الطلب، العميل، المطعم، السائق، الوقت المتأخر).
4.  **إجراءات المدير:**
    *   يمكن للمدير، بعد تلقي التنبيه، التواصل مع السائق والمطعم لمعرفة سبب التأخير.
    *   يمكن للمدير أيضاً تحديث حالة الطلب يدوياً أو اتخاذ إجراءات أخرى حسب سياسة التطبيق.

### ج. مثال على سكريبت Node.js لمراقبة وقت التوصيل (باستخدام `node-cron`)

```javascript
const cron = require("node-cron");
const Order = require("./models/Order");
const User = require("./models/User"); // For admin email/notifications
// const sendEmail = require("./utils/emailService"); // افتراض وجود خدمة إرسال بريد إلكتروني

// جدولة مهمة للتشغيل كل 5 دقائق
cron.schedule("*/5 * * * *", async () => {
    console.log("Running scheduled task: Checking for overdue orders...");
    const now = new Date();

    try {
        const overdueOrders = await Order.find({
            status: "onTheWay",
            expectedDeliveryTime: { $lt: now }
        }).populate("customerId restaurantId driverId"); // جلب تفاصيل العميل والمطعم والسائق

        if (overdueOrders.length > 0) {
            console.log(`Found ${overdueOrders.length} overdue orders.`);
            // جلب معلومات المدير لإرسال التنبيهات
            const admins = await User.find({ role: "admin" });

            for (const order of overdueOrders) {
                const notificationMessage = `Order ${order._id} (from ${order.restaurantId.name}) is overdue! ` +
                                            `Customer: ${order.customerId.name}, Driver: ${order.driverId.name}. ` +
                                            `Expected delivery: ${order.expectedDeliveryTime.toLocaleString()}.`;
                console.warn(notificationMessage);

                // إرسال تنبيهات للمديرين (بريد إلكتروني، إشعار داخل التطبيق، إلخ)
                for (const admin of admins) {
                    // sendEmail(admin.email, "Overdue Order Alert", notificationMessage);
                    // أو إرسال إشعار WebSocket إلى لوحة تحكم المدير
                    // io.to(admin.socketId).emit("adminNotification", { type: "overdueOrder", message: notificationMessage });
                }

                // يمكن تحديث حالة الطلب إلى "delayed" أو "attention_needed" هنا
                // order.status = "delayed";
                // await order.save();
            }
        }
    } catch (error) {
        console.error("Error checking overdue orders:", error);
    }
});

console.log("Overdue order check scheduler started.");
```

**شرح السكريبت:**
*   يستخدم `node-cron` لجدولة وظيفة للتشغيل كل 5 دقائق (`*/5 * * * *`).
*   تبحث الوظيفة عن الطلبات التي حالتها `onTheWay` وتجاوزت `expectedDeliveryTime`.
*   يتم جلب تفاصيل العميل والمطعم والسائق باستخدام `populate` لإثراء بيانات الطلب.
*   يتم إرسال تنبيهات إلى جميع المستخدمين ذوي دور `admin`.
*   يمكن توسيع هذا السكريبت ليشمل إرسال إشعارات عبر WebSockets إلى لوحة تحكم المدير مباشرة.

هذه الأنظمة تضمن لك تطبيقاً آمناً، موثوقاً، وفعالاً في إدارة العمليات المالية ومراقبة جودة الخدمة.
