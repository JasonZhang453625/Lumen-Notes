import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('home screen shows both primary actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = NotesStore(preferences);
    await store.load();

    await tester.pumpWidget(LumenApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('新建笔记'), findsOneWidget);
    expect(find.text('阅览笔记'), findsOneWidget);
  });
}
