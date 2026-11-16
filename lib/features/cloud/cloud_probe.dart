import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/platform.dart';

class CloudProbe {
  Future<void> run() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw const CapabilityFailure(
        'verification',
        'Verify your email and refresh the session before testing private storage.',
      );
    }
    if (AppConfig.databaseUrl.isEmpty || AppConfig.storageBucket.isEmpty) {
      throw const CapabilityFailure(
        'configuration',
        'Add the database URL and Storage bucket to the local configuration.',
      );
    }
    final reference = FirebaseDatabase.instance.ref(
      'users/${user.uid}/phase1/probe',
    );
    final image = FirebaseStorage.instance.ref(
      'users/${user.uid}/phase1/probe.png',
    );
    final bytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      ),
    );
    await reference.set({'ok': true, 'updatedAt': ServerValue.timestamp});
    try {
      if ((await reference.get()).child('ok').value != true) {
        throw const CapabilityFailure(
          'readback',
          'Database readback did not match.',
        );
      }
      await image.putData(bytes, SettableMetadata(contentType: 'image/png'));
      final read = await image.getData(2048);
      if (read == null || base64Encode(read) != base64Encode(bytes)) {
        throw const CapabilityFailure(
          'readback',
          'Image readback did not match.',
        );
      }
    } finally {
      await reference.remove();
      try {
        await image.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
  }
}

final cloudProbeProvider = Provider((ref) => CloudProbe());
