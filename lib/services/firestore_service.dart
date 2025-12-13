// lib/services/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_settings.dart'; // Rol hesaplama algoritması buradan geliyor

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. ODA KURMA (Create Room)
  Future<String?> createRoom(String hostName) async {
    try {
      // Önce misafir girişi yapalım (Anonim)
      UserCredential userCredential = await _auth.signInAnonymously();
      String userId = userCredential.user!.uid;

      // Rastgele 6 haneli oda kodu üret
      String roomId = _generateRoomCode();

      // Odayı oluştur
      await _firestore.collection('games').doc(roomId).set({
        'roomId': roomId,
        'hostId': userId,
        'status': 'waiting', // waiting, playing, finished
        'phase': 'day',      // day, night
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Host'u oyuncular listesine ekle
      await _firestore.collection('games').doc(roomId).collection('players').doc(userId).set({
        'id': userId,
        'name': hostName,
        'role': 'host', // Oyun başlayınca değişecek
        'isAlive': true,
        'isHost': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return roomId; // Başarılıysa oda kodunu dön
    } catch (e) {
      print("Oda kurma hatası: $e");
      return null;
    }
  }

  // 2. ODAYA KATILMA (Join Room)
  Future<bool> joinRoom(String roomId, String playerName) async {
    try {
      // Oda var mı kontrol et
      DocumentSnapshot roomDoc = await _firestore.collection('games').doc(roomId).get();
      if (!roomDoc.exists) {
        print("Böyle bir oda yok!");
        return false;
      }

      // Giriş yap
      UserCredential userCredential = await _auth.signInAnonymously();
      String userId = userCredential.user!.uid;

      // Oyuncuyu ekle
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

  // 3. OYUN VERİSİNİ DİNLE (Oyun başladı mı? Hangi fazdayız?)
  Stream<DocumentSnapshot> getGameStream(String roomId) {
    return _firestore.collection('games').doc(roomId).snapshots();
  }

  // 4. OYUNCULARI DİNLE (Kimler geldi?)
  Stream<QuerySnapshot> getPlayersStream(String roomId) {
    return _firestore.collection('games')
        .doc(roomId)
        .collection('players')
        .orderBy('joinedAt')
        .snapshots();
  }

  // 5. OYUNU BAŞLAT VE ROLLERİ DAĞIT (Host kullanır)
  Future<void> assignRolesAndStart(String roomId) async {
    try {
      // A. Oyuncuları Çek
      var roomRef = _firestore.collection('games').doc(roomId);
      var playersSnapshot = await roomRef.collection('players').get();
      var players = playersSnapshot.docs;

      if (players.isEmpty) return;

      // B. Rolleri Hesapla
      // GameSettings sınıfı otomatik olarak oyuncu sayısına göre rolleri belirler
      final settings = GameSettings.fromPlayerCount(players.length);
      final roles = settings.generateRoles();

      // C. Veritabanına Toplu Yazma (Batch Write)
      // Bu işlem atomiktir: Ya hepsi yazılır ya hiçbiri yazılmaz (Güvenli)
      WriteBatch batch = _firestore.batch();

      for (int i = 0; i < players.length; i++) {
        // Her oyuncuya sırayla listeden bir rol ata
        // roles listesi zaten karıştırılmış (shuffle) geliyor
        batch.update(players[i].reference, {
          'role': roles[i],
          'isAlive': true,
        });
      }

      // D. Oyun Durumunu "Playing" Yap
      batch.update(roomRef, {
        'status': 'playing',
        'phase': 'day', // Oyun gündüz başlar
        'startedAt': FieldValue.serverTimestamp(),
      });

      // E. Değişiklikleri Uygula
      await batch.commit();
      print("Oyun başlatıldı ve roller dağıtıldı!");

    } catch (e) {
      print("Oyun başlatma hatası: $e");
    }
  }

  // YARDIMCI: Rastgele Oda Kodu Üretici (6 Haneli)
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}