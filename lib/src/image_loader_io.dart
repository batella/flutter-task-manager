import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';

Widget imageWidgetFromPath(String p, {BoxFit? fit}) {
  if (p.isEmpty) return const SizedBox();
  if (p.startsWith('data:')) {
    try {
      final comma = p.indexOf(',');
      final base64Str = p.substring(comma + 1);
      final bytes = base64Decode(base64Str);
      return Image.memory(bytes, fit: fit ?? BoxFit.cover);
    } catch (e) {
      return const SizedBox();
    }
  }

  // Treat as local file path on non-web platforms
  final file = File(p);
  if (!file.existsSync()) return const SizedBox();
  return Image.file(file, fit: fit ?? BoxFit.cover);
}
