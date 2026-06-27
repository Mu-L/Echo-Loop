import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary/web_dictionary_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// 配置驱动网页词典源的纯逻辑测试：
/// 遍历全部配置，校验 id 稳定、可禁用、URL 拼接与编码、结果 sourceId 一致。
void main() {
  test('配置表非空且 id 唯一', () {
    expect(kWebDictConfigs, isNotEmpty);
    final ids = kWebDictConfigs.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 必须唯一');
  });

  test('已确认的 8 个网页源都在、Macmillan/欧陆 不在', () {
    final ids = kWebDictConfigs.map((c) => c.id).toSet();
    expect(ids, {
      'cambridge',
      'oxford',
      'longman',
      'merriamWebster',
      'collins',
      'vocabulary',
      'wiktionary',
      'youdao',
    });
    expect(ids.contains('macmillan'), isFalse);
    expect(ids.contains('eudic'), isFalse);
  });

  for (final config in kWebDictConfigs) {
    group('WebDictionarySource(${config.id})', () {
      final source = WebDictionarySource(config);

      test('源契约：id 稳定、可禁用、需联网', () {
        expect(source.id, config.id);
        expect(source.canBeDisabled, isTrue);
        expect(source.requiresNetwork, isTrue);
        expect(source.icon, config.icon);
      });

      test('lookup 返回 WebDictResult 且 sourceId 一致', () async {
        final result = await source.lookup(
          const DictionaryLookupRequest(word: 'nice'),
        );
        expect(result, isA<WebDictResult>());
        final web = result! as WebDictResult;
        expect(web.sourceId, config.id);
        expect(web.word, 'nice');
        expect(web.url.toString(), config.buildUrl('nice'));
      });

      test('查询词被规整为小写并 URL 编码', () async {
        final result =
            await source.lookup(
                  const DictionaryLookupRequest(word: '  A Posteriori '),
                )
                as WebDictResult;
        // trim + toLowerCase + 空格编码为 %20
        expect(result.url.toString(), contains('a%20posteriori'));
        expect(result.url.toString(), isNot(contains(' ')));
      });
    });
  }
}
