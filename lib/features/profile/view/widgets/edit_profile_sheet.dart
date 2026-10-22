import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../bloc/profile_bloc.dart';
import './profile_edit_field.dart';

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileSheet({super.key, required this.userData});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _pendingImageData;
  String? _pendingFilename;
  File? _pendingImageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userData['displayName'],
    );
    _bioController = TextEditingController(text: widget.userData['bio'] ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Compress image and convert to base64
  Future<String> _compressAndEncodeImage(File imageFile) async {
    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();

      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Compress the image (max width: 800px, quality reduced to save bandwidth)
      final compressedImage = img.copyResize(
        image,
        width: 800,
        maintainAspect: true,
      );

      // Encode back to JPEG with reduced quality
      final compressedBytes = img.encodeJpg(compressedImage, quality: 80);

      // Convert to base64
      return base64Encode(compressedBytes);
    } catch (e) {
      throw Exception('Failed to compress image: $e');
    }
  }

  /// Handle photo selection from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions based on source
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission is required to take photos'),
              ),
            );
          }
          return;
        }
      } else if (source == ImageSource.gallery) {
        final photoStatus = await Permission.photos.request();
        if (!photoStatus.isGranted) {
          // Fallback for older Android versions
          final readStatus = await Permission.storage.request();
          if (!readStatus.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Photo library access is required to select photos',
                  ),
                ),
              );
            }
            return;
          }
        }
      }

      // Pick image
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      // Validate file extension (FR02-04)
      final ext = pickedFile.name.toLowerCase().split('.').last;
      if (!['jpg', 'jpeg', 'png'].contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid image format. Only PNG, JPEG, and JPG images are supported.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate magic bytes (FR02-04)
      final rawBytes = await File(pickedFile.path).readAsBytes();
      final isJpeg = rawBytes.length >= 3 &&
          rawBytes[0] == 0xFF &&
          rawBytes[1] == 0xD8 &&
          rawBytes[2] == 0xFF;
      final isPng = rawBytes.length >= 8 &&
          rawBytes[0] == 0x89 &&
          rawBytes[1] == 0x50 &&
          rawBytes[2] == 0x4E &&
          rawBytes[3] == 0x47 &&
          rawBytes[4] == 0x0D &&
          rawBytes[5] == 0x0A &&
          rawBytes[6] == 0x1A &&
          rawBytes[7] == 0x0A;

      if (!isJpeg && !isPng) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid image content. Only valid PNG, JPEG, and JPG images are accepted.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: context.ink.accent),
        ),
      );

      try {
        // Compress and encode image
        final imageData = await _compressAndEncodeImage(File(pickedFile.path));
        final filename = pickedFile.name;

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        // Keep the selected image local until the user confirms with Save.
        setState(() {
          _pendingImageData = imageData;
          _pendingFilename = filename;
          _pendingImageFile = File(pickedFile.path);
        });
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: ${e.toString()}')),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isNoCamera = e.code == 'no_available_camera' ||
          (e.message?.toLowerCase().contains('no camera') ?? false);
      final isDenied = e.code == 'camera_access_denied' ||
          (e.message?.toLowerCase().contains('denied') ?? false);

      final message = isNoCamera
          ? 'No camera available on this device.'
          : isDenied
              ? 'Camera permission was denied.'
              : 'Failed to access camera: ${e.message ?? e.code}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: isNoCamera
              ? SnackBarAction(
                  label: 'Choose Gallery',
                  onPressed: () => _pickImage(ImageSource.gallery),
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  /// Show photo source selection dialog
  void _showPhotoSourceDialog(BuildContext context) {
    final tokens = context.ink;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.s16,
          InkSpacing.s8,
          InkSpacing.s16,
          InkSpacing.s24,
        ),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
                decoration: BoxDecoration(
                  color: tokens.inkMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(LucideIcons.camera, color: tokens.ink),
                title: Text('Take a Photo', style: InkType.body(tokens.ink)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.image, color: tokens.ink),
                title: Text('Choose from Gallery', style: InkType.body(tokens.ink)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build circular avatar with camera overlay
  Widget _buildAvatarPicker(BuildContext context) {
    final tokens = context.ink;
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final isLoading = state is ProfilePhotoUploading;
        Map<String, dynamic> resolvedUserData = widget.userData;
        if (state is ProfileLoaded) {
          resolvedUserData = state.userData;
        } else if (state is ProfilePhotoUploading) {
          resolvedUserData = state.userData;
        }

        final photoURL = resolvedUserData['photoURL'];
        final hasPendingLocalImage = _pendingImageFile != null;

        return GestureDetector(
          onTap: isLoading ? null : () => _showPhotoSourceDialog(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.accent,
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: tokens.field,
                  backgroundImage: hasPendingLocalImage
                      ? FileImage(_pendingImageFile!)
                      : (photoURL != null && photoURL.toString().isNotEmpty)
                      ? NetworkImage(photoURL)
                      : null,
                  child:
                      (!hasPendingLocalImage &&
                          (photoURL == null || photoURL.toString().isEmpty))
                      ? Icon(LucideIcons.user, size: 60, color: tokens.inkMuted)
                      : null,
                ),
              ),
              // Camera icon overlay
              if (!isLoading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.accent,
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              // Loading indicator
              if (isLoading)
                CircularProgressIndicator(color: tokens.accent),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.s16,
          InkSpacing.s8,
          InkSpacing.s16,
          InkSpacing.s24,
        ),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + InkSpacing.s20,
            left: InkSpacing.s24,
            right: InkSpacing.s24,
            top: InkSpacing.s20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.inkMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: InkSpacing.s24),
                Text("Edit Profile", style: InkType.headline(tokens.ink).copyWith(fontSize: 22)),
                const SizedBox(height: InkSpacing.s24 + 6),

                Center(child: _buildAvatarPicker(context)),
                const SizedBox(height: InkSpacing.s24 + 6),

                ProfileEditField(
                  label: "Display Name",
                  controller: _nameController,
                  icon: LucideIcons.user,
                ),
                const SizedBox(height: InkSpacing.s20),
                ProfileEditField(
                  label: "Bio",
                  controller: _bioController,
                  icon: LucideIcons.info,
                  maxLines: 3,
                ),
                const SizedBox(height: InkSpacing.s32),

                _buildSaveButton(context),
                const SizedBox(height: InkSpacing.s20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return InkButton.primary(
      label: 'Save Changes',
      onPressed: () {
        context.read<ProfileBloc>().add(
          SaveProfileChangesRequested(
            name: _nameController.text.trim(),
            bio: _bioController.text.trim(),
            imageData: _pendingImageData,
            filename: _pendingFilename,
          ),
        );

        Navigator.pop(context);
      },
    );
  }
}
