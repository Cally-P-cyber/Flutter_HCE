// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import '../models/nfc_tag.dart';

// class FirestoreService {
//   static CollectionReference get _tagCollection {
//     final uid = FirebaseAuth.instance.currentUser!.uid;
//     return FirebaseFirestore.instance
//         .collection('users')
//         .doc(uid)
//         .collection('tags');
//   }

//   static Stream<List<NfcTag>> tagStream() {
//     return _tagCollection
//         .snapshots()
//         .map((snap) => snap.docs.map((doc) => NfcTag.fromDoc(doc)).toList());
//   }

//   static Future<void> addTag(NfcTag tag) => _tagCollection.add(tag.toMap());

//   static Future<void> updateTag(NfcTag tag) =>
//       _tagCollection.doc(tag.id).update(tag.toMap());
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nfc_tag.dart';

class FirestoreService {
  static CollectionReference get _tags {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tags');
  }

  static Stream<List<NfcTag>> tagStream() => _tags
      .snapshots()
      .map((snap) => snap.docs.map((d) => NfcTag.fromDoc(d)).toList());

  static Future<void> addTag(NfcTag tag) => _tags.add(tag.toMap());
  static Future<void> updateTag(NfcTag tag) =>
      _tags.doc(tag.id).update(tag.toMap());
  static Future<void> deleteTag(String id) => _tags.doc(id).delete();
}
