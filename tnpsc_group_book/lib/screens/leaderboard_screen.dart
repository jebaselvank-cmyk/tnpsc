import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/streak_badge.dart';

// Helper to format seconds to human-readable string
String _formatTime(int seconds) {
  int minutes = seconds ~/ 60;
  int remSeconds = seconds % 60;
  if (minutes > 0) {
    return '$minutes ${AppLanguage.getString('min')} $remSeconds ${AppLanguage.getString('sec')}';
  }
  return '$remSeconds ${AppLanguage.getString('sec')}';
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDaily = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          _isDaily = _tabController.index == 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Container(
          // color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // Custom Header
              Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 25, bottom: 10),
                child: Text(
                  AppLanguage.getString('leaderboard'),
                  style: AppTheme.getStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: isDark ? Colors.white : AppTheme.textMainColor,
                  ),
                ),
              ),
              SizedBox(height: 10,),
              // Pill Tab Selector
              Center(
                child: Container(
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
                    labelStyle: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: AppTheme.getStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: AppLanguage.getString('daily')),
                      Tab(text: AppLanguage.getString('mock')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _LeaderboardContent(isDaily: true),
                          _LeaderboardContent(isDaily: false),
                        ],
                      ),
                    ),
                    // User's own rank sticky card at bottom
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _MyRankStickyCard(isDaily: _isDaily),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class _LeaderboardContent extends StatefulWidget {
  final bool isDaily;
  const _LeaderboardContent({required this.isDaily});

  @override
  State<_LeaderboardContent> createState() => _LeaderboardContentState();
}

class _LeaderboardContentState extends State<_LeaderboardContent> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService().getLeaderboard(isDaily: widget.isDaily, forceRefresh: false);
  }

  @override
  void didUpdateWidget(_LeaderboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDaily != widget.isDaily) {
      _future = FirestoreService().getLeaderboard(isDaily: widget.isDaily, forceRefresh: false);
    }
  }

  Future<void> _onRefresh() async {
    if (mounted) {
      setState(() {
        _future = FirestoreService().getLeaderboard(isDaily: widget.isDaily, forceRefresh: true);
      });
      await _future;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const _EmptyLeaderboard();
        }

        final users = snapshot.data!;
        final topThree = users.take(3).toList();
        final others = users.skip(3).toList();

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _TopThreeSection(topThree: topThree, isDaily: widget.isDaily),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 10, bottom: 120), // Bottom padding for sticky card
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = others[index];
                      return _LeaderboardItem(
                        user: user,
                        rank: index + 4,
                        isDaily: widget.isDaily
                      );
                    },
                    childCount: others.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopThreeSection extends StatelessWidget {
  final List<Map<String, dynamic>> topThree;
  final bool isDaily;
  const _TopThreeSection({required this.topThree, required this.isDaily});

  @override
  Widget build(BuildContext context) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    // Reorder for display: [2, 1, 3]
    List<Map<String, dynamic>?> displayOrder = List.filled(3, null);
    if (topThree.length >= 1) displayOrder[1] = topThree[0];
    if (topThree.length >= 2) displayOrder[0] = topThree[1];
    if (topThree.length >= 3) displayOrder[2] = topThree[2];

    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (displayOrder[0] != null)
            _TopThreeUser(user: displayOrder[0]!, rank: 2, isDaily: isDaily),
          if (displayOrder[1] != null)
            _TopThreeUser(user: displayOrder[1]!, rank: 1, isDaily: isDaily),
          if (displayOrder[2] != null)
            _TopThreeUser(user: displayOrder[2]!, rank: 3, isDaily: isDaily),
        ],
      ),
    );
  }
}

class _TopThreeUser extends StatelessWidget {
  final Map<String, dynamic> user;
  final int rank;
  final bool isDaily;
  const _TopThreeUser({required this.user, required this.rank, required this.isDaily});

  @override
  Widget build(BuildContext context) {
    bool isFirst = rank == 1;
    double avatarSize = isFirst ? 70 : 50;
    String name = user['userName'] ?? AppLanguage.getString('anonymous');
    int score = user['score'] ?? 0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8,right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFirst)
              const Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.workspace_premium, color: Colors.amber, size: 30),
              ),
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rank == 1 ? Colors.amber : rank == 2 ? Colors.blueGrey : Colors.orangeAccent,
                      width: isFirst ? 3 : 2,
                    ),
                    boxShadow: [
                      if (isFirst)
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: Colors.grey.shade900,
                    backgroundImage: NetworkImage(
                        user['photoURL'] != null && user['photoURL'].toString().isNotEmpty
                            ? user['photoURL']
                            : "https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}${user['gender'] == 'female' ? '-female' : user['gender'] == 'male' ? '-male' : ''}&backgroundColor=b6e3f4,c0aede,d1d4f9"
                    ),
                    child: user['photoURL'] == null || user['photoURL'].toString().isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: AppTheme.getStyle(
                              fontSize: isFirst ? 30 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white10,
                            ),
                          )
                        : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rank == 1 ? Colors.amber : rank == 2 ? Colors.blueGrey : Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "#$rank",
                    style: AppTheme.getStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if ((user['streak'] ?? 0) <= 7) const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: AppTheme.getStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((user['streak'] ?? 0) >= 7) ...[
                  const SizedBox(width: 2),
                  StreakBadge(streak: user['streak']),
                ],
              ],
            ),
            if ((user['streak'] ?? 0) <= 7) const SizedBox(height: 8),
            Text(
              _formatTime(user['timeTaken'] ?? 0),
              style: AppTheme.getStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              "$score / ${user['totalQuestions'] ?? (isDaily ? 20 : 50)}",
              style: AppTheme.getStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: rank == 1 ? Colors.amber : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrendIcon(user['yesterdayRank'], rank),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIcon(int? yesterdayRank, int currentRank) {
    if (yesterdayRank == null) return const SizedBox.shrink();
    if (yesterdayRank > currentRank) {
      return const Icon(Icons.arrow_drop_up, color: Colors.green, size: 20);
    } else if (yesterdayRank < currentRank) {
      return const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20);
    }
    return const Icon(Icons.remove, color: Colors.grey, size: 16);
  }
}

class _LeaderboardItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final int rank;
  final bool isDaily;
  const _LeaderboardItem({required this.user, required this.rank, required this.isDaily});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String name = user['userName'] ?? AppLanguage.getString('anonymous');
    int score = user['score'] ?? 0;
    
    // Real trend logic
    int? yesterdayRank = user['yesterdayRank'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              // Diamond Rank Indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: math.pi / 2,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
                      ),
                    ),
                  ),
                  Text(
                    "#$rank",
                    style: AppTheme.getStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade900,
                backgroundImage: NetworkImage(
                    user['photoURL'] != null && user['photoURL'].toString().isNotEmpty
                        ? user['photoURL']
                        : "https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}${user['gender'] == 'female' ? '-female' : user['gender'] == 'male' ? '-male' : ''}&backgroundColor=b6e3f4,c0aede,d1d4f9"
                ),
                child: user['photoURL'] == null || user['photoURL'].toString().isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                        style: AppTheme.getStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white10,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppTheme.getStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textMainColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((user['streak'] ?? 0) >= 7) ...[
                          const SizedBox(width: 2),
                          StreakBadge(streak: user['streak']),
                        ],
                      ],
                    ),
                    Text(
                      _formatTime(user['timeTaken'] ?? 0),
                      style: AppTheme.getStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15,),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$score / ${user['totalQuestions'] ?? (isDaily ? 20 : 50)}",
                    style: AppTheme.getStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildTrendIcon(yesterdayRank, rank),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIcon(int? yesterdayRank, int currentRank) {
    if (yesterdayRank == null) {
      return const Icon(Icons.remove, color: Colors.grey, size: 20);
    }
    if (yesterdayRank > currentRank) {
      return const Icon(Icons.arrow_drop_up, color: Colors.green, size: 24);
    } else if (yesterdayRank < currentRank) {
      return const Icon(Icons.arrow_drop_down, color: Colors.red, size: 24);
    }
    return const Icon(Icons.remove, color: Colors.grey, size: 20);
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("🏆", style: AppTheme.getStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              AppLanguage.getString('no_results_today'),
              style: AppTheme.getStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              isTamil ? 'தேர்வை முடித்து முதலில் இங்கே வரவும்!' : 'Finish a quiz and be the first one here!',
              style: AppTheme.getStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRankStickyCard extends StatefulWidget {
  final bool isDaily;
  const _MyRankStickyCard({required this.isDaily});

  @override
  State<_MyRankStickyCard> createState() => _MyRankStickyCardState();
}

class _MyRankStickyCardState extends State<_MyRankStickyCard> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService().getUserBestResultToday(isDaily: widget.isDaily, forceRefresh: false);
  }

  @override
  void didUpdateWidget(_MyRankStickyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDaily != widget.isDaily) {
      _future = FirestoreService().getUserBestResultToday(isDaily: widget.isDaily, forceRefresh: false);
    }
  }

  void _loadFuture({bool forceRefresh = false}) {
    if (mounted) {
      setState(() {
        _future = FirestoreService().getUserBestResultToday(isDaily: widget.isDaily, forceRefresh: forceRefresh);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
        final data = snapshot.data!;
        
        // Don't show the card if the user hasn't scored anything (score is 0 or null)
        if ((data['score'] ?? 0) <= 0) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: EdgeInsets.only(left: 5, right: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1E293B).withOpacity(0.7) 
                    : Colors.white.withOpacity(0.7),
                borderRadius: const BorderRadius.all(Radius.circular(30)),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (data['rank'] != null && data['rank'] > 0)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: math.pi / 1,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: AppTheme.secondaryColor, width: 2),
                              ),
                            ),
                          ),
                          Text(
                            "#${data['rank']}",
                            style: AppTheme.getStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade900,
                      backgroundImage: NetworkImage(
                          data['photoURL'] != null && data['photoURL'].toString().isNotEmpty
                              ? data['photoURL']
                              : "https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(data['userName'] ?? 'me')}${data['gender'] == 'female' ? '-female' : data['gender'] == 'male' ? '-male' : ''}&backgroundColor=b6e3f4,c0aede,d1d4f9"
                      ),
                      child: data['photoURL'] == null || data['photoURL'].toString().isEmpty
                          ? Text(
                              (data['userName'] ?? "Y").toString().isNotEmpty 
                                  ? (data['userName'] ?? "Y").toString()[0].toUpperCase() 
                                  : "Y",
                              style: AppTheme.getStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white10,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "${AppLanguage.getString('you_label')}: ${data['userName'] ?? AppLanguage.getString('anonymous')}",
                                  style: AppTheme.getStyle(
                                    color: isDark ? Colors.white : AppTheme.textMainColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if ((data['streak'] ?? 0) >= 7) ...[
                                const SizedBox(width: 2),
                                StreakBadge(streak: data['streak']),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                "${AppLanguage.getString('score')}: ${data['score']} / ${data['totalQuestions'] ?? (widget.isDaily ? 20 : 50)}",
                                style: AppTheme.getStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildTrendIcon(data['yesterdayRank'], data['rank'] ?? 0),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(data['timeTaken'] ?? 0),
                            style: AppTheme.getStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : Colors.grey),
                      onPressed: () => _loadFuture(forceRefresh: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendIcon(int? yesterdayRank, int currentRank) {
    if (yesterdayRank == null || yesterdayRank == 0) {
      return const Icon(Icons.remove, color: Colors.grey, size: 16);
    }
    if (yesterdayRank > currentRank) {
      return const Icon(Icons.arrow_drop_up, color: Colors.green, size: 20);
    } else if (yesterdayRank < currentRank) {
      return const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20);
    }
    return const Icon(Icons.remove, color: Colors.grey, size: 16);
  }
}
