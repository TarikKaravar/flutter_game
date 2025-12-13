import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. ODA KURMA
  Future<String?> createRoom(String hostName) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      String userId = userCredential.user!.uid;

      String roomId = _generateRoomCode();

      // Oyun odası oluştur
      await _firestore.collection('games').doc(roomId).set({
        'roomId': roomId,
        'hostId': userId,
        'status': 'waiting',
        'phase': 'day',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Host'u oyuncu olarak ekle
      await _firestore.collection('games').doc(roomId).collection('players').doc(userId).set({
        'id': userId,
        'name': hostName,
        'role': 'host', 
        'isAlive': true,
        'isHost': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return roomId;
    } catch (e) {
      print("Oda kurma hatası: $e");
      return null;
    }
  }

  // 2. ODAYA KATILMA
  Future<bool> joinRoom(String roomId, String playerName) async {
    try {
      DocumentSnapshot roomDoc = await _firestore.collection('games').doc(roomId).get();
      if (!roomDoc.exists) {
        return false;
      }

      UserCredential userCredential = await _auth.signInAnonymously();
      String userId = userCredential.user!.uid;

      await _firestore.collection('games').doc(roomId).collection('players').doc(userId).set({
        'id': userId,
        'name': playerName,
        'role': 'waiting',
        'isAlive': true,
        'isHost': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print("Odaya katılma hatası: $e");
      return false;
    }
  }

  // 3. OYUN VERİSİNİ DİNLE
  Stream<DocumentSnapshot> getGameStream(String roomId) {
    return _firestore.collection('games').doc(roomId).snapshots();
  }

  // 4. OYUNCULARI DİNLE
  Stream<QuerySnapshot> getPlayersStream(String roomId) {
    return _firestore.collection('games').doc(roomId).collection('players').orderBy('joinedAt').snapshots();
  }

  // 5. OYUNU BAŞLAT
  Future<void> startGame(String roomId) async {
    await _firestore.collection('games').doc(roomId).update({
      'status': 'playing',
      'phase': 'day',
    });
  }

  // YARDIMCI: Oda Kodu Üretici
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}