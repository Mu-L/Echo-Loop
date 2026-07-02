/// 句内分词与词级选区纯逻辑测试
library;

import 'package:echo_loop/widgets/practice/sentence_word_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tokenizeSentence', () {
    test('按空白/非空白切分并记录字符区间', () {
      final tokens = tokenizeSentence('Hello, world!');
      expect(tokens.map((t) => t.text).toList(), ['Hello,', ' ', 'world!']);
      expect(tokens[0].start, 0);
      expect(tokens[0].end, 6);
      expect(tokens[1].start, 6);
      expect(tokens[1].end, 7);
      expect(tokens[2].start, 7);
      expect(tokens[2].end, 13);
    });

    test('词判定：含字母/数字为词，纯标点与空白不是词', () {
      final tokens = tokenizeSentence('go — stop... 3rd');
      expect(tokens.map((t) => t.text).toList(), [
        'go',
        ' ',
        '—',
        ' ',
        'stop...',
        ' ',
        '3rd',
      ]);
      expect(tokens[0].isWord, isTrue);
      expect(tokens[1].isWord, isFalse); // 空白
      expect(tokens[2].isWord, isFalse); // 纯标点破折号
      expect(tokens[4].isWord, isTrue); // stop...（含字母）
      expect(tokens[6].isWord, isTrue); // 3rd（含数字）
    });

    test('多空白/换行保留为单个空白 token', () {
      final tokens = tokenizeSentence('a  b\nc');
      expect(tokens.map((t) => t.text).toList(), ['a', '  ', 'b', '\n', 'c']);
    });

    test('空字符串返回空列表', () {
      expect(tokenizeSentence(''), isEmpty);
    });
  });

  group('snapToWordToken', () {
    final tokens = tokenizeSentence('Hello, — world!');
    // tokens: [Hello,(0-6)] [ (6-7)] [—(7-8)] [ (8-9)] [world!(9-15)]

    test('命中词内返回该词', () {
      expect(snapToWordToken(tokens, 2), 0);
      expect(snapToWordToken(tokens, 10), 4);
    });

    test('落在空白/纯标点吸附到最近词', () {
      expect(snapToWordToken(tokens, 6), 0); // 紧邻 Hello,
      expect(snapToWordToken(tokens, 8), 4); // 紧邻 world!（距离 1 < 到 Hello, 的 3）
    });

    test('越界 clamp 到首/末词', () {
      expect(snapToWordToken(tokens, -5), 0);
      expect(snapToWordToken(tokens, 99), 4);
    });

    test('无 word token 返回 -1', () {
      expect(snapToWordToken(tokenizeSentence('— …'), 1), -1);
      expect(snapToWordToken(const [], 0), -1);
    });
  });

  group('wordTokenAtChar', () {
    final tokens = tokenizeSentence('go stop');

    test('词内返回索引，空白返回 -1', () {
      expect(wordTokenAtChar(tokens, 0), 0);
      expect(wordTokenAtChar(tokens, 2), -1); // 空格
      expect(wordTokenAtChar(tokens, 3), 2);
    });

    test('越界返回 -1', () {
      expect(wordTokenAtChar(tokens, 7), -1);
      expect(wordTokenAtChar(tokens, -1), -1);
    });
  });

  group('WordSelection', () {
    test('textOf 截取选区覆盖的原文（含中间标点空白）', () {
      const text = 'give up, on it';
      final tokens = tokenizeSentence(text);
      // tokens: [give(0)] [ ] [up,(2)] [ ] [on(4)] [ ] [it(6)]
      expect(const WordSelection(0, 4).textOf(text, tokens), 'give up, on');
      expect(const WordSelection(2, 2).textOf(text, tokens), 'up,');
    });

    test('charRangeOf 返回字符区间', () {
      const text = 'a bc d';
      final tokens = tokenizeSentence(text);
      expect(const WordSelection(0, 2).charRangeOf(tokens), (0, 4));
    });
  });
}
