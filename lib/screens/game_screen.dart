// lib/screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';
import '../utils/role_assets.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FirestoreService _service = FirestoreService();
  final String _myUserId = FirebaseAuth.instance.currentUser!.uid;
  
  String _currentPhase = 'role_reveal'; 
  Map<String, dynamic> _settings = {};
  bool _isHost = false;
  String? _myRole;
  bool _isAlive = true; // Varsayılan canlı
  String? _lastExecutionMessage;
  String? _winner;
  String? _lastProtectedId;
  
  String? _watcherResult; 
  bool _doctorSuccess = false;

  Timer? _timer;
  int _remainingTime = 0;

  @override
  void initState() {
    super.initState();
    _fetchMyDetails();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _fetchMyDetails() async {
    var doc = await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.roomId)
        .collection('players')
        .doc(_myUserId)
        .get();
        
    if (doc.exists && mounted) {
      setState(() {
        _myRole = doc.data()?['role'] ?? 'Köylü';
        _isHost = doc.data()?['isHost'] ?? false;
        _isAlive = doc.data()?['isAlive'] ?? true;
      });
    }
  }

  // --- ROL GÖRSELİ SEÇİCİ ---
  String _getRoleBackgroundImage() {
    switch (_myRole) {
      case 'Vampir': return 'assets/images/vampir_role.jpg';
      case 'Doktor': return 'assets/images/doktor_role.jpg';
      case 'Gözcü':  return 'assets/images/gozcu_role.jpg';
      case 'Köylü':  return 'assets/images/koylu_role.jpg';
      default: return RoleAssets.welcome;
    }
  }

  // --- FAZ GEÇİŞLERİ ---
  Future<void> _nextPhase() async {
    if (!_isHost) return;

    String nextPhase;
    int nextDuration;

    if (_currentPhase == 'role_reveal') {
      nextPhase = 'day';
      nextDuration = _settings['dayDuration'] ?? 60;
    } else if (_currentPhase == 'day') {
      await _service.processDayResults(widget.roomId);
      nextPhase = 'night';
      nextDuration = _settings['nightDuration'] ?? 10;
    } else if (_currentPhase == 'night') {
      nextPhase = 'night_processing';
      nextDuration = 5;
    } else if (_currentPhase == 'night_processing') {
      await _service.resolveNightResults(widget.roomId);
      nextPhase = 'day';
      nextDuration = _settings['dayDuration'] ?? 60;
    } else {
      nextPhase = 'day';
      nextDuration = 60;
    }

    await _service.updatePhase(widget.roomId, nextPhase);
    _startTimer(nextDuration);
  }

  void _startTimer(int duration) {
    if (!_isHost) return;
    _timer?.cancel();
    _remainingTime = duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() => _remainingTime--);
      } else {
        _timer?.cancel();
        _nextPhase();
      }
    });
  }

  void _showGameOverDialog(String winner) {
    bool villagerWin = winner == 'villagers';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.parchment,
        title: Text(villagerWin ? "KÖYLÜLER KAZANDI!" : "VAMPİRLER KAZANDI!", 
          style: GoogleFonts.medievalSharp(fontSize: 24, fontWeight: FontWeight.bold, color: villagerWin ? Colors.green : Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(villagerWin ? Icons.sunny : Icons.bloodtype, size: 60, color: villagerWin ? Colors.green : Colors.red),
            const SizedBox(height: 20),
            Text(villagerWin ? "Köy kötülükten arındı." : "Karanlık tüm köyü ele geçirdi.", style: GoogleFonts.medievalSharp(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("ANA MENÜYE DÖN"),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()), 
                (route) => false
              );
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.getGameStream(widget.roomId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.gold));

          var gameData = snapshot.data!.data() as Map<String, dynamic>;
          
          String newPhase = gameData['phase'] ?? 'role_reveal';
          if (newPhase != _currentPhase) {
            _currentPhase = newPhase;
            if (_currentPhase == 'night') {
              _watcherResult = null;
              _doctorSuccess = false;
            }
            // Faz değişince durumumu güncelle (Öldüm mü kaldım mı?)
            _fetchMyDetails();
          }

          var settings = gameData['settings'] as Map<String, dynamic>?;
          if (settings != null) _settings = settings;

          _lastExecutionMessage = gameData['lastExecution'];
          _lastProtectedId = gameData['lastProtectedId'];
          _winner = gameData['winner'];

          if (_winner != null && _winner!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted && !ModalRoute.of(context)!.isCurrent) return;
               _showGameOverDialog(_winner!);
            });
          }

          // Durum Kontrolleri
          bool isNight = _currentPhase == 'night';
          bool isProcessing = _currentPhase == 'night_processing';
          bool isRoleReveal = _currentPhase == 'role_reveal';
          bool amIDead = !_isAlive; // Ölü müyüm?

          // --- ARKA PLAN SEÇİMİ ---
          String bgImage;
          if (amIDead) {
            // 1. Eğer ölüysem MEZARLIK
            bgImage = 'assets/images/mezarlik.jpg';
          } else if (isRoleReveal) {
            // 2. Rol öğrenirken ROL GÖRSELİ
            bgImage = _getRoleBackgroundImage();
          } else if (isNight && ['Vampir', 'Doktor', 'Gözcü'].contains(_myRole)) {
            // 3. Gece ve rolüm varsa ROL GÖRSELİ (Köylü hariç)
            bgImage = _getRoleBackgroundImage();
          } else if (isNight || isProcessing) {
            // 4. Gece ama köylüysem veya işlem yapılıyorsa STANDART GECE
            bgImage = RoleAssets.welcome;
          } else {
            // 5. Gündüz KÖY MEYDANI
            bgImage = 'assets/images/background.jpg';
          }

          // Host Timer Başlat
          if (_isHost && _timer == null) {
             int duration = 5;
             if (_currentPhase == 'night') duration = _settings['nightDuration'] ?? 10;
             else if (_currentPhase == 'day') duration = _settings['dayDuration'] ?? 60;
             else if (_currentPhase == 'night_processing') duration = 5;
             _startTimer(duration);
          }

          return Stack(
            children: [
              // 1. DİNAMİK ARKA PLAN
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000),
                child: Container(
                  key: ValueKey<String>(bgImage),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(bgImage),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                    ),
                  ),
                ),
              ),

              // 2. ANA İÇERİK
              SafeArea(
                child: amIDead
                    ? _buildDeadView() // ÖLÜ EKRANI
                    : isRoleReveal
                        ? _buildRoleRevealView() // ROL ÖĞRENME
                        : Column(
                            children: [
                              _buildHeader(isNight || isProcessing), // Sol üstte rol yazısı KALDIRILDI
                              const SizedBox(height: 10),
                              Expanded(
                                child: (isNight || isProcessing)
                                    ? _buildNightInterface(isProcessing)
                                    : _buildVotingTable(),
                              ),
                            ],
                          ),
              ),

              // 3. HOST BUTONU (Ölü değilse ve rol gösterimi değilse)
              if (_isHost && !isRoleReveal && !amIDead)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton.extended(
                    backgroundColor: AppColors.gold,
                    onPressed: _nextPhase,
                    label: Text("GEÇ >>", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown, fontWeight: FontWeight.bold)),
                    icon: const Icon(Icons.fast_forward, color: AppColors.darkBrown),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- ÖLÜ EKRANI (MEZARLIK) ---
  Widget _buildDeadView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sentiment_very_dissatisfied, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            "ÖLDÜN...",
            style: GoogleFonts.medievalSharp(fontSize: 50, color: Colors.redAccent, fontWeight: FontWeight.bold),
          ).animate().shake(duration: 500.ms),
          const SizedBox(height: 10),
          Text(
            "Ruhun artık huzura kavuştu.\nOyun bitene kadar izleyeceksin.",
            textAlign: TextAlign.center,
            style: GoogleFonts.medievalSharp(fontSize: 20, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // --- ÜST BAŞLIK (ROL İSMİ KALDIRILDI) ---
  Widget _buildHeader(bool isNight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol taraf artık boş veya oyun durumu yazabilir (Rol yazısını kaldırdık)
          Text(
            isNight ? "GECE" : "GÜNDÜZ",
            style: GoogleFonts.medievalSharp(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          
          if (_isHost)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
                color: Colors.black54
              ),
              child: Text("$_remainingTime", style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 20)),
            ),
        ],
      ),
    );
  }

  // --- ROL ÖĞRENME (Rol Arkaplanı Üzerine) ---
  Widget _buildRoleRevealView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black54, // Yazı okunsun diye hafif siyah zemin
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold, width: 3)
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SENİN ROLÜN:", style: GoogleFonts.medievalSharp(fontSize: 24, color: Colors.white70)),
            const SizedBox(height: 10),
            Text(
              _myRole?.toUpperCase() ?? "...", 
              style: GoogleFonts.medievalSharp(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.gold)
            ).animate().scale(duration: 600.ms),
            const SizedBox(height: 10),
            // Kısa açıklama
             Text(
               _myRole == 'Vampir' ? "Gece avlan, gündüz saklan." :
               _myRole == 'Doktor' ? "Hayat kurtarmak senin elinde." :
               _myRole == 'Gözcü' ? "Gerçekleri açığa çıkar." : "Köyünü savun, haini bul.",
               textAlign: TextAlign.center,
               style: GoogleFonts.medievalSharp(fontSize: 16, color: Colors.white),
             )
          ],
        ),
      ),
    );
  }

  // --- DİĞER FONKSİYONLAR (Vampir, Doktor vb. arayüzleri aynı kaldı) ---
  Widget _buildNightInterface(bool isProcessing) {
    if (isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 20),
            Text("Gece olayları hesaplanıyor...", style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 18)),
            if (_myRole == 'Gözcü' && _watcherResult != null)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black87, border: Border.all(color: Colors.blueAccent)),
                child: Text(_watcherResult!, style: GoogleFonts.medievalSharp(color: Colors.blueAccent, fontSize: 24)),
              ),
          ],
        ),
      );
    }

    switch (_myRole) {
      case 'Vampir': return _buildVampireView();
      case 'Doktor': return _buildDoctorView();
      case 'Gözcü': return _buildWatcherView();
      default: return const Center(child: Text("Köy derin bir uykuda...", style: TextStyle(color: Colors.white54, fontSize: 20)));
    }
  }

  Widget _buildVampireView() {
    return _buildActionList(
      title: "KİMİ ÖLDÜRECEKSİN?",
      actionIcon: Icons.bloodtype,
      actionColor: Colors.red,
      filter: (player) => player['role'] != 'Vampir' && player['isAlive'] == true, 
      showRoleToMe: true,
      onTap: (targetId, targetName) => _service.submitNightAction(widget.roomId, 'Vampir', targetId)
    );
  }

  Widget _buildDoctorView() {
    return _buildActionList(
      title: "KİMİ KORUYACAKSIN?",
      actionIcon: Icons.local_hospital,
      actionColor: Colors.green,
      filter: (player) => player['isAlive'] == true && player['id'] != _lastProtectedId,
      onTap: (targetId, targetName) => _service.submitNightAction(widget.roomId, 'Doktor', targetId)
    );
  }

  Widget _buildWatcherView() {
    return _buildActionList(
      title: "KİMİ GÖZETLEYECEKSİN?",
      actionIcon: Icons.visibility,
      actionColor: Colors.blue,
      filter: (player) => player['isAlive'] == true && player['id'] != _myUserId,
      onTap: (targetId, targetName) async {
        _service.submitNightAction(widget.roomId, 'Gözcü', targetId);
        var playerDoc = await FirebaseFirestore.instance.collection('games').doc(widget.roomId).collection('players').doc(targetId).get();
        String role = playerDoc.data()?['role'] ?? 'Köylü';
        bool isBad = (role == 'Vampir');
        setState(() {
          _watcherResult = "$targetName ${isBad ? 'TEHLİKELİ! 🩸' : 'MASUM 🕊️'}";
        });
      }
    );
  }

  Widget _buildActionList({required String title, required IconData actionIcon, required Color actionColor, required bool Function(Map<String, dynamic>) filter, required Function(String, String) onTap, bool showRoleToMe = false}) {
    return Column(
      children: [
        Text(title, style: GoogleFonts.medievalSharp(fontSize: 24, color: actionColor, fontWeight: FontWeight.bold, shadows: [const Shadow(blurRadius: 5, color: Colors.black)])),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _service.getPlayersStream(widget.roomId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var players = snapshot.data!.docs;
              return StreamBuilder<DocumentSnapshot>(
                stream: _service.getMyNightActionStream(widget.roomId),
                builder: (context, actionSnap) {
                  String? myTargetId;
                  if (actionSnap.hasData && actionSnap.data!.exists) myTargetId = actionSnap.data!['targetId'];
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      var player = players[index].data() as Map<String, dynamic>;
                      if (!filter(player)) return Container(); 
                      String playerId = player['id'];
                      bool isSelected = playerId == myTargetId;
                      String roleText = showRoleToMe && player['role'] == 'Vampir' ? " (Vampir)" : "";
                      return GestureDetector(
                        onTap: () => onTap(playerId, player['name']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          decoration: BoxDecoration(color: isSelected ? actionColor.withOpacity(0.8) : Colors.black54, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSelected ? actionColor : Colors.white24)),
                          child: Row(children: [Icon(actionIcon, color: isSelected ? Colors.white : actionColor), const SizedBox(width: 15), Text("${player['name']}$roleText", style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 18))]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVotingTable() {
    return Column(
      children: [
        Text("OYLAMA ZAMANI", style: GoogleFonts.medievalSharp(fontSize: 30, color: AppColors.parchment, shadows: [const Shadow(blurRadius: 10, color: Colors.black)])),
        Text("Şüphelendiğin kişiye oy ver!", style: GoogleFonts.medievalSharp(color: Colors.white70)),
        const SizedBox(height: 10),
         if (_lastExecutionMessage != null && _lastExecutionMessage!.isNotEmpty)
            Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.all(10), color: Colors.red.withOpacity(0.5), child: Text(_lastExecutionMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16))),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _service.getPlayersStream(widget.roomId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var players = snapshot.data!.docs;
              var alivePlayers = players.where((doc) => doc['isAlive'] == true).toList();
              return StreamBuilder<DocumentSnapshot>(
                stream: _service.getMyVoteStream(widget.roomId),
                builder: (context, voteSnapshot) {
                  String? myTargetId;
                  if (voteSnapshot.hasData && voteSnapshot.data!.exists) myTargetId = voteSnapshot.data!['targetId'];
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: alivePlayers.length,
                    itemBuilder: (context, index) {
                      var player = alivePlayers[index].data() as Map<String, dynamic>;
                      String playerId = player['id'];
                      bool isSelected = playerId == myTargetId;
                      return GestureDetector(
                        onTap: () => _service.votePlayer(widget.roomId, playerId),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: isSelected ? Colors.redAccent : AppColors.saddleBrown.withOpacity(0.8), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? Colors.red : Colors.transparent, width: 2)),
                          child: Text(player['name'], style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 18)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}