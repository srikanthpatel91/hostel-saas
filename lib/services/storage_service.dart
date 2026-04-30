import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  // Mobile-only upload via dart:io File.
  // Path: hostels/{hostelId}/guests/{guestId}/docs/{timestamp}_{type}
  Future<String> uploadGuestDocument({
    required String hostelId,
    required String guestId,
    required String type,
    required File file,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.split('.').last;
    final ref = _storage.ref(
        'hostels/$hostelId/guests/$guestId/docs/${ts}_$type.$ext');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  // Web+mobile upload using XFile bytes — works on all platforms.
  Future<String> uploadXFile({
    required String storagePath,
    required XFile xfile,
  }) async {
    final bytes = await xfile.readAsBytes();
    final mimeType = xfile.mimeType ?? _guessMime(xfile.name);
    final meta = SettableMetadata(contentType: mimeType);
    final task = await _storage.ref(storagePath).putData(bytes, meta);
    return await task.ref.getDownloadURL();
  }

  String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  Future<void> deleteFile(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (_) {}
  }
}
