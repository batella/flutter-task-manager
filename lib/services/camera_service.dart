import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        // availableCameras is not supported/required on web for our fallback
        _cameras = [];
      } else {
        _cameras = await availableCameras();
      }
      print('✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)');
    } catch (e) {
      print('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  Future<String?> takePicture(BuildContext context) async {
    // If there are no cameras available (or we're on web), fallback to
    // ImagePicker camera mode which works on web and will ask the browser
    // for camera access or fallback to file picker.
    if (!hasCameras) {
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (xfile == null) return null;
        final saved = await savePicture(xfile);
        return saved;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao acessar câmera: $e'), backgroundColor: Colors.red),
          );
        }
        return null;
      }
    }

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (e) {
      print('❌ Erro ao abrir câmera (camera plugin), fallback: $e');
      // Try fallback to ImagePicker camera (works on more devices / web)
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (xfile == null) return null;
        final saved = await savePicture(xfile);
        return saved;
      } catch (e2) {
        print('❌ Erro no fallback da câmera: $e2');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    } finally {
      controller.dispose();
    }
  }

  /// Seleciona múltiplas imagens da galeria e salva no storage interno
  Future<List<String>?> pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
  final images = await picker.pickMultiImage(imageQuality: 85);
  if (images.isEmpty) return null;

      final savedPaths = <String>[];
      for (final img in images) {
        final saved = await savePicture(img);
        savedPaths.add(saved);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${savedPaths.length} imagem(ns) importada(s) da galeria')),
      );

      return savedPaths;
    } catch (e) {
      print('❌ Erro ao selecionar da galeria: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar da galeria: $e')),
        );
      }
      return null;
    }
  }

  /// Saves the picked [image] and returns a string that can be used to
  /// display the image later. On web/mobile we store a data: URI with
  /// base64-encoded bytes. This avoids relying on platform-specific
  /// filesystem APIs and prevents MissingPluginException on web.
  Future<String> savePicture(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final ext = path.extension(image.name).toLowerCase();
      final mime = ext == '.png' ? 'image/png' : 'image/jpeg';
      final base64Data = base64Encode(bytes);
      final dataUri = 'data:$mime;base64,$base64Data';
      // We deliberately do not write to disk. Storing as data URI keeps the
      // code simple and works on web and mobile. If you prefer filesystem
      // storage on mobile, we can implement that later with conditional
      // imports.
      print('✅ Foto processada (data URI) size=${bytes.length} bytes');
      return dataUri;
    } catch (e) {
      print('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      // We store images as data URIs (or file paths for older entries).
      // Deletion is a best-effort: if it's a data URI there's nothing to
      // remove from disk. For file paths we attempt to delete, but to keep
      // this file free of dart:io (which breaks web builds) we simply
      // return true here. The filesystem cleanup can be implemented later
      // with platform-specific code if needed.
      return true;
    } catch (e) {
      print('❌ Erro ao deletar foto: $e');
      return false;
    }
  }
}