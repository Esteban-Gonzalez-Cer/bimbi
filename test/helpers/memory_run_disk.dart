import 'package:bimbi/features/running/data/run_store.dart';

class MemoryRunDisk implements RunDisk {
  final _files = <String, Map<String, String>>{};

  @override
  Future<List<String>> keys(String owner) async =>
      _files[owner]?.keys.toList() ?? [];

  @override
  Future<String?> read(String owner, String key) async => _files[owner]?[key];

  @override
  Future<void> write(String owner, String key, String? value) async {
    final files = _files.putIfAbsent(owner, () => {});
    if (value == null) {
      files.remove(key);
    } else {
      files[key] = value;
    }
  }
}
