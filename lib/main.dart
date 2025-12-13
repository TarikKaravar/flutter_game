import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'config/app_colors.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlatıyoruz
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: VampirKoyluApp()));
}

class VampirKoyluApp extends StatelessWidget {
  const VampirKoyluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vampir Köylü Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.parchment,
        primaryColor: AppColors.saddleBrown,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.darkBrown,
          primary: AppColors.saddleBrown,
          secondary: AppColors.gold,
        ),
        textTheme: GoogleFonts.medievalSharpTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}