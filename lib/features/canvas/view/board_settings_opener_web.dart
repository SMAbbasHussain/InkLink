import 'package:flutter/material.dart';

import '../../../core/utils/app_snackbar.dart';

/// Web version of [openBoardSettings]: the full settings screen (members,
/// roles, delete) stays in the mobile app for now.
void openBoardSettings(
  BuildContext context, {
  required String boardId,
  required String currentTitle,
}) {
  AppSnackBar.showMessage(
    context,
    'Board settings are available in the InkLink mobile app.',
  );
}
