import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';

/// Shows a bottom sheet to pick an image from the camera or gallery and returns
/// the selected [XFile] (or null if cancelled).
Future<XFile?> pickImage(BuildContext context) async {
  final picker = ImagePicker();
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(ctx.tr('cancel')),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
}
