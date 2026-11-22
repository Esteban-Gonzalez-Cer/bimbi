import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../core/config.dart';
import '../../auth/auth_adapter.dart';
import '../infrastructure/file_profile_cache.dart';
import '../infrastructure/firebase_profile.dart';
import 'profile_data.dart';

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  return FirebaseProfileRepository(
    AppConfig.profileDatabaseConfigured ? FirebaseDatabase.instance : null,
    AppConfig.profileStorageConfigured ? FirebaseStorage.instance : null,
  );
});

final profileCacheProvider = Provider<ProfileCache>(
  (ref) => FileProfileCache(AppConfig.firebaseProject),
);

class CloudProfileState {
  const CloudProfileState({
    this.uid,
    this.verified = false,
    this.name = '',
    this.photo,
    this.online = false,
    this.canEditAvatar = false,
    this.savingName = false,
    this.savingPhoto = false,
    this.nameStatus = '',
    this.photoStatus = '',
  });

  final String? uid;
  final bool verified;
  final String name;
  final Uint8List? photo;
  final bool online;
  final bool canEditAvatar;
  final bool savingName;
  final bool savingPhoto;
  final String nameStatus;
  final String photoStatus;

  CloudProfileState copyWith({
    String? name,
    Uint8List? photo,
    bool clearPhoto = false,
    bool? online,
    bool? canEditAvatar,
    bool? savingName,
    bool? savingPhoto,
    String? nameStatus,
    String? photoStatus,
  }) => CloudProfileState(
    uid: uid,
    verified: verified,
    name: name ?? this.name,
    photo: clearPhoto ? null : (photo ?? this.photo),
    online: online ?? this.online,
    canEditAvatar: canEditAvatar ?? this.canEditAvatar,
    savingName: savingName ?? this.savingName,
    savingPhoto: savingPhoto ?? this.savingPhoto,
    nameStatus: nameStatus ?? this.nameStatus,
    photoStatus: photoStatus ?? this.photoStatus,
  );
}

final cloudProfileProvider =
    NotifierProvider<CloudProfileController, CloudProfileState>(
      CloudProfileController.new,
    );

final visibleProfileNameProvider = Provider<String>((ref) {
  final user = ref.watch(sessionProvider).asData?.value;
  if (user == null) return ref.watch(displayNameProvider);
  final profile = ref.watch(cloudProfileProvider);
  if (profile.uid == user.uid && profile.name.isNotEmpty) return profile.name;
  return user.displayName?.trim() ?? '';
});

class CloudProfileController extends Notifier<CloudProfileState> {
  StreamSubscription<bool>? _connection;
  StreamSubscription<String?>? _names;
  User? _user;
  int _session = 0;
  int _photoRequest = 0;
  bool _started = false;

  ProfileRepository? get _repository => ref.read(profileRepositoryProvider);
  ProfileCache get _cache => ref.read(profileCacheProvider);

  bool _current(int session) => ref.mounted && _session == session;

  @override
  CloudProfileState build() {
    ref.listen(sessionProvider, (_, next) {
      if (next case AsyncData(:final value)) unawaited(_activate(value));
    });
    final initial = ref.read(sessionProvider);
    if (initial is AsyncData<User?>) {
      scheduleMicrotask(() {
        if (ref.mounted && !_started) unawaited(_activate(initial.value));
      });
    }
    ref.onDispose(() {
      _session++;
      unawaited(_connection?.cancel());
      unawaited(_names?.cancel());
    });
    return const CloudProfileState();
  }

  Future<void> _activate(User? user) async {
    final repository = _repository;
    if (repository == null) return;
    final uid = user?.uid;
    final verified = user?.emailVerified ?? false;
    _user = user;
    if (_started && state.uid == uid && state.verified == verified) return;
    _started = true;
    final abandonName = state.savingName;
    final generation = ++_session;
    final oldConnection = _connection;
    final oldNames = _names;
    _connection = null;
    _names = null;
    state = CloudProfileState(uid: uid, verified: verified);
    await Future.wait([
      if (oldConnection != null) oldConnection.cancel(),
      if (oldNames != null) oldNames.cancel(),
    ]);
    if (!_current(generation)) return;
    if (abandonName) await _try(() => repository.abandonPendingWrites());
    if (!_current(generation)) return;

    // Serialize this deletion behind prior cache writes before reading a new account.
    await _try(() => _cache.retain(verified ? uid : null));
    if (!_current(generation) || uid == null) return;
    if (verified) {
      final name = await _try(() => _cache.readName(uid));
      final photo = await _try(() => _cache.readPhoto(uid));
      if (!_current(generation)) return;
      state = state.copyWith(name: name, photo: photo);
      _names = repository
          .names(uid)
          .listen(
            (name) {
              if (!_current(generation)) return;
              state = state.copyWith(name: name ?? '');
              unawaited(_try(() => _cache.writeName(uid, name)));
            },
            onError: (Object error) {
              if (!_current(generation)) return;
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                state = state.copyWith(name: '');
                unawaited(_try(() => _cache.writeName(uid, null)));
              }
              state = state.copyWith(
                nameStatus: 'Profile sync unavailable. Try again.',
              );
            },
          );
    }
    _connection = repository.connection.distinct().listen((online) {
      if (!_current(generation)) return;
      state = state.copyWith(online: online);
      if (online) unawaited(refreshPhoto(refreshToken: true));
    });
    if (!verified) unawaited(refreshPhoto());
  }

  Future<void> _refreshAuthorization(
    User user,
    bool refreshToken,
    int generation,
    int request,
  ) async {
    final token = await _try(
      () => user
          .getIdTokenResult(refreshToken)
          .timeout(const Duration(seconds: 8)),
    );
    if (!_current(generation) || request != _photoRequest) return;
    if (token == null) return;
    state = state.copyWith(
      canEditAvatar:
          state.verified &&
          token.signInProvider == 'password' &&
          token.claims?['bimbiAuthOrigin'] == 'password',
    );
  }

  Future<void> refreshPhoto({bool refreshToken = false}) async {
    final repository = _repository;
    final user = _user;
    if (repository == null ||
        user == null ||
        state.uid != user.uid ||
        state.savingPhoto) {
      return;
    }
    final generation = _session;
    final request = ++_photoRequest;
    if (state.online) {
      await _refreshAuthorization(user, refreshToken, generation, request);
    }
    if (!_current(generation) ||
        request != _photoRequest ||
        state.savingPhoto) {
      return;
    }

    final federated = user.providerData.where(
      (provider) =>
          provider.providerId == 'google.com' ||
          provider.providerId == 'github.com',
    );
    final useProvider = !state.canEditAvatar && federated.isNotEmpty;
    final providerUrl = useProvider
        ? Uri.tryParse(federated.first.photoURL ?? '')
        : null;
    if (!state.online && (state.verified || !useProvider)) return;
    try {
      final photo = useProvider
          ? (providerUrl == null
                ? null
                : await repository.loadProviderPhoto(providerUrl))
          : (state.verified ? await repository.loadAvatar(user.uid) : null);
      if (!_current(generation) ||
          request != _photoRequest ||
          state.savingPhoto) {
        return;
      }
      state = state.copyWith(
        photo: photo,
        clearPhoto: photo == null,
        photoStatus: '',
      );
      if (state.verified) await _try(() => _cache.writePhoto(user.uid, photo));
    } on FirebaseException catch (error) {
      if (!_current(generation) ||
          request != _photoRequest ||
          state.savingPhoto) {
        return;
      }
      if (error.code == 'unauthorized' ||
          error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        state = state.copyWith(clearPhoto: true, canEditAvatar: false);
        await _try(() => _cache.writePhoto(user.uid, null));
      }
      if (_current(generation) && request == _photoRequest) {
        state = state.copyWith(
          photoStatus: 'Photo unavailable. You can try again.',
        );
      }
    } catch (_) {
      if (_current(generation) &&
          request == _photoRequest &&
          !state.savingPhoto) {
        state = state.copyWith(
          photoStatus: 'Photo unavailable. You can try again.',
        );
      }
    }
  }

  Future<void> saveName(String input) async {
    final repository = _repository;
    final uid = state.uid;
    if (repository == null ||
        uid == null ||
        !state.verified ||
        state.savingName) {
      return;
    }
    final name = input.trim();
    if (name.isEmpty || name.length > 40 || name.contains(RegExp(r'[\r\n]'))) {
      state = state.copyWith(nameStatus: 'Enter a name of 1 to 40 characters.');
      return;
    }
    final generation = _session;
    state = state.copyWith(savingName: true, nameStatus: '');
    try {
      // Firebase can be reconnecting even while the device is online.
      // Use the server's write acknowledgement as the outcome.
      await repository.saveName(uid, name).timeout(const Duration(seconds: 15));
      if (_current(generation)) {
        state = state.copyWith(savingName: false, nameStatus: 'Name synced.');
      }
    } on TimeoutException {
      if (!_current(generation)) return;
      await _try(() => repository.abandonPendingWrites());
      if (_current(generation)) {
        state = state.copyWith(
          savingName: false,
          nameStatus: 'Firebase could not confirm the name. Try again.',
        );
      }
    } catch (_) {
      if (_current(generation)) {
        state = state.copyWith(
          savingName: false,
          nameStatus: 'Could not save your name. Try again.',
        );
      }
    }
  }

  Future<void> editPhoto({bool remove = false}) async {
    final repository = _repository;
    final uid = state.uid;
    if (repository == null ||
        uid == null ||
        !state.canEditAvatar ||
        state.savingPhoto) {
      return;
    }
    if (!state.online) {
      state = state.copyWith(
        photoStatus: 'Connect to the internet to edit your photo.',
      );
      return;
    }
    final generation = _session;
    final request = ++_photoRequest;
    state = state.copyWith(savingPhoto: true, photoStatus: '');
    try {
      Uint8List? photo;
      if (remove) {
        await repository.removeAvatar(uid);
      } else {
        photo = await repository.pickPhoto();
        if (!_current(generation) || !state.canEditAvatar || photo == null) {
          return;
        }
        await repository.saveAvatar(uid, photo);
      }
      if (!_current(generation) || request != _photoRequest) return;
      state = state.copyWith(
        photo: photo,
        clearPhoto: remove,
        photoStatus: remove ? 'Photo removed.' : 'Photo saved.',
      );
      await _try(() => _cache.writePhoto(uid, photo));
    } on FormatException catch (error) {
      if (_current(generation)) {
        state = state.copyWith(photoStatus: error.message);
      }
    } catch (_) {
      if (_current(generation)) {
        state = state.copyWith(
          photoStatus: 'Could not confirm the photo change. Try again.',
        );
      }
    } finally {
      if (_current(generation)) state = state.copyWith(savingPhoto: false);
    }
  }
}

/// Profile media and cache failures leave the last available view usable.
Future<T?> _try<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (_) {
    return null;
  }
}
