// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Ayar değerlerini tutacak değişkenler
  int _vampires = 1;
  int _doctors = 1;
  int _watchers = 1;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _service.getGameStream(widget.roomId),
      builder: (context, gameSnapshot) {
        
        if (gameSnapshot.hasData && gameSnapshot.data!.exists) {
          var gameData = gameSnapshot.data!.data() as Map<String, dynamic>;
          
          // Oyun başladıysa yönlendir
          if (gameData['status'] == 'playing') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => GameScreen(roomId: widget.roomId)),
                );
              }
            });
          }

          // Güncel ayarları al (Host değilsek ekranımızda güncel görünsün)
          var settings = gameData['settings'] as Map<String, dynamic>?;
          if (settings != null) {
            _vampires = settings['vampires'] ?? 1;
            _doctors = settings['doctors'] ?? 1;
            _watchers = settings['watchers'] ?? 1;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text("ODA: ${widget.roomId}", style: GoogleFonts.medievalSharp(color: AppColors.gold)),
            backgroundColor: AppColors.darkBrown,
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              // SADECE HOST İÇİN AYAR BUTONU
              if (widget.isHost)
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.gold),
                  onPressed: () => _showSettingsDialog(context),
                )
            ],
          ),
          body: Column(
            children: [
              // AYAR BİLGİ KARTI (Herkes görsün)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: AppColors.saddleBrown.withOpacity(0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRoleInfo(Icons.bloodtype, "Vampir: $_vampires", Colors.red),
                    _buildRoleInfo(Icons.medical_services, "Doktor: $_doctors", Colors.green),
                    _buildRoleInfo(Icons.visibility, "Gözcü: $_watchers", Colors.blue),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Text(
                "Beklenen Oyuncular...",
                style: GoogleFonts.medievalSharp(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // OYUNCU LİSTESİ
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _service.getPlayersStream(widget.roomId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var players = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        var player = players[index].data() as Map<String, dynamic>;
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // BAŞLAT BUTONU (HOST)
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
                          // TODO: Oyuncu sayısı rollerden azsa uyarı verilebilir
                          _service.assignRolesAndStart(widget.roomId);
                        },
                        child: Text("OYUNU BAŞLAT", style: GoogleFonts.medievalSharp(fontSize: 24, color: AppColors.darkBrown, fontWeight: FontWeight.bold)),
                      )
                    : Text("Hostun ayarları yapması bekleniyor...", style: GoogleFonts.medievalSharp(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
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
        Text(text, style: GoogleFonts.medievalSharp(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  // AYAR PENCERESİ (HOST İÇİN)
  void _showSettingsDialog(BuildContext context) {
    int tempV = _vampires;
    int tempD = _doctors;
    int tempW = _watchers;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.parchment,
              title: Text("Rol Ayarları", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCounter("Vampir Sayısı", tempV, (val) => setState(() => tempV = val)),
                  _buildCounter("Doktor Sayısı", tempD, (val) => setState(() => tempD = val)),
                  _buildCounter("Gözcü Sayısı", tempW, (val) => setState(() => tempW = val)),
                  const SizedBox(height: 10),
                  Text("Geriye kalanlar KÖYLÜ olacaktır.", style: GoogleFonts.medievalSharp(color: Colors.grey[700], fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  child: Text("İPTAL", style: GoogleFonts.medievalSharp(color: Colors.red)),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text("KAYDET", style: GoogleFonts.medievalSharp(color: AppColors.saddleBrown, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _service.updateGameSettings(widget.roomId, tempV, tempD, tempW);
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