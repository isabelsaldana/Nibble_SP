import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _st = FirebaseStorage.instance;

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,                  // e.g. "recipes/<uid>/<id>.jpg"
    String contentType = 'image/jpeg',
  }) async {
    final ref = _st.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
