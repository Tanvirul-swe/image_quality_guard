import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quality guard demo shows the focused upload flow', (
    tester,
  ) async {
    await tester.pumpWidget(const ImageQualityGuardExampleApp());

    expect(find.text('Image Quality Guard'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Quality profile'), findsOneWidget);
    expect(find.text('Analyze image'), findsOneWidget);
    expect(find.text('Select an image to begin'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    final dropdown = find.byKey(const Key('quality-profile-dropdown'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(find.text('Minimum sharpness'), findsOneWidget);
    expect(find.text('Minimum brightness'), findsOneWidget);
    expect(find.text('Minimum contrast'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
  });
}
