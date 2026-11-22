import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../application/profile_data.dart';

class FileProfileCache implements ProfileCache {
  FileProfileCache(this.project, {Future<Directory> Function()? location})
    : _location = location ?? getApplicationSupportDirectory;

  final String project;
  final Future<Directory> Function() _location;
  Future<void> _queue = Future.value();

  String _key(String input) => sha256.convert(utf8.encode(input)).toString();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Directory> _root() async =>
      Directory('${(await _location()).path}/bimbi-profile/${_key(project)}');

  Future<File> _file(String uid, String name) async =>
      File('${(await _root()).path}/${_key(uid)}/$name');

  @override
  Future<void> retain(String? uid) => _serialize(() async {
    final root = await _root();
    if (!await root.exists()) return;
    final keep = uid == null ? null : '${root.path}/${_key(uid)}';
    await for (final folder in root.list(followLinks: false)) {
      if (folder.path != keep) await folder.delete(recursive: true);
    }
  });

  @override
  Future<String?> readName(String uid) => _serialize(() async {
    final file = await _file(uid, 'name');
    if (!await file.exists() || await file.length() > 200) return null;
    return file.readAsString();
  });

  @override
  Future<void> writeName(String uid, String? name) => _serialize(() async {
    await _replace(
      await _file(uid, 'name'),
      name == null ? null : utf8.encode(name),
    );
  });

  @override
  Future<Uint8List?> readPhoto(String uid) => _serialize(() async {
    final file = await _file(uid, 'avatar.jpg');
    if (!await file.exists()) return null;
    final age = DateTime.now().difference(await file.lastModified());
    if (age.isNegative ||
        age >= const Duration(days: 7) ||
        await file.length() > avatarMaxBytes) {
      await file.delete();
      return null;
    }
    return file.readAsBytes();
  });

  @override
  Future<void> writePhoto(String uid, Uint8List? photo) => _serialize(() async {
    await _replace(await _file(uid, 'avatar.jpg'), photo);
  });

  Future<void> _replace(File file, List<int>? bytes) async {
    if (bytes == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }
}
