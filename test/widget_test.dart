import 'package:flutter_test/flutter_test.dart';

import 'package:ai_workout_application/main.dart';
import 'package:ai_workout_application/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Workout app loads successfully',
          (WidgetTester tester) async {
        // Create an AuthProvider for testing.
        final auth = AuthProvider();

        // Build the app.
        await tester.pumpWidget(
          WorkoutApp(auth: auth),
        );

        // Allow the first frame and any startup animations to complete.
        await tester.pumpAndSettle();

        // Verify that the app has been created.
        expect(find.byType(WorkoutApp), findsOneWidget);
      });
}