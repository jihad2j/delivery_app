import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'core/theme.dart';
import 'screens/auth/screens.dart';
import 'screens/customer/screens.dart';
import 'screens/driver/screens.dart';
import 'screens/restaurant/screens.dart';
import 'screens/admin_screens.dart';
import 'screens/shared/screens.dart'
    show AppRoutes, ProfileScreen;
import 'models/models.dart' as model;

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()..loadCart()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: const WassalniApp(),
    ),
  );
}

class WassalniApp extends StatelessWidget {
  const WassalniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصلني',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      highContrastTheme: AppTheme.lightTheme,
      highContrastDarkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('ar', 'SY'),
      supportedLocales: const [Locale('ar', 'SY'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior(),
      initialRoute: AppRoutes.splash,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              (MediaQuery.of(context).textScaleFactor).clamp(0.85, 1.2),
            ),
          ),
          child: child ?? const SizedBox(width: 1, height: 1),
        );
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return _page(const SplashScreen(), settings);
          case AppRoutes.login:
            return _page(const LoginScreen(), settings);
          case AppRoutes.register:
            return _page(const RegisterScreen(), settings);
          case AppRoutes.customerHome:
            return _page(const CustomerHomeScreen(), settings);
          case AppRoutes.restaurantDetail:
            final rest = settings.arguments as model.User;
            return _page(RestaurantDetailScreen(restaurant: rest), settings);
          case AppRoutes.cart:
            return _page(const CartScreen(), settings);
          case AppRoutes.customerOrders:
            return _page(const CustomerOrdersScreen(), settings);
          case AppRoutes.orderTrack:
            final order = settings.arguments as model.Order;
            return _page(OrderTrackScreen(order: order), settings);
          case AppRoutes.driverHome:
            return _page(const DriverHomeScreen(), settings);
          case AppRoutes.restaurantHome:
            return _page(const RestaurantHomeScreen(), settings);
          case AppRoutes.manageMenu:
            return _page(const ManageMenuScreen(), settings);
          case AppRoutes.addProduct:
            return _page(const AddProductScreen(), settings);
          case AppRoutes.completedOrders:
            return _page(const CompletedOrdersScreen(), settings);
          case AppRoutes.profile:
            return _page(const ProfileScreen(), settings);
          case AppRoutes.adminHome:
            return _page(const AdminHomeScreen(), settings);
          default:
            return _page(const SplashScreen(), settings);
        }
      },
    );
  }

  static MaterialPageRoute<T> _page<T>(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<T>(
      builder: (_) => child,
      settings: settings,
      maintainState: true,
    );
  }
}
