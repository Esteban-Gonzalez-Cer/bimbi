import 'package:bimbi/app/preferences.dart';
import 'package:bimbi/core/clock.dart';
import 'package:bimbi/data/repositories/local_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rows extends CollectionController {
  @override
  String get storageKey => 'test.rows';
}

final _rows = NotifierProvider<_Rows, CollectionState>(_Rows.new);

void main() {
  late DateTime now;
  late SharedPreferences prefs;

  ProviderContainer process() {
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    now = DateTime(2026, 11, 22, 7);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('offline edits survive a restart and stay pending until confirmed', () {
    final c = process();
    c.read(_rows.notifier).put('a', {'v': 1});
    final reopened = process();
    final state = reopened.read(_rows);
    expect(state.visible['a']?['v'], 1);
    expect(state.pending, {'a'});
    final sent = state.rows['a']!['updatedAt']! as int;
    reopened.read(_rows.notifier).confirm('a', sent);
    expect(reopened.read(_rows).pending, isEmpty);
  });

  test('an edit made after sending is not confirmed by the older write', () {
    final c = process();
    final notifier = c.read(_rows.notifier)..put('a', {'v': 1});
    final sent = c.read(_rows).rows['a']!['updatedAt']! as int;
    now = now.add(const Duration(seconds: 5));
    notifier
      ..put('a', {'v': 2})
      ..confirm('a', sent);
    expect(c.read(_rows).pending, {'a'});
  });

  test('guest rows are adopted by the first account, never by another', () {
    final c = process();
    final notifier = c.read(_rows.notifier)..put('a', {'v': 1});
    notifier.confirm('a', c.read(_rows).rows['a']!['updatedAt']! as int);
    notifier.adopt('alice');
    expect(c.read(_rows).owner, 'alice');
    expect(c.read(_rows).pending, {'a'}, reason: 'guest data uploads once');
    notifier.adopt('bob');
    expect(c.read(_rows).owner, 'bob');
    expect(c.read(_rows).rows, isEmpty, reason: 'alice data stays private');
  });

  test('remote snapshot wins unless a newer local edit is pending', () {
    final c = process();
    final notifier = c.read(_rows.notifier)..adopt('alice');
    now = now.add(const Duration(minutes: 1));
    notifier.put('local', {'v': 'mine'});
    final localAt = c.read(_rows).rows['local']!['updatedAt']! as int;
    notifier.applyRemote({
      'local': {'v': 'old', 'updatedAt': localAt - 1000},
      'other': {'v': 'theirs', 'updatedAt': localAt},
    });
    final state = c.read(_rows);
    expect(state.visible['local']?['v'], 'mine');
    expect(state.visible['other']?['v'], 'theirs');
    expect(state.pending, {'local'});

    // A row missing from the cloud and not pending was deleted elsewhere.
    notifier
      ..confirm('local', localAt)
      ..applyRemote({'local': state.rows['local']!});
    expect(c.read(_rows).visible.keys, ['local']);
  });

  test('synced deletes keep a tombstone until the cloud confirms', () {
    final c = process();
    final notifier = c.read(_rows.notifier)
      ..adopt('alice')
      ..put('a', {'v': 1});
    notifier.remove('a');
    expect(c.read(_rows).visible, isEmpty);
    expect(c.read(_rows).rows['a']?['deleted'], isTrue);
    notifier.confirm('a', c.read(_rows).rows['a']!['updatedAt']! as int);
    expect(c.read(_rows).rows, isEmpty);
    expect(c.read(_rows).pending, isEmpty);
  });
}
