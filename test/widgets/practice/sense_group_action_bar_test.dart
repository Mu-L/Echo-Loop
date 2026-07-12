import 'package:echo_loop/widgets/practice/sense_group_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('意群快捷条显示收藏和 AI lookup，lookup 位于收藏右侧', (tester) async {
    var saveCalls = 0;
    var lookupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SenseGroupActionBar(
              isSaved: false,
              onToggleSave: () => saveCalls++,
              onLookup: () => lookupCalls++,
            ),
          ),
        ),
      ),
    );

    final save = find.byKey(const Key('sense_group_save_action'));
    final lookup = find.byKey(const Key('sense_group_lookup_action'));

    expect(save, findsOneWidget);
    expect(lookup, findsOneWidget);
    expect(tester.getCenter(lookup).dx, greaterThan(tester.getCenter(save).dx));

    await tester.tap(save);
    await tester.pump();
    await tester.tap(lookup);
    await tester.pump();

    expect(saveCalls, 1);
    expect(lookupCalls, 1);
  });

  testWidgets('lookup 禁用时不可点击，但收藏仍可用', (tester) async {
    var saveCalls = 0;
    var lookupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SenseGroupActionBar(
              isSaved: false,
              lookupEnabled: false,
              onToggleSave: () => saveCalls++,
              onLookup: () => lookupCalls++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('sense_group_lookup_action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sense_group_save_action')));
    await tester.pump();

    expect(lookupCalls, 0);
    expect(saveCalls, 1);
  });

  testWidgets('夜间模式下快捷条可见且按钮可点击', (tester) async {
    var lookupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SenseGroupActionBar(
              isSaved: false,
              onToggleSave: () {},
              onLookup: () => lookupCalls++,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sense_group_save_action')), findsOneWidget);
    expect(find.byKey(const Key('sense_group_lookup_action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sense_group_lookup_action')));
    await tester.pump();

    expect(lookupCalls, 1);
  });
}
