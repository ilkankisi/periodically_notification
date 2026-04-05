/// Rozet tanımı (sabit katalog).
class GamificationBadgeDef {
  final String id;
  final String title;
  final String description;
  final String emoji;

  const GamificationBadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
  });

  static const List<GamificationBadgeDef> catalog = [
    GamificationBadgeDef(
      id: 'streak_7',
      title: 'Haftalık Zincir',
      description: 'En az 7 gün üst üste aksiyon ekledin; zinciri kırmadın.',
      emoji: '🔥',
    ),
    GamificationBadgeDef(
      id: 'streak_30',
      title: 'Aylık İrade',
      description: 'En az 30 gün kesintisiz aksiyon — güçlü alışkanlık.',
      emoji: '🌙',
    ),
    GamificationBadgeDef(
      id: 'streak_365',
      title: 'Yıllık Efsane',
      description: 'Bir yıllık zincire denk gelecek kesintisiz seri (365+ gün üst üste).',
      emoji: '👑',
    ),
    GamificationBadgeDef(
      id: 'social_first',
      title: 'İlk Sözün',
      description: 'Toplulukta ilk yorumunu paylaştın.',
      emoji: '💬',
    ),
    GamificationBadgeDef(
      id: 'social_10',
      title: 'Sohbetçi',
      description: '10 yorumla etkileşimi artırdın.',
      emoji: '🗨️',
    ),
    GamificationBadgeDef(
      id: 'social_50',
      title: 'Topluluk Sesi',
      description: '50 yorumla sosyal puanda öne çıktın.',
      emoji: '⭐',
    ),
    GamificationBadgeDef(
      id: 'social_thread',
      title: 'Tartışmaya Katıldın',
      description: 'Aynı içerikte başka yazarlar varken yazdın veya bir yoruma yanıt verdin.',
      emoji: '🤝',
    ),
  ];

  static GamificationBadgeDef? byId(String id) {
    try {
      return catalog.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
