// lib/models/game_settings.dart
import 'dart:math';

class GameSettings {
  final int players;
  final int vampires;
  final int doctors;
  final int watchers;

  const GameSettings({
    required this.players,
    required this.vampires,
    required this.doctors,
    required this.watchers,
  });

  // Oyuncu sayısına göre otomatik ayar yapan yardımcı fonksiyon
  factory GameSettings.fromPlayerCount(int count) {
    int v = 1; // En az 1 vampir
    if (count > 6) v = 2; // 7 kişiyseler 2 vampir olsun
    
    int d = (count > 4) ? 1 : 0; // 5 kişiden fazlaysa doktor olsun
    int w = (count > 5) ? 1 : 0; // 6 kişiden fazlaysa gözcü olsun

    return GameSettings(
      players: count,
      vampires: v,
      doctors: d,
      watchers: w,
    );
  }

  List<String> generateRoles() {
    final roles = <String>[];
    roles.addAll(List.filled(vampires, 'Vampir'));
    roles.addAll(List.filled(doctors, 'Doktor'));
    roles.addAll(List.filled(watchers, 'Gözcü'));
    
    final villagersCount = players - roles.length;
    if (villagersCount > 0) {
      roles.addAll(List.filled(villagersCount, 'Köylü'));
    }

    // Karıştırma Algoritması (Shuffle)
    final random = Random();
    for (int i = roles.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = roles[i];
      roles[i] = roles[j];
      roles[j] = temp;
    }
    return roles;
  }
}