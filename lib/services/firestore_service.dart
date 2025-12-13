// lib/services/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_settings.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. ODA KURMA
  Future<String?> createRoom(String hostName) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      String userId = userCredential.user!.uid;
      String roomId = _generateRoomCode();

      // Varsayılan ayarlar (1 Vampir, 1 Doktor, 1 Gözcü)
      Map<String, int> defaultSettings = {
        'vampires': 1,
        'doctors': 1,
        'watchers': 1,
      };

      await _firestore.collection('games').doc(roomId).set({
        'roomId': roomId,
        'hostId': userId,
        'status': 'waiting',
        'phase': 'day',
        'settings': defaultSettings, // Ayarları buraya ekledik
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  // 2. AYARLARI GÜNCELLE (YENİ FONKSİYON)
  Future<void> updateGameSettings(String roomId, int v, int d, int w) async {
    try {
      await _firestore.collection('games').doc(roomId).update({
        'settings': {
          'vampires': v,
          'doctors': d,
          'watchers': w,
        }
      });
    } catch (e) {
      print("Ayar güncelleme hatası: $e");
    }
  }

  // 3. ODAYA KATILMA
  Future<bool> joinRoom(String roomId, String playerName) async {
    try {
      DocumentSnapshot roomDoc = await _firestore.collection('games').doc(roomId).get();
      if (!roomDoc.exists) return false;

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
      print("Katılma hatası: $e");
      return false;
    }
  }

  Stream<DocumentSnapshot> getGameStream(String roomId) {
    return _firestore.collection('games').doc(roomId).snapshots();
  }

  Stream<QuerySnapshot> getPlayersStream(String roomId) {
    return _firestore.collection('games').doc(roomId).collection('players').orderBy('joinedAt').snapshots();
  }

  Future<void> updatePhase(String roomId, String newPhase) async {
    await _firestore.collection('games').doc(roomId).update({
      'phase': newPhase,
      'lastPhaseChange': FieldValue.serverTimestamp(),
    });
  }

  // 4. OYUNU BAŞLAT (GÜNCELLENDİ: ARTIK AYARLARI OKUYOR)
  Future<void> assignRolesAndStart(String roomId) async {
    try {
      var roomRef = _firestore.collection('games').doc(roomId);
      
      // Hem oda bilgisini (ayarlar için) hem oyuncuları çek
      var roomSnapshot = await roomRef.get();
      var playersSnapshot = await roomRef.collection('players').get();
      var players = playersSnapshot.docs;

      if (players.isEmpty) return;

      // Ayarları al
      var settingsMap = roomSnapshot.data()?['settings'] as Map<String, dynamic>?;
      int v = settingsMap?['vampires'] ?? 1;
      int d = settingsMap?['doctors'] ?? 1;
      int w = settingsMap?['watchers'] ?? 1;

      // GameSettings objesi oluştur (Oyuncu sayısı şu anki sayı, roller ayardan)
      final settings = GameSettings(
        players: players.length,
        vampires: v,
        doctors: d,
        watchers: w,
      );

      final roles = settings.generateRoles();

      WriteBatch batch = _firestore.batch();

      for (int i = 0; i < players.length; i++) {
        batch.update(players[i].reference, {
          'role': roles[i],
          'isAlive': true,
        });
      }

      batch.update(roomRef, {
        'status': 'playing',
        'phase': 'day',
        'startedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

    } catch (e) {
      print("Başlatma hatası: $e");
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}