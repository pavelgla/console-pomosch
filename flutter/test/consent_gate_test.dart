import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/pages/consent_page.dart';

void main() {
  Widget app({
    required bool accepted,
    required List<String> saved,
    List<String>? opened,
  }) {
    var state = accepted;
    return MaterialApp(
      home: ConsentGate(
        isAccepted: () => state,
        onAccept: () async {
          state = true;
          saved.add('Y');
        },
        openUrl: (url) async => opened?.add(url),
        child: const Scaffold(body: Text('ГЛАВНЫЙ ЭКРАН')),
      ),
    );
  }

  testWidgets('без согласия главный экран не открывается', (tester) async {
    await tester.pumpWidget(app(accepted: false, saved: []));

    expect(find.text('ГЛАВНЫЙ ЭКРАН'), findsNothing);
    expect(find.text('Принимаю'), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Условия использования'), findsOneWidget);
  });

  testWidgets('ссылки ведут на политику и оферту', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(app(accepted: false, saved: [], opened: opened));

    await tester.tap(find.text('Политика конфиденциальности'));
    await tester.tap(find.text('Условия использования'));

    expect(opened, [
      'https://console10.ru/helpdesk/privacy',
      'https://console10.ru/helpdesk/oferta',
    ]);
  });

  testWidgets('«Принимаю» сохраняет согласие и открывает главный экран',
      (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(app(accepted: false, saved: saved));

    await tester.tap(find.text('Принимаю'));
    await tester.pumpAndSettle();

    expect(saved, ['Y']);
    expect(find.text('ГЛАВНЫЙ ЭКРАН'), findsOneWidget);
    expect(find.text('Принимаю'), findsNothing);
  });

  testWidgets('при уже данном согласии экран не показывается', (tester) async {
    await tester.pumpWidget(app(accepted: true, saved: []));

    expect(find.text('ГЛАВНЫЙ ЭКРАН'), findsOneWidget);
    expect(find.text('Принимаю'), findsNothing);
  });
}
