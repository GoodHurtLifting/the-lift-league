import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/widgets/lifetime_stats.dart';
import 'package:lift_league/widgets/badge_display.dart';
import 'package:lift_league/widgets/big_three_prs.dart';
import 'package:lift_league/widgets/checkin_graph.dart';
import 'package:lift_league/widgets/consistency_meter.dart';
import 'package:lift_league/widgets/efficiency_meter.dart';
import 'package:lift_league/widgets/momentum_meter.dart';
import 'package:lift_league/widgets/stats/calories_workout_chart.dart';
import 'package:lift_league/widgets/stats/body_weight_chart.dart';
import 'package:lift_league/widgets/stats/widget_picker_bottom_sheet.dart';
import 'package:lift_league/services/db_service.dart';

const Map<String, String> _widgetNames = {
  'lifetimeStats': 'Lifetime Stats',
  'consistencyMeter': 'Consistency',
  'efficiencyMeter': 'Efficiency',
  'momentumMeter': 'Momentum',
  'caloriesChart': 'Calories Chart',
  'bodyWeightChart': 'Body Weight Chart',
  'checkInGraph': 'Check-In Graph',
  'bigThreePrs': 'Big Three PRs',
  'badgeDisplay': 'Badges',
};

const List<String> _defaultLayout = [
  'lifetimeStats',
  'consistencyMeter',
  'efficiencyMeter',
  'momentumMeter',
  'caloriesChart',
  'bodyWeightChart',
  'checkInGraph',
  'bigThreePrs',
  'badgeDisplay',
];

class UserStatsScreen extends StatefulWidget {
  final String userId;
  final String? blockId;
  final bool showCheckInGraph;

  const UserStatsScreen({
    super.key,
    required this.userId,
    this.blockId,
    this.showCheckInGraph = true,
  });

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  late Future<Map<String, dynamic>?> _userFuture;
  late Future<List<String>> _layoutFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserData();
    _layoutFuture = _fetchLayout();
  }
  Future<Map<String, dynamic>?> _fetchUserData() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    final data = doc.data();

    if (widget.blockId == null) {
      String? activeId = data?['activeBlockInstanceId']?.toString();
      activeId ??= await DBService().getActiveBlockInstanceId(widget.userId);
      if (activeId != null) {
        data?['activeBlockInstanceId'] = activeId;
      }
    }

    return data;
  }

  Future<List<String>> _fetchLayout() async {
    final doc = await FirebaseFirestore.instance
        .doc('users/${widget.userId}/preferences')
        .get();
    final data = doc.data();
    if (data != null && data['statsLayout'] is List) {
      return List<String>.from(data['statsLayout']);
    }
    return _defaultLayout;
  }

  List<Widget> _buildWidgets(List<String> layout, Map<String, dynamic> userData) {
    final activeBlockId =
        widget.blockId ?? userData['activeBlockInstanceId']?.toString();
    final widgets = <Widget>[];
    bool shownNoBlockMsg = false;
    for (final id in layout) {
      switch (id) {
        case 'lifetimeStats':
          widgets.add(LifetimeStats(userId: widget.userId));
          widgets.add(const SizedBox(height: 20));
          break;
        case 'consistencyMeter':
          if (activeBlockId == null) {
            if (!shownNoBlockMsg) {
              widgets.add(
                  const Text('Start a training block to track your stats!'));
              widgets.add(const SizedBox(height: 20));
              shownNoBlockMsg = true;
            }
          } else {
            widgets.add(const Text('Consistency',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
            widgets.add(const SizedBox(height: 8));
            widgets.add(ConsistencyMeter(
                userId: widget.userId,
                blockId: int.tryParse(activeBlockId) ?? 0));
            widgets.add(const SizedBox(height: 20));
          }
          break;
        case 'efficiencyMeter':
          if (activeBlockId != null) {
            widgets.add(const Text('Efficiency',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
            widgets.add(const SizedBox(height: 8));
            widgets.add(EfficiencyMeter(
                userId: widget.userId, blockId: activeBlockId));
            widgets.add(const SizedBox(height: 20));
          }
          break;
        case 'momentumMeter':
          if (activeBlockId != null) {
            widgets.add(const Text('Momentum',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
            widgets.add(const SizedBox(height: 8));
            widgets.add(MomentumMeter(userId: widget.userId));
            widgets.add(const SizedBox(height: 20));
          }
          break;
        case 'caloriesChart':
          widgets.add(CaloriesWorkoutChart(userId: widget.userId));
          widgets.add(const SizedBox(height: 20));
          break;
        case 'bodyWeightChart':
          widgets.add(BodyWeightChart(userId: widget.userId));
          widgets.add(const SizedBox(height: 20));
          break;
        case 'checkInGraph':
          if (widget.showCheckInGraph) {
            widgets.add(CheckInGraph(userId: widget.userId));
            widgets.add(const SizedBox(height: 20));
          }
          break;
        case 'bigThreePrs':
          widgets.add(BigThreePRs(userId: widget.userId));
          widgets.add(const SizedBox(height: 20));
          break;
        case 'badgeDisplay':
          widgets.add(BadgeDisplay(userId: widget.userId));
          widgets.add(const SizedBox(height: 20));
          break;
      }
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          FutureBuilder<List<String>>(
            future: _layoutFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.error),
                  tooltip: snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () async {
                  final newLayout = await showModalBottomSheet<List<String>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => WidgetPickerBottomSheet(
                      userId: widget.userId,
                      currentLayout: snapshot.data!,
                      availableWidgets: _widgetNames,
                    ),
                  );
                  if (newLayout != null) {
                    setState(() {
                      _layoutFuture = Future.value(newLayout);
                    });
                  }
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error.toString()}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!;
          final displayName = userData['displayName'] ?? 'Unknown User';
          final title = userData['title'] ?? '';

          return FutureBuilder<List<String>>(
            future: _layoutFuture,
            builder: (context, layoutSnap) {
              if (layoutSnap.hasError) {
                return Center(child: Text('Error: ${layoutSnap.error.toString()}'));
              }
              if (!layoutSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final layout = layoutSnap.data!;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFC3B3D)),
                        ),
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ..._buildWidgets(layout, userData),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
