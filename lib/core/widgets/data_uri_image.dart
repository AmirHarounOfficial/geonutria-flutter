import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Renders an image from a `data:image/...;base64,...` URI (as returned by the
/// segmentation / palm-count / palm-disease endpoints). Falls back gracefully
/// if the payload can't be decoded.
class DataUriImage extends StatelessWidget {
  const DataUriImage({super.key, required this.dataUri, this.height, this.fit});

  final String dataUri;
  final double? height;
  final BoxFit? fit;

  Uint8List? _decode() {
    final comma = dataUri.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUri.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode();
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(bytes, height: height, fit: fit ?? BoxFit.contain),
    );
  }
}
