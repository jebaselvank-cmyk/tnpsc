import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import '../utils/app_icons.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final String currentAvatar;
  final int currentPoints;

  const AvatarSelectionScreen({
    super.key,
    required this.currentAvatar,
    required this.currentPoints,
  });

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedStyle;
  bool _isUpdating = false;

  final List<Map<String, dynamic>> _avatarStyles = [
    {'id': 'pixel-art', 'name': 'Pixel Art', 'cost': 2000},
    {'id': 'open-peeps', 'name': 'Open Peeps', 'cost': 2000},
    {'id': 'big-ears', 'name': 'Big Ears', 'cost': 2500},
    {'id': 'big-smile', 'name': 'Big Smile', 'cost': 2500},
    {'id': 'bottts', 'name': 'Bottts', 'cost': 3000},
    {'id': 'croodles', 'name': 'Croodles', 'cost': 3500},
    {'id': 'lorelei', 'name': 'Lorelei', 'cost': 4500},
    {'id': 'avataaars', 'name': 'Avataaars', 'cost': 4500},
    {'id': 'adventurer', 'name': 'Adventurer', 'cost': 5000},
    {'id': 'notionists', 'name': 'Notionists', 'cost': 5500},
    {'id': 'shapes', 'name': 'Shapes', 'cost': 6000},
    {'id': 'fun-emoji', 'name': 'Fun Emoji', 'cost': 6000},
    {'id': 'micah', 'name': 'Micah', 'cost': 6500},
    {'id': 'miniavs', 'name': 'Mini Avatars', 'cost': 6500},
    {'id': 'personas', 'name': 'Personas', 'cost': 7000},
    {'id': 'identicon', 'name': 'Identicon', 'cost': 1500},
    {'id': 'rings', 'name': 'Rings', 'cost': 1500},
    {'id': 'initials', 'name': 'Initials', 'cost': 1000},
    {'id': 'icons', 'name': 'Icons', 'cost': 4000},
    {'id': 'pixel-art-neutral', 'name': 'Pixel Art Neutral', 'cost': 2500},
  ];

  static const List<String> _bgColors = [
    'b6e3f4', 'c0aede', 'd1d4f9', 'ffd5dc', 'ffdfbf', 'c9f3e4', 'ffda9e', 
    'ffb3ba', 'baffc9', 'bae1ff', 'ffffba', 'ffdfba', 'e0bbe4', '957dad', 
    'd291bc', 'fec8d8', 'ffdfd3', 'b3e5fc', 'c8e6c9', 'fff9c4', 'ffccbc', 'cfd8dc'
  ];

  String _getAvatarUrl(String style, {int? variationIndex}) {
    final user = FirebaseAuth.instance.currentUser;
    final baseSeed = user?.displayName ?? user?.uid ?? 'user';
    final seed = variationIndex != null ? "${baseSeed}_$variationIndex" : baseSeed;
    final encodedSeed = Uri.encodeComponent(seed);
    return "https://api.dicebear.com/7.x/$style/png?seed=$encodedSeed&backgroundColor=${_bgColors.join(',')}";
  }

  void _showVariations(Map<String, dynamic> style) {
    if (widget.currentPoints < style['cost']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.languageNotifier.value == 'ta'
                ? "உங்களிடம் போதிய புள்ளிகள் இல்லை!"
                : "You don't have enough points!",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style['name'],
                        style: AppTheme.getStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textMainColor,
                        ),
                      ),
                      Text(
                        AppLanguage.languageNotifier.value == 'ta' 
                          ? "உங்களுக்கு பிடித்ததை தேர்வு செய்யவும்"
                          : "Pick your favorite variation",
                        style: AppTheme.getStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "${style['cost']}",
                          style: AppTheme.getStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: 100,
                  itemBuilder: (context, index) {
                    final url = _getAvatarUrl(style['id'], variationIndex: index);
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _handleAvatarSelection(style, url);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor.withOpacity(0.5),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Icon(Icons.face_retouching_natural_rounded, color: Colors.grey.withOpacity(0.5), size: 30),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleAvatarSelection(Map<String, dynamic> style, String chosenUrl) async {
    if (widget.currentPoints < style['cost']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.languageNotifier.value == 'ta'
                ? "உங்களிடம் போதிய புள்ளிகள் இல்லை!"
                : "You don't have enough points!",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          AppLanguage.languageNotifier.value == 'ta' ? "உறுதிப்படுத்துக" : "Confirm Purchase",
          style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: Text(
          AppLanguage.languageNotifier.value == 'ta'
              ? "${style['cost']} புள்ளிகளைச் செலவழித்து இந்த அவதாரை மாற்ற விரும்புகிறீர்களா?"
              : "Are you sure you want to spend ${style['cost']} points to change your avatar?",
          style: AppTheme.getStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLanguage.getString('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              AppLanguage.languageNotifier.value == 'ta' ? "சரி" : "Confirm",
              style: AppTheme.getStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isUpdating = true);
      bool success = await _firestoreService.updateAvatar(chosenUrl, style['cost']);
      
      if (mounted) {
        setState(() => _isUpdating = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLanguage.languageNotifier.value == 'ta'
                    ? "அவதார் மாற்றப்பட்டது!"
                    : "Avatar updated successfully!",
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLanguage.getString('error_generic')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLanguage.languageNotifier.value == 'ta' ? "அவதார் தேர்வு" : "Select Avatar",
          style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      "${widget.currentPoints}",
                      style: AppTheme.getStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _avatarStyles.length,
            itemBuilder: (context, index) {
              final style = _avatarStyles[index];
              final bool canAfford = widget.currentPoints >= style['cost'];
              final avatarUrl = _getAvatarUrl(style['id']);

              return InkWell(
                onTap: _isUpdating ? null : () => _showVariations(style),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: canAfford 
                          ? (isDark ? Colors.white10 : Colors.black12)
                          : Colors.red.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor.withOpacity(0.5),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.face, color: Colors.grey.withOpacity(0.5), size: 30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        style['name'],
                        style: AppTheme.getStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textMainColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.stars_rounded, 
                            size: 14, 
                            color: canAfford ? Colors.orange : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${style['cost']} pts",
                            style: AppTheme.getStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: canAfford ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isUpdating)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
