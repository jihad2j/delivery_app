class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String? profilePicture;
  final Address? address;
  final List<Address> addresses;
  final RestaurantInfo? restaurantInfo;
  final DriverInfo? driverInfo;
  final double balance;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.profilePicture,
    this.address,
    required this.addresses,
    this.restaurantInfo,
    this.driverInfo,
    required this.balance,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    var addrList = <Address>[];
    if (json['addresses'] != null) {
      addrList = List<Address>.from(
        (json['addresses'] as List).map((x) => Address.fromJson(x))
      );
    }
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
      status: json['status'] ?? 'active',
      profilePicture: json['profilePicture'],
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      addresses: addrList,
      restaurantInfo: json['restaurantInfo'] != null
          ? RestaurantInfo.fromJson(json['restaurantInfo'])
          : null,
      driverInfo: json['driverInfo'] != null
          ? DriverInfo.fromJson(json['driverInfo'])
          : null,
      balance: (json['balance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'profilePicture': profilePicture,
      'address': address?.toJson(),
      'addresses': addresses.map((x) => x.toJson()).toList(),
      'restaurantInfo': restaurantInfo?.toJson(),
      'driverInfo': driverInfo?.toJson(),
      'balance': balance,
    };
  }
}

class Address {
  final String? label; // بيتي - العمل - محلي
  final String? governorate; // المحافظة
  final String? region; // المنطقة
  final String? details; // التفاصيل (الحارة - اسم الشارع...)
  final String? street;
  final String? city;
  final String? zipCode;
  final Location? location;
  final String? houseDoorPicture; // Base64 or URL

  Address({
    this.label,
    this.governorate,
    this.region,
    this.details,
    this.street,
    this.city,
    this.zipCode,
    this.location,
    this.houseDoorPicture,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      label: json['label'],
      governorate: json['governorate'],
      region: json['region'],
      details: json['details'],
      street: json['street'],
      city: json['city'],
      zipCode: json['zipCode'],
      location: json['location'] != null ? Location.fromJson(json['location']) : null,
      houseDoorPicture: json['houseDoorPicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'governorate': governorate,
      'region': region,
      'details': details,
      'street': street,
      'city': city,
      'zipCode': zipCode,
      'location': location?.toJson(),
      'houseDoorPicture': houseDoorPicture,
    };
  }
}

class Location {
  final String type;
  final List<double> coordinates;

  Location({this.type = 'Point', required this.coordinates});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      type: json['type'] ?? 'Point',
      coordinates: List<double>.from((json['coordinates'] ?? [0.0, 0.0]).map((x) => x.toDouble())),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }
}

class RestaurantInfo {
  final String? description;
  final String logo;
  final String status;
  final double minOrderAmount;
  final double deliveryFee;
  final List<String> menu;
  final String cuisineType; // مشروبات - حلويات - مشاوي - شاورما فروج
  final bool firebaseNotifications; // تفعيل التنبيهات أو إيقافها

  RestaurantInfo({
    this.description,
    required this.logo,
    required this.status,
    required this.minOrderAmount,
    required this.deliveryFee,
    required this.menu,
    this.cuisineType = 'مشاوي',
    this.firebaseNotifications = true,
  });

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) {
    return RestaurantInfo(
      description: json['description'],
      logo: json['logo'] ?? 'https://via.placeholder.com/150',
      status: json['status'] ?? 'open',
      minOrderAmount: (json['minOrderAmount'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      menu: (json['menu'] ?? []).map<String>((x) {
        if (x is Map) {
          return (x['_id'] ?? x['id'] ?? '').toString();
        }
        return x.toString();
      }).toList(),
      cuisineType: json['cuisineType'] ?? 'مشاوي',
      firebaseNotifications: json['firebaseNotifications'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'logo': logo,
      'status': status,
      'minOrderAmount': minOrderAmount,
      'deliveryFee': deliveryFee,
      'menu': menu,
      'cuisineType': cuisineType,
      'firebaseNotifications': firebaseNotifications,
    };
  }
}

class DriverInfo {
  final String? vehicleType;
  final String? licenseNumber;
  final bool availability;
  final Location? currentLocation;

  DriverInfo({
    this.vehicleType,
    this.licenseNumber,
    required this.availability,
    this.currentLocation,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      vehicleType: json['vehicleType'],
      licenseNumber: json['licenseNumber'],
      availability: json['availability'] ?? false,
      currentLocation: json['currentLocation'] != null
          ? Location.fromJson(json['currentLocation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleType': vehicleType,
      'licenseNumber': licenseNumber,
      'availability': availability,
      'currentLocation': currentLocation?.toJson(),
    };
  }
}

class Product {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final String image;
  final double price;
  final double? totalAmount;
  final String currency;
  final String category;
  final bool isAvailable;

  Product({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.image,
    required this.price,
    this.totalAmount,
    required this.currency,
    required this.category,
    required this.isAvailable,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? json['id'] ?? '',
      restaurantId: json['restaurantId'] is Map
          ? (json['restaurantId']['_id'] ?? json['restaurantId']['id'] ?? '')
          : (json['restaurantId'] ?? ''),
      name: json['name'] ?? '',
      description: json['description'],
      image: json['image'] ?? 'https://via.placeholder.com/150',
      price: (json['price'] ?? 0).toDouble(),
      totalAmount: json['totalAmount'] != null ? (json['totalAmount'] as num).toDouble() : null,
      currency: json['currency'] ?? 'SYP',
      category: json['category'] ?? 'mainCourse',
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'totalAmount': totalAmount,
      'currency': currency,
      'category': category,
      'isAvailable': isAvailable,
    };
  }
}

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}

class Order {
  final String id;
  final dynamic customerId; // Can be ID or User object
  final dynamic restaurantId; // Can be ID or User object
  final dynamic driverId; // Can be ID or User object
  final List<OrderItem> items;
  final double totalAmount;
  final String currency;
  final double deliveryFee;
  final String status;
  final Address deliveryAddress;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? expectedDeliveryTime;
  final double? platformCommission;
  final double? restaurantShare;
  final double? driverShare;
  final String? packagedPicture; // تصوير الطلب وتغليفه (من المطعم)
  final String? receivedPicture; // تصوير الطلب عند الاستلام (من العميل)

  Order({
    required this.id,
    required this.customerId,
    required this.restaurantId,
    this.driverId,
    required this.items,
    required this.totalAmount,
    required this.currency,
    required this.deliveryFee,
    required this.status,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.expectedDeliveryTime,
    this.platformCommission,
    this.restaurantShare,
    this.driverShare,
    this.packagedPicture,
    this.receivedPicture,
  });

  String get driverIdStr {
    if (driverId == null) return '';
    if (driverId is String) return driverId;
    if (driverId is Map) return driverId['_id'] ?? driverId['id'] ?? '';
    if (driverId is User) return (driverId as User).id;
    return driverId.toString();
  }

  String get customerIdStr {
    if (customerId == null) return '';
    if (customerId is String) return customerId;
    if (customerId is Map) return customerId['_id'] ?? customerId['id'] ?? '';
    if (customerId is User) return (customerId as User).id;
    return customerId.toString();
  }

  String get restaurantIdStr {
    if (restaurantId == null) return '';
    if (restaurantId is String) return restaurantId;
    if (restaurantId is Map) return restaurantId['_id'] ?? restaurantId['id'] ?? '';
    if (restaurantId is User) return (restaurantId as User).id;
    return restaurantId.toString();
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? json['id'] ?? '',
      customerId: json['customerId'],
      restaurantId: json['restaurantId'],
      driverId: json['driverId'],
      items: List<OrderItem>.from((json['items'] ?? []).map((x) => OrderItem.fromJson(x))),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'SYP',
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      deliveryAddress: Address.fromJson(json['deliveryAddress'] ?? {}),
      paymentMethod: json['paymentMethod'] ?? 'cash',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      expectedDeliveryTime: json['expectedDeliveryTime'] != null
          ? DateTime.parse(json['expectedDeliveryTime'])
          : null,
      platformCommission: json['platformCommission'] != null
          ? (json['platformCommission'] as num).toDouble()
          : null,
      restaurantShare: json['restaurantShare'] != null
          ? (json['restaurantShare'] as num).toDouble()
          : null,
      driverShare: json['driverShare'] != null
          ? (json['driverShare'] as num).toDouble()
          : null,
      packagedPicture: json['packagedPicture'],
      receivedPicture: json['receivedPicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'customerId': customerId is User ? (customerId as User).id : customerId,
      'restaurantId': restaurantId is User ? (restaurantId as User).id : restaurantId,
      'driverId': driverId is User ? (driverId as User).id : driverId,
      'items': items.map((x) => x.toJson()).toList(),
      'totalAmount': totalAmount,
      'currency': currency,
      'deliveryFee': deliveryFee,
      'status': status,
      'deliveryAddress': deliveryAddress.toJson(),
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'expectedDeliveryTime': expectedDeliveryTime?.toIso8601String(),
      'packagedPicture': packagedPicture,
      'receivedPicture': receivedPicture,
    };
  }
}
