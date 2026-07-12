/// RevenueCat 平台 key 映射测试。
///
/// 重点锁定 Apple 平台策略：iOS 与 macOS 同属 StoreKit 购买通道，必须共用
/// `REVENUECAT_API_KEY_APPLE`，避免 macOS 订阅入口被误隐藏。
library;

import 'package:echo_loop/config/revenuecat_config.dart';
import 'package:echo_loop/config/client_distribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('revenueCatApiKeyForPlatform', () {
    test('iOS 和 macOS 都使用 Apple public key', () {
      for (final platform in [
        (isIOS: true, isMacOS: false),
        (isIOS: false, isMacOS: true),
      ]) {
        final key = revenueCatApiKeyForPlatform(
          isWeb: false,
          isIOS: platform.isIOS,
          isMacOS: platform.isMacOS,
          isAndroid: false,
          appleKey: 'apple_key',
          googleKey: 'google_key',
        );

        expect(key, 'apple_key');
      }
    });

    test('Android 使用 Google public key', () {
      final key = revenueCatApiKeyForPlatform(
        isWeb: false,
        isIOS: false,
        isMacOS: false,
        isAndroid: true,
        appleKey: 'apple_key',
        googleKey: 'google_key',
      );

      expect(key, 'google_key');
    });

    test('Web 和未知桌面平台不启用 RevenueCat', () {
      final webKey = revenueCatApiKeyForPlatform(
        isWeb: true,
        isIOS: true,
        isMacOS: true,
        isAndroid: true,
        appleKey: 'apple_key',
        googleKey: 'google_key',
      );
      final unknownKey = revenueCatApiKeyForPlatform(
        isWeb: false,
        isIOS: false,
        isMacOS: false,
        isAndroid: false,
        appleKey: 'apple_key',
        googleKey: 'google_key',
      );

      expect(webKey, isEmpty);
      expect(unknownKey, isEmpty);
    });
  });

  group('manageSubscriptionsUrlForChannel', () {
    test('商店渠道返回对应商店管理页', () {
      expect(
        manageSubscriptionsUrlForChannel(
          ClientPaymentChannel.appleStore,
          webManageUrl: '',
        ),
        'https://apps.apple.com/account/subscriptions',
      );
      expect(
        manageSubscriptionsUrlForChannel(
          ClientPaymentChannel.googlePlay,
          webManageUrl: '',
        ),
        'https://play.google.com/store/account/subscriptions',
      );
    });

    test('direct 使用 web 管理页，未配置时隐藏', () {
      expect(
        manageSubscriptionsUrlForChannel(
          ClientPaymentChannel.web,
          webManageUrl: 'https://example.com/manage',
        ),
        'https://example.com/manage',
      );
      expect(
        manageSubscriptionsUrlForChannel(
          ClientPaymentChannel.web,
          webManageUrl: '',
        ),
        isNull,
      );
    });
  });
}
