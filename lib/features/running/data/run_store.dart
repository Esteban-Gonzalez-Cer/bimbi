import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config.dart';
import '../domain/run.dart';

class SavedRun {
  const SavedRun({
    required this.id,
    required this.summary,
    this.segments = const [],
    this.pending = false,
  });

  final String id;
  final RunSummary? summary;
  final List<List<RunPoint>> segments;
  final bool pending;
  bool get deleted => summary == null;

  SavedRun confirmed() =>
      SavedRun(id: id, summary: summary, segments: segments);

  Map<String, Object?> toJson() => {
    'summary': summary?.toJson(),
    'segments': encodeSegments(segments),
    'pending': pending,
  };

  factory SavedRun.fromJson(String id, Map<String, dynamic> value) {
    final json = value['summary'];
    final summary = RunSummary.parse(id, json);
    if (json != null && summary == null) {
      throw const FormatException('Invalid saved workout');
    }
    return SavedRun(
      id: id,
      summary: summary,
      segments: decodeSegments(value['segments'] as List),
      pending: value['pending'] == true,
    );
  }
}

typedef RunSnapshot = ({RunDraft? draft, Map<String, SavedRun> runs});

abstract interface class RunDisk {
  Future<List<String>> keys(String owner);
  Future<String?> read(String owner, String key);

  /// A replacement becomes visible atomically. Null removes the previous file.
  Future<void> write(String owner, String key, String? value);
}

class FileRunDisk implements RunDisk {
  FileRunDisk(this.project, {Future<Directory> Function()? location})
    : _location = location ?? getApplicationSupportDirectory;

  final String project;
  final Future<Directory> Function() _location;

  Future<Directory> _directory(String owner) async {
    final root = await _location();
    final account = sha256.convert(utf8.encode(jsonEncode([project, owner])));
    return Directory.fromUri(root.uri.resolve('bimbi-runs/$account/'));
  }

  Future<File> _file(String owner, String key) async {
    if (key != 'draft' && !runIdPattern.hasMatch(key)) {
      throw const FormatException('Invalid workout identifier');
    }
    return File.fromUri((await _directory(owner)).uri.resolve('$key.json'));
  }

  @override
  Future<List<String>> keys(String owner) async {
    final directory = await _directory(owner);
    if (!await directory.exists()) return [];
    return [
      await for (final file in directory.list(followLinks: false))
        if (file is File && file.uri.pathSegments.last.endsWith('.json'))
          file.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
    ];
  }

  @override
  Future<String?> read(String owner, String key) async {
    final file = await _file(owner, key);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String owner, String key, String? value) async {
    final file = await _file(owner, key);
    if (value == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }
}

class RunStore {
  RunStore(this.disk);

  final RunDisk disk;
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<SavedRun?> _readRun(String owner, String id) async {
    final json = await disk.read(owner, id);
    return json == null ? null : SavedRun.fromJson(id, _parse(json));
  }

  Map<String, dynamic> _parse(String json) {
    final value = jsonDecode(json);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid workout file');
    }
    return value;
  }

  Future<RunSnapshot> load(String owner) => _serial(() async {
    final runs = <String, SavedRun>{};
    for (final id in await disk.keys(owner)) {
      if (!runIdPattern.hasMatch(id)) continue;
      final run = await _readRun(owner, id);
      if (run != null) runs[id] = run;
    }
    final data = await disk.read(owner, 'draft');
    final draft = data == null ? null : RunDraft.fromJson(_parse(data));
    // Recovery after a crash between committing a run and removing its draft.
    return (draft: runs.containsKey(draft?.id) ? null : draft, runs: runs);
  });

  Future<void> checkpoint(String owner, RunDraft? draft) => _serial(
    () => disk.write(
      owner,
      'draft',
      draft == null ? null : jsonEncode(draft.toJson()),
    ),
  );

  Future<SavedRun> save(String owner, RunDraft draft, {required bool sync}) =>
      _serial(() async {
        final run = SavedRun(
          id: draft.id,
          summary: draft.summary,
          segments: draft.segments,
          pending: sync,
        );
        await _write(owner, run);
        // The committed file takes precedence if draft cleanup fails.
        try {
          await disk.write(owner, 'draft', null);
        } on FileSystemException {
          // load() recovers this state after a restart.
        }
        return run;
      });

  Future<SavedRun?> remove(
    String owner,
    String id, {
    required bool sync,
  }) => _serial(() async {
    if (!sync) {
      await disk.write(owner, id, null);
      return null;
    }
    // Replace the file atomically, dropping both the coordinates and totals.
    final tombstone = SavedRun(id: id, summary: null, pending: true);
    await _write(owner, tombstone);
    return tombstone;
  });

  Future<List<SavedRun>> merge(String owner, Iterable<SavedRun> remote) =>
      _serial(() async {
        final changed = <SavedRun>[];
        for (final entry in remote) {
          final local = await _readRun(owner, entry.id);
          if (local?.deleted == true) continue;
          if (!entry.deleted && local != null) continue;
          await _write(owner, entry);
          changed.add(entry);
        }
        return changed;
      });

  Future<SavedRun?> confirm(String owner, SavedRun sent) => _serial(() async {
    final current = await _readRun(owner, sent.id);
    if (current == null ||
        !current.pending ||
        current.deleted != sent.deleted) {
      return null;
    }
    final confirmed = current.confirmed();
    await _write(owner, confirmed);
    return confirmed;
  });

  Future<void> _write(String owner, SavedRun value) =>
      disk.write(owner, value.id, jsonEncode(value.toJson()));
}

final runStoreProvider = Provider<RunStore>(
  (ref) => RunStore(FileRunDisk(AppConfig.firebaseProject)),
);
