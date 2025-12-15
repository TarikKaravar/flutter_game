// lib/services/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_settings.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> createRoom(String hostName) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      String userId = userCredential.user!.uid;
      String roomId = _generateRoomCode();

      Map<String, dynamic> defaultSettings = {
        'vampires': 1,
        'doctors': 1,
        'watchers': 1,
        'dayDuration': 60,
        'nightDuration': 10,
      };

      await _firestore.collection('games').doc(roomId).set({
        'roomId': roomId,
        'hostId': userId,
        'lobbyName': "$hostName'in Odası",
        'status': 'waiting',
        'phase': 'role_reveal',
        'lastExecution': '',
        'winner': '', 
        'lastProtectedId': '',
        'settings': defaultSettings,
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

  Future<void> updateLobbyName(String roomId, String newName) async {
    await _firestore.collection('games').doc(roomId).update({
      'lobbyName': newName,
    });
  }

  Future<void> removePlayer(String roomId, String playerId) async {
    await _firestore.collection('games').doc(roomId).collection('players').doc(playerId).delete();
  }

  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('games').doc(roomId).delete();
  }

  Future<void> updateGameSettings(String roomId, Map<String, dynamic> newSettings) async {
    await _firestore.collection('games').doc(roomId).update({
      'settings': newSettings
    });
  }

  Future<void> updatePhase(String roomId, String newPhase) async {
    await _firestore.collection('games').doc(roomId).update({
      'phase': newPhase,
      'lastPhaseChange': FieldValue.serverTimestamp(),
    });
  }

  Future<void> votePlayer(String roomId, String targetId) async {
    String myId = _auth.currentUser!.uid;
    await _firestore.collection('games').doc(roomId).collection('votes').doc(myId).set({
      'voterId': myId,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitNightAction(String roomId, String role, String targetId) async {
    String myId = _auth.currentUser!.uid;
    await _firestore.collection('games').doc(roomId).collection('night_actions').doc(myId).set({
      'role': role,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> processDayResults(String roomId) async {
    var votesSnapshot = await _firestore.collection('games').doc(roomId).collection('votes').get();
    var votes = votesSnapshot.docs;
    
    Map<String, int> voteCounts = {};
    for (var doc in votes) {
      String targetId = doc.data()['targetId'];
      voteCounts[targetId] = (voteCounts[targetId] ?? 0) + 1;
    }

    String resultMessage = "Bu tur kimse asılmadı.";
    String? playerToDie;

    if (voteCounts.isNotEmpty) {
      var sortedEntries = voteCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)); 
      
      var winner = sortedEntries[0];
      
      if (sortedEntries.length > 1 && sortedEntries[0].value == sortedEntries[1].value) {
        resultMessage = "Oylar eşit çıktı! Kimse asılmıyor.";
      } else {
        playerToDie = winner.key;
        var playerDoc = await _firestore.collection('games').doc(roomId).collection('players').doc(playerToDie).get();
        String playerName = playerDoc.data()?['name'] ?? 'Birisi';
        resultMessage = "$playerName köylüler tarafından asıldı! ⚰️";

        await _firestore.collection('games').doc(roomId).collection('players').doc(playerToDie).update({'isAlive': false});
      }
    }

    await _firestore.collection('games').doc(roomId).update({'lastExecution': resultMessage});
    for (var doc in votes) { await doc.reference.delete(); }
    await _checkWinCondition(roomId);
  }

  Future<Map<String, dynamic>> resolveNightResults(String roomId) async {
    var actionsSnapshot = await _firestore.collection('games').doc(roomId).collection('night_actions').get();
    var actions = actionsSnapshot.docs;

    List<String> vampireTargets = [];
    String? doctorTarget;
    String lastProtectedId = "";

    for (var doc in actions) {
      var data = doc.data();
      if (data['role'] == 'Vampir') {
        vampireTargets.add(data['targetId']);
      } else if (data['role'] == 'Doktor') {
        doctorTarget = data['targetId'];
      }
    }

    String? killTarget;
    if (vampireTargets.isNotEmpty) {
      killTarget = vampireTargets[0];
    }

    String executionMessage = "Gece olaysız geçti.";
    bool doctorSuccess = false;

    if (killTarget != null) {
      if (doctorTarget == killTarget) {
        executionMessage = "Gece biri saldırıya uğradı ama DOKTOR onu kurtardı! 🛡️";
        doctorSuccess = true;
      } else {
        var playerDoc = await _firestore.collection('games').doc(roomId).collection('players').doc(killTarget).get();
        String playerName = playerDoc.data()?['name'] ?? 'Birisi';
        executionMessage = "$playerName gece vampirler tarafından öldürüldü! 🩸";
        
        await _firestore.collection('games').doc(roomId).collection('players').doc(killTarget).update({'isAlive': false});
      }
    }

    if (doctorTarget != null) {
      await _firestore.collection('games').doc(roomId).update({'lastProtectedId': doctorTarget});
    }

    await _firestore.collection('games').doc(roomId).update({'lastExecution': executionMessage});
    for (var doc in actions) { await doc.reference.delete(); }
    await _checkWinCondition(roomId);

    return {
      'doctorSuccess': doctorSuccess,
      'doctorTarget': doctorTarget,
    };
  }

  Future<void> _checkWinCondition(String roomId) async {
    var playersSnapshot = await _firestore.collection('games').doc(roomId).collection('players').get();
    var players = playersSnapshot.docs;

    int vampires = 0;
    int others = 0;

    for (var doc in players) {
      if (doc['isAlive'] == true) {
        if (doc['role'] == 'Vampir') {
          vampires++;
        } else {
          others++;
        }
      }
    }

    if (vampires == 0) {
      await _firestore.collection('games').doc(roomId).update({'winner': 'villagers'});
    }
    else if (vampires >= others) {
      await _firestore.collection('games').doc(roomId).update({'winner': 'vampires'});
    }
  }

  Stream<DocumentSnapshot> getGameStream(String roomId) {
    return _firestore.collection('games').doc(roomId).snapshots();
  }

  Stream<QuerySnapshot> getPlayersStream(String roomId) {
    return _firestore.collection('games').doc(roomId).collection('players').orderBy('joinedAt').snapshots();
  }
  
  Stream<DocumentSnapshot> getMyVoteStream(String roomId) {
    String myId = _auth.currentUser!.uid;
    return _firestore.collection('games').doc(roomId).collection('votes').doc(myId).snapshots();
  }

  Stream<DocumentSnapshot> getMyNightActionStream(String roomId) {
    String myId = _auth.currentUser!.uid;
    return _firestore.collection('games').doc(roomId).collection('night_actions').doc(myId).snapshots();
  }

  Future<void> assignRolesAndStart(String roomId) async {
    try {
      var roomRef = _firestore.collection('games').doc(roomId);
      var roomSnapshot = await roomRef.get();
      var playersSnapshot = await roomRef.collection('players').get();
      var players = playersSnapshot.docs;

      if (players.isEmpty) return;

      var settingsMap = roomSnapshot.data()?['settings'] as Map<String, dynamic>?;
      int v = settingsMap?['vampires'] ?? 1;
      int d = settingsMap?['doctors'] ?? 1;
      int w = settingsMap?['watchers'] ?? 1;

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
        'phase': 'role_reveal', 
        'startedAt': FieldValue.serverTimestamp(),
        // !!! İŞTE BU SATIR EKSİKTİ, BUNU EKLEDİK !!!
        'lastPhaseChange': FieldValue.serverTimestamp(), 
        'winner': '', 
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