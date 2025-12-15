// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Panoya kopyalamak için
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final FirestoreService _service = FirestoreService();
  final String _myUserId = FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic> _settings = {
    'vampires': 1,
    'doctors': 1,
    'watchers': 1,
    'dayDuration': 60,
    'nightDuration': 30,
    'votingDuration': 30,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _service.getGameStream(widget.roomId),
      builder: (context, gameSnapshot) {
        
        if (gameSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.parchment,
            body: Center(child: CircularProgressIndicator(color: AppColors.saddleBrown))
          );
        }

        if (!gameSnapshot.hasData || !gameSnapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          });
          return const Scaffold(body: Center(child: Text("Oda bulunamadı...")));
        }

        var gameData = gameSnapshot.data!.data() as Map<String, dynamic>;
        String lobbyName = gameData['lobbyName'] ?? "Oyun Odası";

        if (gameData['status'] == 'playing') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => GameScreen(roomId: widget.roomId)),
              );
            }
          });
        }

        var incomingSettings = gameData['settings'] as Map<String, dynamic>?;
        if (incomingSettings != null) {
          _settings = Map.from(incomingSettings);
        }

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: widget.isHost ? () => _editLobbyName(context, lobbyName) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(lobbyName, overflow: TextOverflow.ellipsis, style: GoogleFonts.medievalSharp(color: AppColors.gold))),
                  if (widget.isHost) const SizedBox(width: 8),
                  if (widget.isHost) const Icon(Icons.edit, size: 18, color: Colors.white54),
                ],
              ),
            ),
            backgroundColor: AppColors.darkBrown,
            centerTitle: true,
            automaticallyImplyLeading: false, 
            leading: IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => _leaveLobby(context),
              tooltip: "Lobiden Ayrıl",
            ),
            actions: [
              if (widget.isHost)
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.gold),
                  onPressed: () => _showSettingsDialog(context),
                )
            ],
          ),
          body: Column(
            children: [
              // --- YENİLENEN ODA KODU ALANI ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                color: Colors.black38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "ODA KODU: ", 
                      style: GoogleFonts.medievalSharp(color: Colors.white70, fontSize: 14, letterSpacing: 1),
                    ),
                    Text(
                      widget.roomId,
                      style: GoogleFonts.medievalSharp(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(width: 10),
                    
                    // KOPYALAMA BUTONU
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.roomId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Oda kodu kopyalandı: ${widget.roomId}", style: GoogleFonts.medievalSharp()),
                            backgroundColor: AppColors.saddleBrown,
                            duration: const Duration(milliseconds: 1500),
                          )
                        );
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold)
                        ),
                        child: const Icon(Icons.copy, color: AppColors.gold, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              // ---------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: AppColors.saddleBrown.withOpacity(0.5),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRoleInfo(Icons.bloodtype, "${_settings['vampires']}", Colors.red),
                        _buildRoleInfo(Icons.medical_services, "${_settings['doctors']}", Colors.green),
                        _buildRoleInfo(Icons.visibility, "${_settings['watchers']}", Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         const Icon(Icons.sunny, size: 16, color: Colors.amber),
                         Text(" ${_settings['dayDuration']}sn  ", style: const TextStyle(color: Colors.white70)),
                         const Icon(Icons.nightlight_round, size: 16, color: Colors.blueGrey),
                         Text(" ${_settings['nightDuration']}sn", style: const TextStyle(color: Colors.white70)),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Text("Oyuncular", style: GoogleFonts.medievalSharp(fontSize: 24, fontWeight: FontWeight.bold)),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _service.getPlayersStream(widget.roomId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var players = snapshot.data!.docs;

                    bool amIInList = players.any((doc) => doc.id == _myUserId);
                    if (!amIInList) {
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                         if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                       });
                       return Container();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        var player = players[index].data() as Map<String, dynamic>;
                        String playerId = player['id'];
                        bool isMeHost = player['isHost'] ?? false;
                        
                        return Card(
                          color: AppColors.saddleBrown.withOpacity(0.9),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold,
                              child: Icon(isMeHost ? Icons.star : Icons.person, color: AppColors.darkBrown),
                            ),
                            title: Text(
                              player['name'],
                              style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 20),
                            ),
                            trailing: (widget.isHost && !isMeHost) 
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () => _kickPlayer(context, playerId, player['name']),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: AppColors.darkBrown,
                child: widget.isHost
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {
                          _service.assignRolesAndStart(widget.roomId);
                        },
                        child: Text("OYUNU BAŞLAT", style: GoogleFonts.medievalSharp(fontSize: 24, color: AppColors.darkBrown, fontWeight: FontWeight.bold)),
                      )
                    : Text("Hostun başlatması bekleniyor...", style: GoogleFonts.medievalSharp(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRoleInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 5),
        Text(text, style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 18)),
      ],
    );
  }

  void _editLobbyName(BuildContext context, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.parchment,
        title: Text("Oda İsmini Değiştir", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown)),
        content: TextField(controller: controller, maxLength: 20),
        actions: [
          TextButton(child: const Text("İptal"), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text("Kaydet"), 
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _service.updateLobbyName(widget.roomId, controller.text.trim());
              }
              Navigator.pop(context);
            }
          ),
        ],
      ),
    );
  }

  void _kickPlayer(BuildContext context, String playerId, String playerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.parchment,
        title: Text("$playerName atılsın mı?", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown)),
        actions: [
          TextButton(child: const Text("Hayır"), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text("EVET, AT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
            onPressed: () {
              _service.removePlayer(widget.roomId, playerId);
              Navigator.pop(context);
            }
          ),
        ],
      ),
    );
  }

  void _leaveLobby(BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.parchment,
        title: Text("Lobiden çıkmak istiyor musun?", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown)),
        content: widget.isHost ? const Text("Host olduğun için oda kapanacak!") : null,
        actions: [
          TextButton(child: const Text("Hayır"), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text("Evet"), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.isHost) {
        await _service.deleteRoom(widget.roomId);
      } else {
        await _service.removePlayer(widget.roomId, _myUserId);
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showSettingsDialog(BuildContext context) {
    Map<String, dynamic> tempSettings = Map.from(_settings);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.parchment,
              title: Text("Oyun Ayarları", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Roller"),
                    _buildCounter("Vampir", tempSettings['vampires'], (val) => setState(() => tempSettings['vampires'] = val)),
                    _buildCounter("Doktor", tempSettings['doctors'], (val) => setState(() => tempSettings['doctors'] = val)),
                    _buildCounter("Gözcü", tempSettings['watchers'], (val) => setState(() => tempSettings['watchers'] = val)),
                    
                    const Divider(color: AppColors.saddleBrown),
                    
                    _buildSectionTitle("Süreler (Saniye)"),
                    _buildSlider("Gündüz Süresi", tempSettings['dayDuration'], 30, 180, (val) => setState(() => tempSettings['dayDuration'] = val)),
                    _buildSlider("Gece Süresi", tempSettings['nightDuration'], 10, 90, (val) => setState(() => tempSettings['nightDuration'] = val)),
                    _buildSlider("Oylama Süresi", tempSettings['votingDuration'], 10, 90, (val) => setState(() => tempSettings['votingDuration'] = val)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text("İPTAL", style: GoogleFonts.medievalSharp(color: Colors.red)),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text("KAYDET", style: GoogleFonts.medievalSharp(color: AppColors.saddleBrown, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _service.updateGameSettings(widget.roomId, tempSettings);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.saddleBrown)),
    );
  }

  Widget _buildSlider(String label, int value, double min, double max, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.medievalSharp(fontSize: 14)),
            Text("$value sn", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min,
          max: max,
          divisions: ((max - min) / 5).round(),
          activeColor: AppColors.saddleBrown,
          inactiveColor: Colors.grey[400],
          label: "$value",
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.medievalSharp(fontSize: 16)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle, color: AppColors.saddleBrown),
              onPressed: () => value > 0 ? onChanged(value - 1) : null,
            ),
            Text("$value", style: GoogleFonts.medievalSharp(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.saddleBrown),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}