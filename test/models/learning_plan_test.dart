/// LearningPlan 值对象测试
///
/// 覆盖：
/// - fromSettings 根据 retellEnabled 派生不同 plan
/// - subStagesFor / includes / indexOf / totalPlannedCount
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/learning_plan.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningPlan.fromSettings', () {
    test('retellEnabled=true → 包含所有复述类子步骤', () {
      final plan = LearningPlan.fromSettings(
        const LearningSettings(retellEnabled: true),
      );
      expect(
        plan.subStagesFor(LearningStage.firstLearn),
        equals(LearningStage.firstLearn.allSubStages),
      );
      expect(
        plan.subStagesFor(LearningStage.review0),
        equals(LearningStage.review0.allSubStages),
      );
      expect(
        plan.subStagesFor(LearningStage.review28),
        equals(LearningStage.review28.allSubStages),
      );
    });

    test('retellEnabled=false → 移除复述类子步骤', () {
      final plan = LearningPlan.fromSettings(
        const LearningSettings(retellEnabled: false),
      );
      expect(plan.subStagesFor(LearningStage.firstLearn), [
        SubStageType.blindListen,
        SubStageType.intensiveListen,
        SubStageType.listenAndRepeat,
      ]);
      expect(plan.subStagesFor(LearningStage.review0), [
        SubStageType.reviewDifficultPractice,
      ]);
      expect(plan.subStagesFor(LearningStage.review14), [
        SubStageType.blindListen,
        SubStageType.reviewDifficultPractice,
      ]);
      expect(plan.subStagesFor(LearningStage.review28), [
        SubStageType.blindListen,
        SubStageType.reviewDifficultPractice,
      ]);
    });

    test('completed 阶段始终返回空列表', () {
      final planOn = LearningPlan.fromSettings(
        const LearningSettings(retellEnabled: true),
      );
      final planOff = LearningPlan.fromSettings(
        const LearningSettings(retellEnabled: false),
      );
      expect(planOn.subStagesFor(LearningStage.completed), isEmpty);
      expect(planOff.subStagesFor(LearningStage.completed), isEmpty);
    });
  });

  group('LearningPlan API', () {
    final plan = LearningPlan.fromSettings(
      const LearningSettings(retellEnabled: false),
    );

    test('includes 判定 sub 是否在 plan 内', () {
      expect(
        plan.includes(LearningStage.firstLearn, SubStageType.blindListen),
        isTrue,
      );
      // retell 不在 plan
      expect(
        plan.includes(LearningStage.firstLearn, SubStageType.retell),
        isFalse,
      );
    });

    test('indexOf 返回 plan 内位置，不在 plan 返回 -1', () {
      expect(
        plan.indexOf(LearningStage.firstLearn, SubStageType.listenAndRepeat),
        2,
      );
      expect(
        plan.indexOf(LearningStage.firstLearn, SubStageType.retell),
        -1,
      );
    });

    test('totalPlannedCount 跨所有阶段求和', () {
      // OFF: firstLearn=3 + review0=1 + review1/2/4/7/14=2*5 + review28=2 + completed=0 = 16
      expect(plan.totalPlannedCount, 16);

      final planOn = LearningPlan.fromSettings(
        const LearningSettings(retellEnabled: true),
      );
      // ON: firstLearn=4 + review0=2 + review1/2/4/7/14=3*5 + review28=3 + completed=0 = 24
      expect(planOn.totalPlannedCount, 24);
    });
  });

  group('LearningPlan.nextPlannedAfter', () {
    final planOn = LearningPlan.fromSettings(
      const LearningSettings(retellEnabled: true),
    );
    final planOff = LearningPlan.fromSettings(
      const LearningSettings(retellEnabled: false),
    );

    test('当前阶段 plan 中间项 → 返回下一项', () {
      // plan ON: firstLearn = [blind, intensive, shadow, retell]
      final next = planOn.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.intensiveListen,
      );
      expect(next, isNotNull);
      expect(next!.stage, LearningStage.firstLearn);
      expect(next.subStage, SubStageType.listenAndRepeat);
    });

    test('当前阶段 plan 末尾 → 返回 null（不跨阶段引导）', () {
      // plan ON: firstLearn 末尾 = retell
      final next = planOn.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.retell,
      );
      expect(next, isNull);
    });

    test('plan OFF：review0 难句补练（plan 末尾）→ null（bug 1 修复）', () {
      // plan OFF: review0 = [reviewDifficultPractice]
      final next = planOff.nextPlannedAfter(
        LearningStage.review0,
        SubStageType.reviewDifficultPractice,
      );
      expect(next, isNull, reason: '关闭复述时 review0 难句补练完成后不应"继续段落复述"');
    });

    test('当前 subStage 不在 plan 内（被过滤）→ null', () {
      // plan OFF：firstLearn 不含 retell
      final next = planOff.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.retell,
      );
      expect(next, isNull);
    });
  });
}
