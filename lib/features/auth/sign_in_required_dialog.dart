import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import 'providers/auth_providers.dart';

/// 在受保护操作前检查登录状态，并复用统一的登录引导交互。
///
/// 已登录时返回 `true`，调用方可以继续原操作；未登录时显示提示，用户确认后
/// 进入登录页，并返回 `false`，避免登录完成后隐式重放原操作。
Future<bool> ensureSignedInForAction({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String message,
}) async {
  if (ref.read(isAuthenticatedProvider)) return true;

  final l10n = AppLocalizations.of(context);
  final shouldOpenLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n?.authSignInButton ?? 'Sign In'),
        ),
      ],
    ),
  );
  if (!context.mounted || shouldOpenLogin != true) return false;

  context.push(AppRoutes.login);
  return false;
}
