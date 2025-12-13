// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../utils/role_assets.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final String _myUserId = FirebaseAuth.instance.currentUser!.uid;
  late ConfettiController _confettiController;
  
  bool _isRoleVisible = false;
  String? _myRole;
  String _myDocId = "";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchMyRole();
  }

  // Kendi rolümüzü veritabanından bir kere çekip hafızaya alalım
  void _fetchMyRole() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.roomId)
          .collection('players')
          .doc(_myUserId)
          .get();
          
      if (doc.exists && mounted) {
        setState(() {
          _myRole = doc.data()?['role'] ?? 'Köylü';
          _myDocId = doc.id;
        });
      }
    } catch (e) {
      print("Rol çekme hatası: $e");
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String role) {
    return switch (role) {
      'Vampir' => Colors.red.shade900,
      'Köylü' => Colors.blue.shade800,
      'Doktor' => Colors.green.shade800,
      'Gözcü' => Colors.orange.shade800,
      _ => Colors.grey.shade800,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Rol henüz yüklenmediyse bekle
    if (_myRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.saddleBrown)));
    }

    final roleColor = _getRoleColor(_myRole!);
    // Rol görünürse rolün görseli, değilse Welcome görseli
    final bgImage = _isRoleVisible 
        ? RoleAssets.getRoleBackground(_myRole!) 
        : RoleAssets.welcome;

    return Scaffold(
      body: Stack(
        children: [
          // 1. ARKA PLAN (ANİMASYONLU GEÇİŞ)
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(bgImage),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
              ),
            ),
          ),

          // 2. KONFETİ (Sadece rol ilk açıldığında)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              // DÜZELTME BURADA: const kaldırıldı ve AppColors.gold kullanıldı
              colors: [Colors.red, Colors.blue, AppColors.gold, Colors.green],
            ),
          ),

          // 3. İÇERİK
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO (Rol gizliyken göster)
                    if (!_isRoleVisible)
                      Image.asset('assets/icon/logo.png', height: 120)
                          .animate()
                          .scale(duration: 500.ms, curve: Curves.easeOut),

                    const SizedBox(height: 40),

                    // ROL KARTI / BUTONU
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRoleVisible = !_isRoleVisible;
                          if (_isRoleVisible) _confettiController.play();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutBack,
                        width: double.infinity,
                        height: _isRoleVisible ? 400 : 100, // Açılınca büyüsün
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isRoleVisible ? roleColor.withOpacity(0.8) : AppColors.saddleBrown,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors.gold, 
                            width: _isRoleVisible ? 4 : 2
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)
                          ]
                        ),
                        child: _isRoleVisible 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("SENİN ROLÜN:", style: GoogleFonts.medievalSharp(color: Colors.white70, fontSize: 18)),
                                const SizedBox(height: 20),
                                Text(
                                  _myRole!.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.medievalSharp(
                                    fontSize: 48, 
                                    fontWeight: FontWeight.bold, 
                                    color: AppColors.gold,
                                    shadows: [const Shadow(blurRadius: 10, color: Colors.black)]
                                  ),
                                ).animate().fadeIn(delay: 200.ms).scale(),
                                const SizedBox(height: 20),
                                Text("(Gizlemek için dokun)", style: GoogleFonts.medievalSharp(color: Colors.white30, fontSize: 12)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app, color: AppColors.gold, size: 32),
                                const SizedBox(width: 15),
                                Text(
                                  "ROLÜNÜ GÖRMEK İÇİN DOKUN",
                                  style: GoogleFonts.medievalSharp(
                                    color: AppColors.parchment, 
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}