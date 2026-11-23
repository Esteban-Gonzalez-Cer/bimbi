import 'dart:async';

import 'package:bimbi/data/services/messaging_service.dart';
import 'package:bimbi/ui/notifications/view_models/notifications.dart';

class FakeMessaging implements MessagingService {
  FakeMessaging({this.allow = true, this.launch});
  bool allow;
  final InboxMessage? launch;
  final subscribed = <String>{};
  final calls = <String>[];
  var permissionRequests = 0;
  final _foreground = StreamController<InboxMessage>.broadcast();
  final _opened = StreamController<InboxMessage>.broadcast();

  void deliver(InboxMessage m) => _foreground.add(m);
  void tap(InboxMessage m) => _opened.add(m);

  @override
  Stream<InboxMessage> get foreground => _foreground.stream;
  @override
  Stream<InboxMessage> get opened => _opened.stream;
  @override
  Future<InboxMessage?> initial() async => launch;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allow;
  }

  @override
  Future<void> subscribe(String topic) async {
    calls.add('+$topic');
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    calls.add('-$topic');
    subscribed.remove(topic);
  }
}

class FakeTopicCloud implements TopicPrefsCloud {
  final rows = <String, TopicChoice>{};
  final _changes = StreamController<String>.broadcast();

  void serverSet(String uid, TopicChoice c) {
    rows[uid] = c;
    _changes.add(uid);
  }

  @override
  Stream<TopicChoice?> watch(String uid) async* {
    yield rows[uid];
    yield* _changes.stream.where((u) => u == uid).map((_) => rows[uid]);
  }

  @override
  Future<void> write(String uid, TopicChoice choice) async =>
      rows[uid] = choice;
}
