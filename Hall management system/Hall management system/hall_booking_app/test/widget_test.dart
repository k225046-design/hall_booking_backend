import 'package:flutter_test/flutter_test.dart';
import 'package:hall_booking_app/main.dart';

void main() {
  testWidgets('shows landing page', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Shaadi Ghar'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
