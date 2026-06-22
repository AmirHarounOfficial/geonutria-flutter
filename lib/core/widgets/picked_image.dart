import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Displays an [XFile] picked via image_picker in a platform-agnostic way.
///
/// `Image.file` relies on `dart:io` and doesn't work on web, so we read the
/// bytes and use [Image.memory] — which works on web, Android and iOS alike.
class PickedImage extends StatelessWidget {
  const PickedImage({super.key, required this.file, this.fit = BoxFit.cover});

  final XFile file;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.memory(snap.data!, fit: fit, width: double.infinity);
      },
    );
  }
}
