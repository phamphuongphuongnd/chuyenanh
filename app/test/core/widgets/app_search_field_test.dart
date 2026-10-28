import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/widgets/app_search_field.dart';

const _yellow = Color(0xFFFFEB3B);

Future<TextEditingController> _pump(
  WidgetTester tester, {
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  bool autofocus = false,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        // Giống app_theme.dart: ô nhập nền vàng.
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _yellow,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: AppSearchField(
            controller: controller,
            hintText: 'Search here',
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('không ăn nền vàng của theme, chữ và hint màu trắng', (
    tester,
  ) async {
    await _pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.filled, isFalse);
    expect(field.style!.color, Colors.white);
    expect(field.decoration!.hintStyle!.color, Colors.white70);
    expect(field.cursorColor, Colors.white);
    expect(find.text('Search here'), findsOneWidget);

    // Nền thực tế (đã gộp với theme) cũng không được tô vàng.
    final effective = tester
        .widget<InputDecorator>(find.byType(InputDecorator))
        .decoration
        .applyDefaults(Theme.of(tester.element(find.byType(TextField))).inputDecorationTheme);
    expect(effective.filled, isFalse);
  });

  testWidgets('gọi onChanged khi gõ và onSubmitted khi bấm tìm', (tester) async {
    final changed = <String>[];
    final submitted = <String>[];
    final controller = await _pump(
      tester,
      onChanged: changed.add,
      onSubmitted: submitted.add,
    );

    await tester.enterText(find.byType(TextField), 'abc');
    expect(changed, ['abc']);
    expect(controller.text, 'abc');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submitted, ['abc']);
  });

  testWidgets('autofocus mặc định bật', (tester) async {
    await _pump(tester, autofocus: true);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.textInputAction, TextInputAction.search);
  });
}
