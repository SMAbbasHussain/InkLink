import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/utils/app_error_formatter.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../theme/chat_theme.dart';

/// Lets the user pick a square-ish image from the gallery or camera, uploads
/// it through the existing `uploadProfilePhoto` callable (it only stores the
/// image and returns its public URL) and returns that URL.
///
/// Returns null when the user cancels or the upload fails.
Future<String?> pickAndUploadGroupAvatar(BuildContext context) async {
  final colors = ChatTheme.colorsOf(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: colors.accent),
            title: Text(
              'Choose from gallery',
              style: TextStyle(color: colors.textPrimary),
            ),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: colors.accent),
            title: Text(
              'Take a photo',
              style: TextStyle(color: colors.textPrimary),
            ),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  try {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (context.mounted) {
          AppSnackBar.showMessage(
            context,
            'Camera permission is required to take a photo.',
          );
        }
        return null;
      }
    }

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (picked == null || !context.mounted) return null;

    final extension = picked.name.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      if (context.mounted) {
        AppSnackBar.showMessage(
          context,
          'Only PNG, JPEG, and JPG images are supported.',
        );
      }
      return null;
    }

    final cloudFunctions = context.read<CloudFunctionsService>();

    final rawBytes = await File(picked.path).readAsBytes();
    final decoded = img.decodeImage(rawBytes);
    final uploadBytes = decoded == null
        ? rawBytes
        : img.encodeJpg(
            img.copyResize(decoded, width: 512, maintainAspect: true),
            quality: 85,
          );

    final result = await cloudFunctions
        .httpsCallable('uploadProfilePhoto')
        .call({
          'imageData': base64Encode(uploadBytes),
          'filename': 'group_avatar.jpg',
        });

    final photoUrl = result.data['photoUrl']?.toString() ?? '';
    if (photoUrl.isEmpty) {
      throw Exception('Upload did not return an image URL.');
    }
    return photoUrl;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showMessage(
        context,
        AppErrorFormatter.cleanMessage(
          e,
          fallback: 'Could not upload the group photo. Please try again.',
        ),
      );
    }
    return null;
  }
}
