// lib/utils/role_assets.dart
class RoleAssets {
  static const String welcome = 'assets/images/welcome_screen.jpg';

  static String getRoleBackground(String role) {
    switch (role) {
      case 'Vampir':
        return 'assets/images/vampir_role.jpg';
      case 'Doktor':
        return 'assets/images/doktor_role.jpg';
      case 'Gözcü':
        return 'assets/images/gozcu_role.jpg';
      case 'Köylü':
        return 'assets/images/koylu_role.jpg';
      default:
        return 'assets/images/koylu_role.jpg';
    }
  }
}