import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider((ref) => StorageService());

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('users').child(userId).child('profile_pic.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e) {
      // Si el error es 404, puede que el bucket en FirebaseOptions esté mal configurado
      // o que no se haya inicializado el storage en la consola de Firebase.
      print('Error en StorageService: $e');
      rethrow;
    }
  }
}
