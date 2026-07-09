import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/utils/plan_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造仅含价格与周期的套餐（其余字段不影响折算）。
SubscriptionPlan _plan(String price, SubscriptionPeriod period) =>
    SubscriptionPlan(
      planId: price,
      title: price,
      priceString: price,
      period: period,
    );

void main() {
  group('computeYearlyValue', () {
    test(r'常规：$4.99/月 + $39.99/年 → 立省 33%，每月折合 $3.33', () {
      final v = computeYearlyValue(
        _plan(r'$4.99', SubscriptionPeriod.monthly),
        _plan(r'$39.99', SubscriptionPeriod.yearly),
      );
      expect(v.savePercent, 33);
      expect(v.perMonth, r'$3.33');
    });

    test(r'带 US$ 前缀同样可解析', () {
      final v = computeYearlyValue(
        _plan(r'US$4.99', SubscriptionPeriod.monthly),
        _plan(r'US$39.99', SubscriptionPeriod.yearly),
      );
      expect(v.savePercent, 33);
      expect(v.perMonth, r'US$3.33');
    });

    test('人民币符号 ¥', () {
      final v = computeYearlyValue(
        _plan('¥28.00', SubscriptionPeriod.monthly),
        _plan('¥198.00', SubscriptionPeriod.yearly),
      );
      // 1 - 198/(28*12)=1-198/336=0.4107 → 41%
      expect(v.savePercent, 41);
      expect(v.perMonth, '¥16.50');
    });

    test('欧元后缀 + 逗号小数（39,99 €）', () {
      final v = computeYearlyValue(
        _plan('4,99 €', SubscriptionPeriod.monthly),
        _plan('39,99 €', SubscriptionPeriod.yearly),
      );
      expect(v.savePercent, 33);
      expect(v.perMonth, '3.33 €');
    });

    test(r'年付有首期促销时，按首年实际支付价计算折扣', () {
      const yearly = SubscriptionPlan(
        planId: 'yearly',
        title: 'Yearly',
        priceString: r'US$59.99',
        period: SubscriptionPeriod.yearly,
        introOffer: SubscriptionIntroOffer(
          priceString: r'US$30.00',
          period: SubscriptionOfferPeriod.year,
          periodNumberOfUnits: 1,
          cycles: 1,
          isFreeTrial: false,
          renewalPriceString: r'US$59.99',
        ),
      );
      final v = computeYearlyValue(
        _plan(r'US$8.99', SubscriptionPeriod.monthly),
        yearly,
      );
      // 1 - 30/(8.99*12)=0.7219 → 72%
      expect(v.savePercent, 72);
      expect(v.perMonth, r'US$2.50');
    });

    test('千分位整数（1,000）按整数解析', () {
      final v = computeYearlyValue(
        _plan(r'$100', SubscriptionPeriod.monthly),
        _plan(r'$1,000', SubscriptionPeriod.yearly),
      );
      // 1 - 1000/1200 = 0.1667 → 17%
      expect(v.savePercent, 17);
      expect(v.perMonth, r'$83.33');
    });

    test('年付不便宜（年 ≥ 月×12）返回空', () {
      final v = computeYearlyValue(
        _plan(r'$4.99', SubscriptionPeriod.monthly),
        _plan(r'$60.00', SubscriptionPeriod.yearly),
      );
      expect(v.savePercent, isNull);
      expect(v.perMonth, isNull);
    });

    test('价格无法解析（无数字）返回空', () {
      final v = computeYearlyValue(
        _plan('Free', SubscriptionPeriod.monthly),
        _plan(r'$39.99', SubscriptionPeriod.yearly),
      );
      expect(v.savePercent, isNull);
      expect(v.perMonth, isNull);
    });
  });
}
