import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import '../../../../core/constants/app_colors.dart';
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

      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  /// Show photo source selection dialog
  void _showPhotoSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build circular avatar with camera overlay
  Widget _buildAvatarPicker(BuildContext context, bool isDark) {
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: isDark
                      ? AppColors.surfaceDark
                      : Colors.grey.shade200,
                  backgroundImage: hasPendingLocalImage
                      ? FileImage(_pendingImageFile!)
                      : (photoURL != null && photoURL.toString().isNotEmpty)
                      ? NetworkImage(photoURL)
                      : null,
                  child:
                      (!hasPendingLocalImage &&
                          (photoURL == null || photoURL.toString().isEmpty))
                      ? const Icon(Icons.person, size: 60)
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              // Loading indicator
              if (isLoading)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A11CB)),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 24,
          right: 24,
          top: 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Edit Profile",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Photo picker avatar
              Center(child: _buildAvatarPicker(context, isDark)),
              const SizedBox(height: 30),

              ProfileEditField(
                label: "Display Name",
                controller: _nameController,
                icon: Icons.person_outline,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              ProfileEditField(
                label: "Bio",
                controller: _bioController,
                icon: Icons.info_outline,
                isDark: isDark,
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              _buildSaveButton(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return InkWell(
      onTap: () {
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
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "Save Changes",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
