import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../../../core/platform.dart';
import '../application/profile_data.dart';

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository(this.database, this.storage);

  final FirebaseDatabase? database;
  final FirebaseStorage? storage;

  static const _timeout = Duration(seconds: 12);
  static const _maxSource = 12 * 1024 * 1024;

  Reference _photo(String uid) =>
      (storage ??
              (throw const CapabilityFailure(
                'configuration',
                'Photo storage is unavailable in this build.',
              )))
          .ref('users/$uid/avatar.jpg');

  DatabaseReference _name(String uid) =>
      (database ??
              (throw const CapabilityFailure(
                'configuration',
                'Profile sync is unavailable in this build.',
              )))
          .ref('users/$uid/profile/displayName');

  @override
  Stream<bool> get connection =>
      database
          ?.ref('.info/connected')
          .onValue
          .map((e) => e.snapshot.value == true) ??
      Stream.value(false);

  @override
  Stream<String?> names(String uid) => database == null
      ? const Stream.empty()
      : _name(uid).onValue.map((event) {
          final value = event.snapshot.value;
          return value is String ? value : null;
        });

  @override
  Future<void> saveName(String uid, String name) async {
    final result = await _name(uid)
        .runTransaction((_) => Transaction.success(name), applyLocally: false);
    if (!result.committed) {
      throw const CapabilityFailure('aborted', 'Name change was not saved.');
    }
  }

  @override
  Future<void> abandonPendingWrites() async {
    await database?.purgeOutstandingWrites();
  }

  @override
  Future<Uint8List?> loadAvatar(String uid) async {
    try {
      final bytes = await _photo(uid).getData(avatarMaxBytes).timeout(_timeout);
      if (bytes == null) return null;
      return await compute(normalizeAvatar, bytes);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List?> loadProviderPhoto(Uri url) async {
    if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
      return null;
    }
    final client = http.Client();
    try {
      return await _download(client, url).timeout(_timeout);
    } finally {
      client.close();
    }
  }

  Future<Uint8List?> _download(http.Client client, Uri url) async {
    final request = http.Request('GET', url)..followRedirects = false;
    final response = await client.send(request);
    if (response.statusCode != 200) {
      if (response.statusCode == 404 || response.statusCode == 410) return null;
      throw const CapabilityFailure(
        'photo_unavailable',
        'Profile photo unavailable.',
      );
    }
    const limit = 2 * 1024 * 1024;
    if ((response.contentLength ?? 0) > limit) {
      throw const FormatException('Photo exceeds download limit.');
    }
    final output = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (output.length + chunk.length > limit) {
        throw const FormatException('Photo exceeds download limit.');
      }
      output.add(chunk);
    }
    return compute(normalizeAvatar, output.takeBytes());
  }

  @override
  Future<Uint8List?> pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > _maxSource) {
      throw const FormatException('Choose a photo smaller than 12 MB.');
    }
    return compute(normalizeAvatar, await file.readAsBytes());
  }

  @override
  Future<void> saveAvatar(String uid, Uint8List bytes) async {
    final upload = _photo(uid)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    await upload.timeout(
      const Duration(seconds: 30),
      onTimeout: () async {
        await upload.cancel();
        throw TimeoutException('Photo upload could not be confirmed.');
      },
    );
  }

  @override
  Future<void> removeAvatar(String uid) async {
    try {
      await _photo(uid).delete().timeout(_timeout);
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}

Uint8List normalizeAvatar(Uint8List input) {
  final decoder = image.findDecoderForData(input);
  final info = decoder?.startDecode(input);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 24 * 1000 * 1000) {
    throw const FormatException(
      'Choose a supported photo under 24 megapixels.',
    );
  }
  final frame = decoder!.decodeFrame(0);
  if (frame == null) {
    throw const FormatException('The photo could not be opened.');
  }
  final oriented = image.bakeOrientation(frame);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest <= 512
      ? oriented
      : image.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 512 : null,
          height: oriented.height > oriented.width ? 512 : null,
          interpolation: image.Interpolation.average,
        );

  // A new RGB canvas flattens transparency and discards the original metadata.
  final clean = image.Image(width: resized.width, height: resized.height)
    ..clear(image.ColorRgb8(255, 255, 255));
  image.compositeImage(clean, resized);
  for (final quality in [88, 74, 60, 45]) {
    final jpeg = image.encodeJpg(clean, quality: quality);
    if (jpeg.length <= avatarMaxBytes) return jpeg;
  }
  throw const FormatException('The photo could not fit the upload limit.');
}
