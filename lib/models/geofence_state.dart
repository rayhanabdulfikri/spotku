import 'package:geolocator/geolocator.dart';
import 'spot_model.dart';

/// Model snapshot terpusat untuk merepresentasikan kondisi real-time Geofence, GPS, & Event Log.
class GeofenceState {
  final Position? position;
  final List<Spot> spots;
  final Spot? nearestSpot;
  final double nearestDistance;
  final bool isInside;
  final String currentState;
  final String previousState;
  final bool isTimerRunning;
  final DateTime? timestamp;
  final DateTime? lastNotifTime;
  final DateTime? nextNotifTime;
  final List<String> eventLogs;

  GeofenceState({
    this.position,
    this.spots = const [],
    this.nearestSpot,
    this.nearestDistance = double.infinity,
    this.isInside = false,
    this.currentState = "OUTSIDE",
    this.previousState = "OUTSIDE",
    this.isTimerRunning = false,
    this.timestamp,
    this.lastNotifTime,
    this.nextNotifTime,
    this.eventLogs = const [],
  });

  /// Mengkategorikan akurasi lokasi berdasarkan Position.accuracy (meter)
  String get accuracyCategory {
    if (position == null) return "-";
    final acc = position!.accuracy;
    if (acc <= 3.0) return "Excellent";
    if (acc <= 5.0) return "Very Good";
    if (acc <= 10.0) return "Good";
    if (acc <= 20.0) return "Fair";
    if (acc <= 50.0) return "Poor";
    return "Very Poor";
  }

  /// Menentukan status penyedia GPS (Real / Mock)
  String get gpsProvider {
    if (position == null) return "-";
    return position!.isMocked ? "Mock GPS" : "Real GPS (Hardware)";
  }
}
