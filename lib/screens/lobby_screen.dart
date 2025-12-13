import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ODA KODU: ${widget.roomId}", style: GoogleFonts.medievalSharp(color: AppColors.gold)),
        backgroundColor: AppColors.darkBrown,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "Beklenen Oyuncular...",
            style: GoogleFonts.medievalSharp(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          
          // OYUNCU LİSTESİ (CANLI AKIŞ)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.getPlayersStream(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var players = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
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
                          child: Icon(
                            isMeHost ? Icons.star : Icons.person,
                            color: AppColors.darkBrown,
                          ),
                        ),
                        title: Text(
                          player['name'],
                          style: GoogleFonts.medievalSharp(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                        trailing: isMeHost 
                            ? Text("HOST", style: GoogleFonts.medievalSharp(color: AppColors.gold, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ALT PANEL
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
                      _service.startGame(widget.roomId);
                    },
                    child: Text(
                      "OYUNU BAŞLAT",
                      style: GoogleFonts.medievalSharp(
                        fontSize: 24, 
                        color: AppColors.darkBrown, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  )
                : Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.gold),
                      const SizedBox(height: 10),
                      Text(
                        "Oyunun başlatılması bekleniyor...",
                        style: GoogleFonts.medievalSharp(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}