import 'dart:typed_data';

const avatarMaxBytes = 256 * 1024;

abstract interface class ProfileRepository {
  Stream<bool> get connection;
  Stream<String?> names(String uid);
  Future<void> saveName(String uid, String name);
  Future<void> abandonPendingWrites();
  Future<Uint8List?> loadAvatar(String uid);
  Future<Uint8List?> loadProviderPhoto(Uri url);
  Future<Uint8List?> pickPhoto();
  Future<void> saveAvatar(String uid, Uint8List image);
  Future<void> removeAvatar(String uid);
}

abstract interface class ProfileCache {
  Future<void> retain(String? uid);
  Future<String?> readName(String uid);
  Future<void> writeName(String uid, String? name);
  Future<Uint8List?> readPhoto(String uid);
  Future<void> writePhoto(String uid, Uint8List? photo);
}
