import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'account_info_page.dart';

/// Profil sayfası: avatar (galeriden seçilebilir), kullanıcı adı, üyelik tipi, Ayarlar (Hesap Bilgileri, Tema).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
  });

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _darkModeOn = true;
  String? _displayName;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await ProfileService.getDisplayName();
    final imagePath = await ProfileService.getProfileImagePath();
    setState(() {
      _displayName = name;
      _profileImagePath = imagePath;
    });
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (xFile == null || !mounted) return;
    await ProfileService.setProfileImageFromFile(xFile.path);
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
            title: 'Profil',
            leading: const SizedBox(width: 40, height: 40),
            trailing: const SizedBox(width: 40, height: 40),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  _buildSectionTitle('AYARLAR'),
                  _buildSettingsRow(
                    icon: Icons.person_outline,
                    label: 'Hesap Bilgileri',
                    onTap: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => const AccountInfoPage()),
                      );
                      if (saved == true) _loadProfile();
                    },
                  ),
                  _buildThemeRow(),
                  // Bildirim Ayarları - şimdilik yorum
                  // _buildSettingsRow(icon: Icons.notifications_outlined, label: 'Bildirim Ayarları', onTap: () {}),
                  // DESTEK - şimdilik yorum
                  // _buildSectionTitle('DESTEK'),
                  // _buildSettingsRow(icon: Icons.info_outline, label: 'Hakkımızda', onTap: () {}, iconBgGray: true),
                  // Çıkış Yap - şimdilik yorum
                  // const SizedBox(height: 16),
                  // _buildLogoutRow(),
                ],
              ),
            ),
          ),
          if (widget.showBottomBar)
            BottomNavBar(activeIndex: 3, onTabTap: widget.onTabTap),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2094F3).withValues(alpha: 0.3), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2094F3).withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: _profileImagePath != null && File(_profileImagePath!).existsSync()
                    ? Image.file(
                        File(_profileImagePath!),
                        fit: BoxFit.cover,
                        width: 128,
                        height: 128,
                      )
                    : Container(
                        color: const Color(0xFF27272A),
                        child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 64),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _displayName?.trim().isNotEmpty == true ? _displayName! : 'Kullanıcı Adı',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
    bool iconBgGray = false,
  }) {
    final iconBg = iconBgGray ? const Color(0xFF374151) : const Color(0xFF2094F3).withValues(alpha: 0.15);
    final iconColor = iconBgGray ? const Color(0xFF9CA3AF) : const Color(0xFF2094F3);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
          ],
        ),
      ),
    );
  }

  /// Tema: görünür ama değiştirilemez (disabled).
  Widget _buildThemeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2094F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF2094F3), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tema',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _darkModeOn ? 'Karanlık Mod Açık' : 'Karanlık Mod Kapalı',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _darkModeOn,
            onChanged: null,
            activeTrackColor: const Color(0xFF2094F3),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
