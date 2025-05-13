import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class StudySession extends ParseObject implements ParseCloneable {
  StudySession() : super('StudySession');
  StudySession.clone() : this();

  @override
  StudySession clone(Map<String, dynamic> map) =>
      StudySession.clone()..fromJson(map);

  String get subject => get<String>('subject') ?? '';
  set subject(String subject) => set<String>('subject', subject);

  int get duration => get<int>('duration') ?? 0;
  set duration(int duration) => set<int>('duration', duration);

  String get notes => get<String>('notes') ?? '';
  set notes(String notes) => set<String>('notes', notes);

  ParseUser? get user => get<ParseUser?>('user');
  set user(ParseUser? user) => set<ParseUser?>('user', user);

  @override
  DateTime get createdAt => get<DateTime>('createdAt') ?? DateTime.now();
}
