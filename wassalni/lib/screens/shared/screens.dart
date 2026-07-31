export 'customer_profile_screen.dart';
export 'driver_profile_screen.dart';
export 'restaurant_profile_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import 'customer_profile_screen.dart';
import 'driver_profile_screen.dart';
import 'restaurant_profile_screen.dart';

/// Public dispatcher — picks the correct profile page based on user role.
/// Falls back to [CustomerProfileScreen] when role is unknown.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.currentUser?.role ?? 'customer';
    switch (role) {
      case 'driver':
        return const DriverProfileScreen();
      case 'restaurant':
        return const RestaurantProfileScreen();
      case 'customer':
      case 'admin':
      default:
        return const CustomerProfileScreen();
    }
  }
}

/// Central route names shared across the app — keep in sync with main.dart.
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String customerHome = '/customer-home';
  static const String restaurantDetail = '/restaurant-detail';
  static const String cart = '/cart';
  static const String customerOrders = '/customer-orders';
  static const String orderTrack = '/order-track';
  static const String driverHome = '/driver-home';
  static const String restaurantHome = '/restaurant-home';
  static const String manageMenu = '/manage-menu';
  static const String addProduct = '/add-product';
  static const String completedOrders = '/completed-orders';
  static const String profile = '/profile';
  static const String adminHome = '/admin-home';

  const AppRoutes._();
}
