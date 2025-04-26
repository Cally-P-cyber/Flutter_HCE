import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nfc_emulator/models/nfc_tag.dart';

class TagService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('tags');

  Stream<List<NfcTag>> streamTags() {
    return _col
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => NfcTag.fromDoc(d)).toList());
  }

  Future<List<NfcTag>> fetchTags() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs.map((d) => NfcTag.fromDoc(d)).toList();
  }

  Future<void> addTag(NfcTag t) => _col.add(t.toMap());
  Future<void> updateTag(NfcTag t) => _col.doc(t.id).update(t.toMap());
}
