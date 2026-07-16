import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wassalni/main.dart';
import 'package:wassalni/providers/providers.dart';

void main() {
  testWidgets('Wassalni App Splash Screen Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame, wrapping it with the required Providers
    await tester.pumpWidget(
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

    // Verify that splash screen content exists
    expect(find.text('وصلني'), findsOneWidget);

    // Allow timers and animations to finish completely
    await tester.pumpAndSettle();
  });
}
