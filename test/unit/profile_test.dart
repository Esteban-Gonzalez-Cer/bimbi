import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bimbi/features/auth/auth_adapter.dart';
import 'package:bimbi/features/profile/application/cloud_profile.dart';
import 'package:bimbi/features/profile/application/profile_data.dart';
import 'package:bimbi/features/profile/infrastructure/file_profile_cache.dart';
import 'package:bimbi/features/profile/infrastructure/firebase_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  bool get emailVerified => true;
  @override
  String? get displayName => null;
  @override
  List<UserInfo> get providerData => [];
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _Token();
}

class _Token extends Fake implements IdTokenResult {
  @override
  String get signInProvider => 'password';
  @override
  Map<String, dynamic> get claims => {'bimbiAuthOrigin': 'password'};
}

class _Repository extends Fake implements ProfileRepository {
  _Repository() {
    connected = StreamController<bool>.broadcast(
      onListen: () {
        if (!listening.isCompleted) listening.complete();
      },
    );
  }

  late final StreamController<bool> connected;
  final listening = Completer<void>();
  final namesChanged = StreamController<String?>.broadcast();
  final alicePhoto = Completer<Uint8List?>();
  final saved = Completer<void>();
  int abandoned = 0;
  int nameWrites = 0;

  @override
  Stream<bool> get connection => connected.stream;
  @override
  Stream<String?> names(String uid) => namesChanged.stream;
  @override
  Future<void> saveName(String uid, String name) {
    nameWrites++;
    return saved.future;
  }

  @override
  Future<void> abandonPendingWrites() async => abandoned++;

  @override
  Future<Uint8List?> loadAvatar(String uid) async =>
      uid == 'alice' ? alicePhoto.future : null;
}

Future<void> _drain() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('cache survives recreation, expires by age and is removed on account switch', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bimbi-profile-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final photo = Uint8List.fromList([1, 2, 3]);
    final cache = FileProfileCache(
      'demo-bimbi',
      location: () async => directory,
    );
    await cache.writeName('alice', 'Alice');
    await cache.writePhoto('alice', photo);
    final reopened = FileProfileCache(
      'demo-bimbi',
      location: () async => directory,
    );
    expect(await reopened.readPhoto('alice'), photo);
    expect(await reopened.readPhoto('bob'), isNull);
    expect(await reopened.readName('alice'), 'Alice');
    final files = await directory.list(recursive: true).toList();
    final avatar = files.whereType<File>().singleWhere(
      (file) => file.path.endsWith('avatar.jpg'),
    );
    await avatar.setLastModified(
      DateTime.now().subtract(const Duration(days: 8)),
    );
    expect(await reopened.readPhoto('alice'), isNull);
    expect(await avatar.exists(), isFalse);
    await reopened.retain('bob');
    expect(await cache.readName('alice'), isNull);
  });

  test('photo conversion bounds the longest edge and output bytes', () {
    final original = image.Image(width: 900, height: 600, numChannels: 4);
    final jpeg = normalizeAvatar(image.encodePng(original));
    final decoded = image.decodeJpg(jpeg)!;
    expect(decoded.width, 512);
    expect(decoded.height, 341);
    expect(jpeg.length, lessThanOrEqualTo(avatarMaxBytes));
    expect(() => normalizeAvatar(Uint8List(6)), throwsFormatException);
  });

  test('name stays pending until confirmed and a switched account ignores late media', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bimbi-profile-session-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = _Repository();
    final cache = FileProfileCache(
      'demo-bimbi',
      location: () async => directory,
    );
    final sessions = StreamController<User?>();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        profileCacheProvider.overrideWithValue(cache),
        sessionProvider.overrideWith((_) => sessions.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await sessions.close();
      await repository.connected.close();
      await repository.namesChanged.close();
    });
    final controller = container.read(cloudProfileProvider.notifier);
    final active = container.listen(cloudProfileProvider, (_, _) {});
    addTearDown(active.close);
    CloudProfileState state() => container.read(cloudProfileProvider);
    sessions.add(_User('alice'));
    // Wait for the disk-backed session transition to attach Firebase streams.
    await repository.listening.future.timeout(const Duration(seconds: 2));
    repository.connected.add(false);
    await _drain();

    final save = controller.saveName('Synced name');
    expect(repository.nameWrites, 1);
    expect(state().savingName, isTrue);
    expect(state().name, isEmpty);
    repository.connected.add(true);
    repository.namesChanged.add('Synced name');
    repository.saved.complete();
    await save.timeout(const Duration(seconds: 2));
    await _drain();
    expect(state().name, 'Synced name');
    expect(state().savingName, isFalse);

    sessions.add(_User('bob'));
    await _drain();
    repository.alicePhoto.complete(Uint8List.fromList([5, 6, 7]));
    await _drain();
    expect(state().uid, 'bob');
    expect(state().name, isEmpty);
    expect(state().photo, isNull);
    expect(await cache.readPhoto('alice'), isNull);
  });
}
