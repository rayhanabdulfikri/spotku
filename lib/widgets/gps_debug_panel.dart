import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/spot_model.dart';
import '../models/geofence_state.dart';
import '../services/geofence_service.dart';

/// Widget Panel Debug GPS Accuracy & Geofence Status Monitor + Event Logger.
/// Terhubung langsung ke GeofenceService (Single Source of Truth, Event-Driven).
/// Hanya aktif dan ditampilkan pada mode Debug (kDebugMode).
class GpsDebugPanel extends StatefulWidget {
  final List<Spot> spots;

  const GpsDebugPanel({
    super.key,
    required this.spots,
  });

  @override
  State<GpsDebugPanel> createState() => _GpsDebugPanelState();
}

class _GpsDebugPanelState extends State<GpsDebugPanel> {
  StreamSubscription<GeofenceState>? _stateSubscription;
  late GeofenceState _geoState;
  bool _isMinimized = false;
  int _activeTab = 0; // 0: Status Monitor, 1: Event Log

  @override
  void initState() {
    super.initState();
    _geoState = GeofenceService().currentState;

    // Stream terpusat Single Source of Truth
    _stateSubscription = GeofenceService().stateStream.listen((GeofenceState state) {
      if (!mounted) return;
      setState(() {
        _geoState = state;
      });
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final state = _geoState;
    final position = state.position;
    final entryRadius = GeofenceService().entryRadiusMeters;
    final exitRadius = GeofenceService().exitRadiusMeters;

    // Formatting string
    String latStr = position != null ? position.latitude.toStringAsFixed(6) : "Menunggu GPS...";
    String lngStr = position != null ? position.longitude.toStringAsFixed(6) : "Menunggu GPS...";
    String accuracyStr = position != null
        ? "${position.accuracy.toStringAsFixed(1)} m (${state.accuracyCategory})"
        : "-";
    String speedStr = position != null ? "${position.speed.toStringAsFixed(1)} m/s" : "-";
    String headingStr = position != null ? "${position.heading.toStringAsFixed(0)}°" : "-";
    String altitudeStr = position != null ? "${position.altitude.toStringAsFixed(1)} m" : "-";
    String distanceStr = state.nearestDistance.isFinite
        ? "${state.nearestDistance.toStringAsFixed(1)} m"
        : "-";
    String nearestMarkerStr = state.nearestSpot?.title ?? "Tidak Ada";
    String currentStateStr = state.currentState;
    String previousStateStr = state.previousState;
    String timerStatus = state.isTimerRunning ? "RUNNING" : "STOPPED";
    String gpsProviderStr = state.gpsProvider;
    String timestampStr = state.timestamp != null
        ? DateFormat('HH:mm:ss').format(state.timestamp!)
        : "-";

    String lastNotifStr = state.lastNotifTime != null
        ? DateFormat('HH:mm:ss').format(state.lastNotifTime!)
        : "-";
    String nextNotifStr = state.nextNotifTime != null
        ? DateFormat('HH:mm:ss').format(state.nextNotifTime!)
        : "-";

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 12,
      right: _isMinimized ? 76 : 12, // Tidak menutupi FAB (+) saat minimize
      bottom: _isMinimized ? (16 + bottomPadding) : (85 + bottomPadding),
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: _isMinimized ? 52 : 340,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.teal.shade300, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Toggle Tabs (Dapat diklik di seluruh area header untuk Minimize / Expand)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isMinimized = !_isMinimized;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bug_report, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'GPS DEBUG',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.teal.shade200,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isMinimized) ...[
                          _buildTabButton(0, 'MONITOR'),
                          const SizedBox(width: 3),
                          _buildTabButton(1, 'LOGS (${state.eventLogs.length})'),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: currentStateStr == 'INSIDE'
                                ? Colors.green.shade800
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentStateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isMinimized ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!_isMinimized) ...[
                const Divider(color: Colors.white24, height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _activeTab == 0
                        ? _buildMonitorTab(
                            latStr: latStr,
                            lngStr: lngStr,
                            accuracyStr: accuracyStr,
                            speedStr: speedStr,
                            headingStr: headingStr,
                            altitudeStr: altitudeStr,
                            distanceStr: distanceStr,
                            nearestMarkerStr: nearestMarkerStr,
                            currentStateStr: currentStateStr,
                            previousStateStr: previousStateStr,
                            timerStatus: timerStatus,
                            gpsProviderStr: gpsProviderStr,
                            timestampStr: timestampStr,
                            lastNotifStr: lastNotifStr,
                            nextNotifStr: nextNotifStr,
                            entryRadius: entryRadius,
                            exitRadius: exitRadius,
                          )
                        : _buildEventLogTab(state.eventLogs),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? Colors.teal.shade700 : Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMonitorTab({
    required String latStr,
    required String lngStr,
    required String accuracyStr,
    required String speedStr,
    required String headingStr,
    required String altitudeStr,
    required String distanceStr,
    required String nearestMarkerStr,
    required String currentStateStr,
    required String previousStateStr,
    required String timerStatus,
    required String gpsProviderStr,
    required String timestampStr,
    required String lastNotifStr,
    required String nextNotifStr,
    required double entryRadius,
    required double exitRadius,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('GPS LOCATION'),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.8)},
          children: [
            _buildTableRow('Latitude / Lng', '$latStr, $lngStr'),
            _buildTableRow('Accuracy', accuracyStr, isHighlighted: true),
            _buildTableRow('Speed / Heading', '$speedStr / $headingStr'),
            _buildTableRow('Altitude', altitudeStr),
            _buildTableRow('GPS Provider', gpsProviderStr),
          ],
        ),
        const SizedBox(height: 6),
        _buildSectionHeader('MARKER TARGET'),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.8)},
          children: [
            _buildTableRow('Jumlah Marker', '${widget.spots.length}',
                color: widget.spots.isEmpty ? Colors.orangeAccent : Colors.white),
            _buildTableRow('Nearest Marker', nearestMarkerStr),
            _buildTableRow('Distance', distanceStr, isHighlighted: true),
          ],
        ),
        const SizedBox(height: 6),
        _buildSectionHeader('GEOFENCE ENGINE'),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.8)},
          children: [
            _buildTableRow('Current State', currentStateStr,
                color: currentStateStr == 'INSIDE' ? Colors.lightGreenAccent : Colors.white),
            _buildTableRow('Previous State', previousStateStr),
            _buildTableRow('Entry Radius', '${entryRadius.toStringAsFixed(1)} m'),
            _buildTableRow('Exit Radius', '${exitRadius.toStringAsFixed(1)} m'),
          ],
        ),
        const SizedBox(height: 6),
        _buildSectionHeader('NOTIFICATION SYSTEM'),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.8)},
          children: [
            _buildTableRow('Timer Status', timerStatus,
                color: timerStatus == 'RUNNING' ? Colors.amberAccent : Colors.white70),
            _buildTableRow('Last Notif', lastNotifStr),
            _buildTableRow('Next Notif', nextNotifStr),
            _buildTableRow('Last GPS Update', timestampStr),
          ],
        ),
      ],
    );
  }

  Widget _buildEventLogTab(List<String> logs) {
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Belum ada event geofence tercatat.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: logs.map((log) {
        final isEnter = log.contains('ENTER');
        final isExit = log.contains('EXIT');
        final isNotif = log.contains('NOTIF');

        Color itemColor = Colors.white70;
        if (isEnter) itemColor = Colors.lightGreenAccent;
        if (isExit) itemColor = Colors.orangeAccent;
        if (isNotif) itemColor = Colors.amberAccent;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            log,
            style: TextStyle(
              color: itemColor,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        '--- $title ---',
        style: TextStyle(
          color: Colors.teal.shade200,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String value, {Color? color, bool isHighlighted = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text(
            '$label :',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text(
            value,
            style: TextStyle(
              color: color ?? (isHighlighted ? Colors.greenAccent : Colors.white),
              fontSize: 10,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
