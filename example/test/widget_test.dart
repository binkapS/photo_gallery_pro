// Smoke test: the demo app builds and shows either a loading spinner or an
// error/permission state (method-channel calls are unavailable in tests and
// surface through the error path rather than crashing).

import 'package:flutter_test/flutter_test.dart';

import 'package:photo_gallery_pro_example/main.dart';

void main() {
  testWidgets('Demo app builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Photo Gallery Pro Demo'), findsOneWidget);
  });
}
