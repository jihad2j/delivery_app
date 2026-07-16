# هيكلية قاعدة البيانات MongoDB لتطبيق التوصيل

بناءً على طلبك، تم تحديث قاعدة البيانات المقترحة لتكون **MongoDB**. فيما يلي تفاصيل هيكلية البيانات (Schema) المقترحة للمجموعات الرئيسية في قاعدة البيانات، مع الأخذ في الاعتبار المتطلبات الجديدة مثل نظام العملات المتعددة والتتبع المتقدم.

## 1. مجموعة المستخدمين (Users Collection)

ستحتوي هذه المجموعة على جميع أنواع المستخدمين (العميل، السائق، المطعم، المدير)، مع حقل `role` لتحديد نوع المستخدم.

| الحقل | النوع | الوصف | ملاحظات |
| :--- | :--- | :--- | :--- |
| `_id` | ObjectId | المعرف الفريد للمستخدم | يتم إنشاؤه تلقائياً بواسطة MongoDB |
| `name` | String | الاسم الكامل للمستخدم | مطلوب |
| `email` | String | البريد الإلكتروني للمستخدم | مطلوب، فريد |
| `password` | String | كلمة المرور المشفرة | مطلوب |
| `phone` | String | رقم الهاتف | مطلوب، فريد |
| `role` | String | دور المستخدم | `customer`, `driver`, `restaurant`, `admin` |
| `status` | String | حالة الحساب | `active`, `inactive`, `blocked` |
| `profilePicture` | String | رابط صورة الملف الشخصي | اختياري |
| `address` | Object | عنوان العميل (لعملاء فقط) | `street`, `city`, `zipCode`, `location: { type: 'Point', coordinates: [long, lat] }` |
| `restaurantId` | ObjectId | معرف المطعم المرتبط (للمطاعم فقط) | مرجع إلى `Restaurants` Collection |
| `driverInfo` | Object | معلومات السائق (للسائقين فقط) | `vehicleType`, `licenseNumber`, `availability: { type: Boolean, default: false }`, `currentLocation: { type: 'Point', coordinates: [long, lat] }` |
| `createdAt` | Date | تاريخ إنشاء الحساب | |
| `updatedAt` | Date | تاريخ آخر تحديث للحساب | |

## 2. مجموعة المطاعم (Restaurants Collection)

تحتوي على معلومات المطاعم التي تقدم الوجبات.

| الحقل | النوع | الوصف | ملاحظات |
| :--- | :--- | :--- | :--- |
| `_id` | ObjectId | المعرف الفريد للمطعم | |
| `name` | String | اسم المطعم | مطلوب |
| `description` | String | وصف المطعم | اختياري |
| `logo` | String | رابط شعار المطعم | مطلوب |
| `address` | Object | عنوان المطعم | `street`, `city`, `zipCode`, `location: { type: 'Point', coordinates: [long, lat] }` |
| `phone` | String | رقم هاتف المطعم | مطلوب |
| `email` | String | بريد إلكتروني للمطعم | اختياري |
| `ownerId` | ObjectId | معرف مالك المطعم | مرجع إلى `Users` Collection (دور `restaurant`) |
| `status` | String | حالة المطعم | `open`, `closed`, `busy` |
| `minOrderAmount` | Number | الحد الأدنى للطلب | |
| `deliveryFee` | Number | رسوم التوصيل | |
| `menu` | Array of ObjectId | قائمة الوجبات | مرجع إلى `Products` Collection |
| `createdAt` | Date | تاريخ إنشاء المطعم | |
| `updatedAt` | Date | تاريخ آخر تحديث للمطعم | |

## 3. مجموعة المنتجات/الوجبات (Products Collection)

تحتوي على تفاصيل الوجبات التي يقدمها كل مطعم.

| الحقل | النوع | الوصف | ملاحظات |
| :--- | :--- | :--- | :--- |
| `_id` | ObjectId | المعرف الفريد للمنتج | |
| `restaurantId` | ObjectId | معرف المطعم الذي يقدم الوجبة | مرجع إلى `Restaurants` Collection |
| `name` | String | اسم الوجبة | مطلوب |
| `description` | String | وصف الوجبة | اختياري |
| `image` | String | رابط صورة الوجبة | مطلوب |
| `price` | Number | سعر الوجبة بالعملة الأساسية للمطعم | مطلوب (سيتم تحديد العملة الأساسية للمطعم في `Restaurants` Collection أو في إعدادات النظام) |
| `currency` | String | العملة الأساسية للسعر | `SYP` أو `USD` (افتراضي `SYP`) |
| `category` | String | فئة الوجبة | `mainCourse`, `dessert`, `drink` |
| `isAvailable` | Boolean | هل الوجبة متاحة حالياً | `true`, `false` |
| `createdAt` | Date | تاريخ إضافة الوجبة | |
| `updatedAt` | Date | تاريخ آخر تحديث للوجبة | |

## 4. مجموعة الطلبات (Orders Collection)

تحتوي على تفاصيل كل طلب يتم إنشاؤه.

| الحقل | النوع | الوصف | ملاحظات |
| :--- | :--- | :--- | :--- |
| `_id` | ObjectId | المعرف الفريد للطلب | |
| `customerId` | ObjectId | معرف العميل الذي قام بالطلب | مرجع إلى `Users` Collection |
| `restaurantId` | ObjectId | معرف المطعم الذي تم الطلب منه | مرجع إلى `Restaurants` Collection |
| `driverId` | ObjectId | معرف السائق الذي يقوم بالتوصيل | مرجع إلى `Users` Collection (اختياري في البداية) |
| `items` | Array of Objects | قائمة الوجبات المطلوبة | `productId`, `name`, `quantity`, `price` |
| `totalAmount` | Number | إجمالي مبلغ الطلب | مطلوب |
| `currency` | String | العملة التي تم بها الطلب | `SYP` أو `USD` |
| `status` | String | حالة الطلب | `pending`, `accepted`, `preparing`, `ready`, `onTheWay`, `delivered`, `cancelled` |
| `deliveryAddress` | Object | عنوان التوصيل | `street`, `city`, `zipCode`, `location: { type: 'Point', coordinates: [long, lat] }` |
| `paymentMethod` | String | طريقة الدفع | `cash`, `card` |
| `paymentStatus` | String | حالة الدفع | `paid`, `unpaid` |
| `driverLocationHistory` | Array of Objects | سجل مواقع السائق أثناء التوصيل | `timestamp`, `location: { type: 'Point', coordinates: [long, lat] }` (للتتبع) |
| `orderRating` | Object | تقييم الطلب من العميل | `restaurantRating`, `driverRating`, `comment` |
| `createdAt` | Date | تاريخ إنشاء الطلب | |
| `updatedAt` | Date | تاريخ آخر تحديث للطلب | |

## 5. مجموعة أسعار صرف العملات (CurrencyRates Collection)

هذه المجموعة ستخزن أسعار الصرف التي يحددها المدير.

| الحقل | النوع | الوصف | ملاحظات |
| :--- | :--- | :--- | :--- |
| `_id` | ObjectId | المعرف الفريد لسعر الصرف | |
| `baseCurrency` | String | العملة الأساسية | `USD` |
| `targetCurrency` | String | العملة المستهدفة | `SYP` |
| `rate` | Number | سعر الصرف (كم ليرة سورية مقابل 1 دولار) | مطلوب، يحدده المدير |
| `updatedBy` | ObjectId | معرف المدير الذي قام بالتحديث | مرجع إلى `Users` Collection |
| `lastUpdated` | Date | تاريخ آخر تحديث لسعر الصرف | |

## 6. مجموعة الإعدادات العامة (Settings Collection)

يمكن استخدام هذه المجموعة لتخزين الإعدادات العامة للنظام، بما في ذلك العملة الافتراضية.

| الحقل | النوع | الوصف | ملاحظات |
| :--- | :--- | :--- | :--- |
| `_id` | ObjectId | المعرف الفريد للإعداد | |
| `key` | String | مفتاح الإعداد | `defaultCurrency`, `deliveryRadius`, `adminEmail` |
| `value` | Mixed | قيمة الإعداد | `SYP`, `USD`, `10km`, `admin@example.com` |
| `lastUpdated` | Date | تاريخ آخر تحديث للإعداد | |

**ملاحظات هامة حول MongoDB:**
*   **المرونة:** MongoDB مرنة للغاية، ويمكن إضافة حقول جديدة إلى المستندات بسهولة دون الحاجة لتعديل الهيكلية (Schema) بشكل صارم.
*   **الفهرسة (Indexing):** لضمان الأداء العالي، يجب إنشاء فهارس على الحقول التي يتم البحث بها بشكل متكرر (مثل `email`, `phone`, `role` في `Users`، و `restaurantId` في `Products` و `Orders`).
*   **الفهرسة الجغرافية (Geospatial Indexing):** حقول `location` في `Users` (للسائقين والعملاء) و `Restaurants` و `Orders` يجب أن تكون من نوع `GeoJSON Point` مع فهرسة `2dsphere` لتمكين عمليات البحث الجغرافي الفعالة (مثل البحث عن أقرب سائق أو مطعم).
