import 'package:cloud_firestore/cloud_firestore.dart';

class NfcTag {
  final String id;
  final String name;
  final String icon;
  final String data;

  NfcTag({
    required this.id,
    required this.name,
    required this.icon,
    required this.data,
  });

  factory NfcTag.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NfcTag(
      id: doc.id,
      name: d['name'] as String,
      icon: d['icon'] as String,
      data: d['data'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'icon': icon,
        'data': data,
      };
}
