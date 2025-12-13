import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ODA KURMA
  void _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError("Lütfen önce bir isim giriniz!");
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Oda oluşturuluyor...", style: GoogleFonts.medievalSharp(color: Colors.white)),
        backgroundColor: AppColors.saddleBrown,
        duration: const Duration(seconds: 1),
      ),
    );

    FirestoreService service = FirestoreService();
    String? roomId = await service.createRoom(name);

    if (roomId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            roomId: roomId,
            isHost: true,
          ),
        ),
      );
    } else {
      if (mounted) _showError("Oda kurulamadı, internet bağlantını kontrol et.");
    }
  }

  // ODAYA KATILMA
  void _joinRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError("Lütfen önce bir isim giriniz!");
      return;
    }

    String? roomId = await showDialog<String>(
      context: context,
      builder: (context) {
        String inputCode = "";
        return AlertDialog(
          backgroundColor: AppColors.parchment,
          title: Text("Oda Kodu Gir", style: GoogleFonts.medievalSharp(color: AppColors.darkBrown)),
          content: TextField(
            onChanged: (val) => inputCode = val,
            decoration: const InputDecoration(hintText: "Örn: X9K2L"),
          ),
          actions: [
            TextButton(
              child: Text("İPTAL", style: GoogleFonts.medievalSharp(color: Colors.red)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("KATIL", style: GoogleFonts.medievalSharp(color: AppColors.saddleBrown, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, inputCode.toUpperCase().trim()),
            ),
          ],
        );
      },
    );

    if (roomId == null || roomId.isEmpty) return;

    FirestoreService service = FirestoreService();
    bool success = await service.joinRoom(roomId, name);

    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            roomId: roomId,
            isHost: false,
          ),
        ),
      );
    } else {
      if (mounted) _showError("Odaya katılınamadı! Kod hatalı olabilir.");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.medievalSharp(color: Colors.white)),
        backgroundColor: AppColors.saddleBrown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/welcome_screen.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icon/logo.png', height: 150),
                const SizedBox(height: 20),
                Text(
                  "VAMPİR KÖYLÜ",
                  style: GoogleFonts.medievalSharp(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                    shadows: [
                      const Shadow(blurRadius: 10, color: Colors.black, offset: Offset(2, 2))
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Oyuncu Adınız",
                      hintStyle: TextStyle(color: Colors.white54),
                      icon: Icon(Icons.person, color: AppColors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildMenuButton("ODA KUR", Icons.add_home_work, _createRoom),
                const SizedBox(height: 15),
                _buildMenuButton("ODAYA KATIL", Icons.login, _joinRoom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.saddleBrown,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: AppColors.gold, width: 2),
          ),
          elevation: 10,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 28),
            const SizedBox(width: 15),
            Text(
              text,
              style: GoogleFonts.medievalSharp(
                fontSize: 24,
                color: AppColors.parchment,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}