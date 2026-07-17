import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/widgets/add_audio_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用 en locale 包裹被测弹窗。
Widget _host(List<({String attempted, String existing})> duplicates) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: DuplicatesSkippedDialog(duplicates: duplicates)),
  );
}

void main() {
  group('DuplicatesSkippedDialog', () {
    testWidgets('展示计数标题与确定按钮', (tester) async {
      await tester.pumpWidget(_host([(attempted: 'a', existing: 'a')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('1'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'OK'), findsOneWidget);
    });

    testWidgets('大量重复项不溢出且可滚动', (tester) async {
      final many = [
        for (var i = 0; i < 40; i++) (attempted: 'TPO-$i', existing: 'TPO-$i'),
      ];
      await tester.pumpWidget(_host(many));
      await tester.pumpAndSettle();

      // 列表在限高卡片内滚动，不应有渲染溢出（tester 会在溢出时抛异常）。
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 首项可见。
      expect(find.text('TPO-0'), findsOneWidget);
    });

    testWidgets('导入名与已有名不同时显示"内容相同"次行', (tester) async {
      await tester.pumpWidget(
        _host([(attempted: 'lecture-copy', existing: 'TPO-32-L4')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('lecture-copy'), findsOneWidget);
      // en 文案："Same content as \"TPO-32-L4\""
      expect(find.textContaining('TPO-32-L4'), findsOneWidget);
    });

    testWidgets('导入名与已有名相同时不显示次行', (tester) async {
      await tester.pumpWidget(_host([(attempted: 'same', existing: 'same')]));
      await tester.pumpAndSettle();

      expect(find.text('same'), findsOneWidget);
      expect(find.textContaining('Same content as'), findsNothing);
    });

    testWidgets('点击确定关闭弹窗', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const DuplicatesSkippedDialog(
                      duplicates: [(attempted: 'a', existing: 'a')],
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(DuplicatesSkippedDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DuplicatesSkippedDialog), findsNothing);
    });
  });
}
