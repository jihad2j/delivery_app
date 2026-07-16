import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'core/theme.dart';
import 'screens/auth_screens.dart';
import 'screens/customer_screens.dart';
import 'screens/driver_screens.dart';
import 'screens/restaurant_screens.dart';
import 'screens/profile_screen.dart';
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
      themeMode: ThemeMode.system,
      locale: const Locale('ar', 'SY'), // Default Arabic localization
      supportedLocales: const [Locale('ar', 'SY'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/customer-home':
            return MaterialPageRoute(
              builder: (_) => const CustomerHomeScreen(),
            );
          case '/restaurant-detail':
            final rest = settings.arguments as model.User;
            return MaterialPageRoute(
              builder: (_) => RestaurantDetailScreen(restaurant: rest),
            );
          case '/cart':
            return MaterialPageRoute(builder: (_) => const CartScreen());
          case '/customer-orders':
            return MaterialPageRoute(
              builder: (_) => const CustomerOrdersScreen(),
            );
          case '/order-track':
            final order = settings.arguments as model.Order;
            return MaterialPageRoute(
              builder: (_) => OrderTrackScreen(order: order),
            );
          case '/driver-home':
            return MaterialPageRoute(builder: (_) => const DriverHomeScreen());
          case '/restaurant-home':
            return MaterialPageRoute(
              builder: (_) => const RestaurantHomeScreen(),
            );
          case '/manage-menu':
            return MaterialPageRoute(builder: (_) => const ManageMenuScreen());
          case '/add-product':
            return MaterialPageRoute(builder: (_) => const AddProductScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
