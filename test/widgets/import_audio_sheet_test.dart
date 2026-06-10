import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/widgets/import_audio_sheet.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _ImmediateAudioImportController extends AudioImportController {
  _ImmediateAudioImportController({this.fail = false});

  final bool fail;

  @override
  AudioImportState build() => const AudioImportIdle();

  @override
  Future<AudioItem?> importFromUrl(String url, {String? collectionId}) async {
    if (fail) {
      state = const AudioImportFailed(
        AudioImportException(AudioImportFailureCode.invalidUrl, 'invalid'),
      );
      return null;
    }
    final item = AudioItem(
      id: 'url-audio',
      name: 'URL Audio',
      audioPath: 'audios/imported/url.mp3',
      addedDate: DateTime(2026, 1, 1),
    );
    state = AudioImportCompleted(item);
    return item;
  }
}

Widget _buildApp({bool failImport = false}) {
  return createTestApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => showImportAudioSheet(context),
            child: const Text('Open Import'),
          ),
        ),
      ),
    ),
    overrides: [
      analyticsOverride(),
      appSettingsProvider.overrideWith(
        () => TestAppSettings(const AppSettingsState(locale: Locale('en'))),
      ),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      audioImportControllerProvider.overrideWith(
        () => _ImmediateAudioImportController(fail: failImport),
      ),
    ],
  );
}

void main() {
  void mockClipboardText(String? text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return text == null ? null : <String, dynamic>{'text': text};
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('导入方式 sheet 提供本地文件和链接入口', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import Audio'), findsOneWidget);
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
  });

  testWidgets('导入方式入口使用独立边框分隔', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    final localOption = find.byKey(const ValueKey('import-option-local-file'));
    final linkOption = find.byKey(const ValueKey('import-option-direct-url'));
    expect(localOption, findsOneWidget);
    expect(linkOption, findsOneWidget);

    final localMaterial = tester.widget<Material>(
      find.descendant(of: localOption, matching: find.byType(Material)),
    );
    final linkMaterial = tester.widget<Material>(
      find.descendant(of: linkOption, matching: find.byType(Material)),
    );
    final localShape = localMaterial.shape;
    final linkShape = linkMaterial.shape;
    expect(localShape, isA<RoundedRectangleBorder>());
    expect(linkShape, isA<RoundedRectangleBorder>());
    expect(
      (localShape! as RoundedRectangleBorder).side.style,
      BorderStyle.solid,
    );
    expect(
      (linkShape! as RoundedRectangleBorder).side.style,
      BorderStyle.solid,
    );

    final localBottom = tester.getBottomLeft(localOption).dy;
    final linkTop = tester.getTopLeft(linkOption).dy;
    expect(linkTop - localBottom, 12);
  });

  testWidgets('链接入口显示 URL 表单且空输入禁用提交', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    expect(find.text('Audio link'), findsOneWidget);
    expect(find.text('Paste Link'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Download and Import'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('本地文件入口使用全宽次级按钮', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from File'));
    await tester.pumpAndSettle();

    final selectButton = find.byKey(const ValueKey('select-audio-file-button'));
    expect(selectButton, findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Select Audio File'),
      findsNothing,
    );
    expect(
      find.descendant(
        of: selectButton,
        matching: find.byIcon(Icons.audio_file_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Select Audio File'),
      findsOneWidget,
    );

    final sheetWidth = tester.getSize(find.byType(ImportAudioFlowSheet)).width;
    final selectWidth = tester.getSize(selectButton).width;
    expect(selectWidth, greaterThan(sheetWidth - 40));
  });

  testWidgets('链接导入页可从剪切板粘贴链接并启用提交', (tester) async {
    mockClipboardText('https://example.com/audio.mp3');
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste Link'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'https://example.com/audio.mp3');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Download and Import'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('链接导入页剪切板没有链接时显示内联提示', (tester) async {
    mockClipboardText('not a link');
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste Link'));
    await tester.pump();

    expect(
      find.text('Clipboard does not contain a valid link'),
      findsOneWidget,
    );
  });

  testWidgets('链接导入页可返回导入方式选择页', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    expect(find.text('Audio link'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
    expect(find.text('Audio link'), findsNothing);
  });

  testWidgets('链接导入页空闲时底部返回按钮回到导入方式选择页', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Back'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Import Audio'), findsOneWidget);
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
    expect(find.text('Audio link'), findsNothing);
  });

  testWidgets('链接导入失败时留在表单并显示内联错误', (tester) async {
    await tester.pumpWidget(_buildApp(failImport: true));
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bad-url');
    await tester.pump();
    await tester.tap(find.text('Download and Import'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid audio link'), findsOneWidget);
    expect(find.text('Audio link'), findsOneWidget);
  });

  testWidgets('链接导入成功后在同一流程内显示完成和字幕操作', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://example.com/a.mp3');
    await tester.pump();
    await tester.tap(find.text('Download and Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import complete'), findsOneWidget);
    expect(find.text('URL Audio'), findsOneWidget);
    expect(find.text('Add Subtitle'), findsOneWidget);
  });
}
