[CLOSED] Debug Session: restaurant-product-objectid

## Symptoms
- عند محاولة إضافة منتج من واجهة المطعم، يرجع الخادم الخطأ:
- `Cast to ObjectId failed for value "dummy" (type string) at path "_id" for model "Restaurant"`

## Hypotheses
1. واجهة Flutter ترسل `restaurantId: "dummy"` كقيمة افتراضية بدل المعرف الحقيقي للمطعم.
2. نموذج/شاشة إضافة المنتج تبني الطلب من كائن مطعم ناقص البيانات فيتحول المعرف إلى قيمة placeholder.
3. الخادم يتوقع `restaurantId` في `req.body` بينما الواجهة لا تجلب مطعم المستخدم الحالي أصلًا.
4. هناك تحويل خاطئ في طبقة `ProductModel.toJson()` أو عند إنشاء جسم الطلب يمرر `_id`/`restaurantId` بشكل غير صحيح.
5. بيانات المستخدم المطعم لا تحتوي `restaurantId` الصحيح في البروفايل أو الجلسة، لذلك تستبدل الواجهة القيمة بـ `dummy`.

## Plan
1. تتبع مسار إضافة المنتج من الشاشة حتى الطلب الشبكي.
2. إضافة instrumentation فقط حول payload والقيم المستخدمة في `restaurantId`.
3. إعادة إنتاج المشكلة وجمع السجل.
4. تحديد السبب المؤكد ثم تطبيق إصلاح محدود.
5. إعادة التحقق بعد الإصلاح.

## Evidence
- تم فحص ملف `menu_screen.dart` في واجهة التطبيق، وتبين أنه يرسل `restaurantId: 'dummy'` كقيمة افتراضية (placeholder) عند إنشاء منتج جديد.
- في واجهة الـ Backend (`controller_ProductController.js`)، إذا تم تسجيل الدخول بحساب مسؤول (`admin`) وتجربة واجهة المطعم، أو إذا تم محاولة البحث عن المطعم عن طريق الـ `restaurantId` المُرسل كـ `'dummy'`، يفشل MongoDB في تحويل السلسلة إلى `ObjectId`.
- دالة `toJson` في كائن `ProductModel` كانت تقوم بإرفاق حقول `_id` و `restaurantId` دائمًا حتى وإن كانت `null`.

## Conclusion
تم حل المشكلة عبر ثلاث خطوات أساسية:
1. تعديل دالة `toJson` في كلاس `ProductModel` (`product.dart`) لتجاهل حقلي `_id` و `restaurantId` وعدم إرسالهم في الطلب إذا كانوا `null`.
2. إزالة القيمة الافتراضية `'dummy'` من واجهة إضافة المنتج في التطبيق (`menu_screen.dart`)، مما يسمح للخادم باستنتاج المطعم آلياً بناءً على توكن المصادقة للمستخدم.
3. إضافة حماية في واجهة الخادم (`controller_ProductController.js`) في دالة `createProduct` لرد خطأ `400 Bad Request` برسالة واضحة في حال كان المستخدم (admin) ولم يمرر `restaurantId` صالح بدلاً من انهيار الطلب بخطأ MongoDB، كما تم إزالة دالة `getProductByIde` الزائدة.
