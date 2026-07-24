import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/spot_model.dart';
import '../models/geofence_state.dart';
import 'notification_service.dart';

/// Service tunggal (Singleton) sebagai Geofence Engine terpusat.
/// Mengelola evaluasi geofence otomatis berpatokan penuh pada Position Stream (Event-Driven).
class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  Timer? _repeatTimer;
  Spot? _activeGeofenceSpot;

  // Radius Masuk = 15 meter
  // Radius Keluar = 20 meter (hysteresis)
  double _entryRadiusMeters = 15.0;
  double _exitRadiusMeters = 20.0;

  DateTime? _lastNotifTime;
  DateTime? _nextNotifTime;
  final List<String> _eventLogs = [];

  final StreamController<GeofenceState> _stateController =
      StreamController<GeofenceState>.broadcast();

  GeofenceState _lastState = GeofenceState();

  Stream<GeofenceState> get stateStream => _stateController.stream;
  GeofenceState get currentState => _lastState;

  void setRadiusThreshold(double entryMeters) {
    _entryRadiusMeters = entryMeters;
    _exitRadiusMeters = entryMeters + 5.0;
  }

  double get radiusThresholdMeters => _entryRadiusMeters;
  double get entryRadiusMeters => _entryRadiusMeters;
  double get exitRadiusMeters => _exitRadiusMeters;

  bool get isTimerRunning => _repeatTimer != null && _repeatTimer!.isActive;
  Spot? get activeGeofenceSpot => _activeGeofenceSpot;

  /// Menambahkan event log ber-timestamp ke buffer internal (maksimal 20 event terakhir)
  void _addEventLog(String message) {
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    final logItem = "[$timeStr] $message";
    _eventLogs.insert(0, logItem);
    if (_eventLogs.length > 20) {
      _eventLogs.removeLast();
    }
  }

  /// Memeriksa lokasi GPS secara otomatis setiap kali ada update Position Stream.
  /// Menghitung jarak ke seluruh marker tanpa perlu interaksi klik dari pengguna.
  void checkGeofence({
    required Position currentPosition,
    required List<Spot> spots,
  }) {
    Spot? nearestSpot;
    double nearestDistance = double.infinity;
    Spot? closestInsideSpot;
    double minInsideDistance = double.infinity;

    // Hitung jarak ke SELURUH marker secara otomatis
    for (final spot in spots) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        spot.latitude,
        spot.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestSpot = spot;
      }

      if (distance <= _entryRadiusMeters) {
        if (distance < minInsideDistance) {
          minInsideDistance = distance;
          closestInsideSpot = spot;
        }
      }
    }

    final String previousStateStr = _lastState.currentState;

    if (closestInsideSpot != null) {
      // Masuk radius <= 15m
      final bool isTimerActive = _repeatTimer != null && _repeatTimer!.isActive;
      final bool isDifferentSpot = _activeGeofenceSpot?.id != closestInsideSpot.id;

      if (!isTimerActive || isDifferentSpot) {
        _activeGeofenceSpot = closestInsideSpot;
        _addEventLog(
            "ENTER: Masuk radius '${closestInsideSpot.title}' (${minInsideDistance.toStringAsFixed(1)}m <= 15m)");
        _startSpamTimer(closestInsideSpot);
      }
    } else if (_activeGeofenceSpot != null) {
      // Periksa apakah _activeGeofenceSpot masih ada di daftar spots pengaliran (belum dihapus)
      final bool spotStillExists = spots.any((s) => s.id == _activeGeofenceSpot!.id);
      if (!spotStillExists) {
        _addEventLog("DELETED: Spot '${_activeGeofenceSpot!.title}' telah dihapus dari daftar.");
        _stopSpamTimer();
      } else {
        // Keluar radius hysteresis > 20m
        final currentDistance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          _activeGeofenceSpot!.latitude,
          _activeGeofenceSpot!.longitude,
        );

        if (currentDistance > _exitRadiusMeters) {
          _addEventLog(
              "EXIT: Keluar radius '${_activeGeofenceSpot!.title}' (${currentDistance.toStringAsFixed(1)}m > 20m)");
          _stopSpamTimer();
        }
      }
    }

    final bool isInsideGeofence = closestInsideSpot != null ||
        (_activeGeofenceSpot != null &&
            spots.any((s) => s.id == _activeGeofenceSpot!.id) &&
            nearestDistance <= _exitRadiusMeters);

    final String currentStateStr = isInsideGeofence ? "INSIDE" : "OUTSIDE";

    // Buat GeofenceState baru yang terpusat
    _lastState = GeofenceState(
      position: currentPosition,
      spots: spots,
      nearestSpot: nearestSpot,
      nearestDistance: nearestDistance,
      isInside: isInsideGeofence,
      currentState: currentStateStr,
      previousState: previousStateStr,
      isTimerRunning: isTimerRunning,
      timestamp: currentPosition.timestamp,
      lastNotifTime: _lastNotifTime,
      nextNotifTime: _nextNotifTime,
      eventLogs: List.from(_eventLogs),
    );

    // Broadcast ke listener (DebugPanel, UI, dll)
    _stateController.add(_lastState);

    if (kDebugMode) {
      _logConsoleState(_lastState);
    }
  }

  void _logConsoleState(GeofenceState state) {
    final pos = state.position;
    if (pos == null) return;

    final logBuffer = StringBuffer();
    logBuffer.writeln("==============================");
    logBuffer.writeln("Jumlah Marker : ${state.spots.length}");
    if (state.spots.isEmpty) {
      logBuffer.writeln("[CATATAN]: Marker 0. Firestore belum selesai load!");
    } else {
      for (int i = 0; i < state.spots.length; i++) {
        final s = state.spots[i];
        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          s.latitude,
          s.longitude,
        );
        logBuffer.writeln("  Marker #${i + 1}: '${s.title}' (${dist.toStringAsFixed(1)}m)");
      }
    }
    logBuffer.writeln("Latitude : ${pos.latitude}");
    logBuffer.writeln("Longitude : ${pos.longitude}");
    logBuffer.writeln("Accuracy : ${pos.accuracy.toStringAsFixed(1)} m (${state.accuracyCategory})");
    logBuffer.writeln("Speed : ${pos.speed.toStringAsFixed(1)} m/s");
    logBuffer.writeln("Heading : ${pos.heading.toStringAsFixed(0)}°");
    logBuffer.writeln("Altitude : ${pos.altitude.toStringAsFixed(1)} m");
    logBuffer.writeln("Distance : ${state.nearestDistance.isFinite ? state.nearestDistance.toStringAsFixed(1) : '-'} m");
    logBuffer.writeln("Radius Masuk : ${_entryRadiusMeters.toStringAsFixed(1)} m");
    logBuffer.writeln("Radius Keluar : ${_exitRadiusMeters.toStringAsFixed(1)} m");
    logBuffer.writeln("Inside Radius : ${state.currentState}");
    logBuffer.writeln("Current State : ${state.currentState}");
    logBuffer.writeln("Previous State : ${state.previousState}");
    logBuffer.writeln("Nearest Marker : ${state.nearestSpot?.title ?? 'Tidak Ada'}");
    logBuffer.writeln("Notification Timer : ${state.isTimerRunning ? 'RUNNING' : 'STOPPED'}");
    logBuffer.writeln("GPS Provider : ${state.gpsProvider}");
    logBuffer.writeln("Timestamp : ${DateFormat('yyyy-MM-dd HH:mm:ss').format(pos.timestamp)}");
    logBuffer.writeln("==============================");

    debugPrint(logBuffer.toString());
  }

  void _startSpamTimer(Spot spot) {
    _repeatTimer?.cancel();
    _activeGeofenceSpot = spot;

    _addEventLog("Timer Started (Spam 5 detik)");

    String formattedDate = 'Tidak diketahui';
    if (spot.createdAt != null) {
      final dateTime = spot.createdAt!.toDate();
      try {
        formattedDate = DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(dateTime);
      } catch (_) {
        formattedDate = DateFormat('d MMMM yyyy, HH:mm').format(dateTime);
      }
    }

    _triggerNotification(spot.title, formattedDate);

    _repeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_activeGeofenceSpot != null) {
        _triggerNotification(spot.title, formattedDate);
      } else {
        timer.cancel();
      }
    });
  }

  void _triggerNotification(String title, String date) {
    final now = DateTime.now();
    _lastNotifTime = now;
    _nextNotifTime = now.add(const Duration(seconds: 5));
    _addEventLog("NOTIF SENT: '$title'");
    NotificationService.showGeofenceReminder(
      placeName: title,
      formattedDate: date,
    );
  }

  void _stopSpamTimer() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _activeGeofenceSpot = null;
    _lastNotifTime = null;
    _nextNotifTime = null;
    _addEventLog("Timer Stopped & Notifications Cleared");
    NotificationService.cancelAllNotifications();
  }

  /// Dipanggil saat spot dihapus agar timer & notifikasi langsung mati seketika
  void onSpotDeleted(String spotId) {
    if (_activeGeofenceSpot?.id == spotId) {
      _addEventLog("DELETED: Spot '${_activeGeofenceSpot!.title}' dihapus pengguna.");
      _stopSpamTimer();
    }
  }

  void dispose() {
    _stopSpamTimer();
  }
}
