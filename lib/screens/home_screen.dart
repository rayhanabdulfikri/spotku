import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/spot_model.dart';
import '../services/geofence_service.dart';
import '../widgets/gps_debug_panel.dart';
import 'add_spot_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  Spot? _selectedSpot;
  bool _isMapInitialized = false;

  StreamSubscription<Position>? _positionSubscription;
  Position? _latestPosition;
  List<Spot> _cachedSpots = [];

  @override
  void initState() {
    super.initState();
    _startPositionListening();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    GeofenceService().dispose();
    super.dispose();
  }

  void _startPositionListening() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Menggunakan Foreground Notification Service agar GPS Tetap Memantau Meskipun Aplikasi Ditutup
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "SpotKu Pemantau Lokasi",
          notificationText: "Memantau lokasi kenangan di latar belakang...",
          notificationIcon: AndroidResource(name: 'ic_launcher'),
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          _latestPosition = position;
        });
      }
      if (_cachedSpots.isNotEmpty) {
        GeofenceService().checkGeofence(
          currentPosition: position,
          spots: _cachedSpots,
        );
      }
    });
  }

  Future<void> _logout() async {
    GeofenceService().dispose();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteSpotFromFirebase(BuildContext context, Spot spot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Spot Kenangan'),
        content: Text(
            'Apakah Anda yakin ingin menghapus "${spot.title}" dari peta? Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('spots')
            .doc(spot.id)
            .delete();

        // Notifikasi & Timer langsung dibatalkan seketika
        GeofenceService().onSpotDeleted(spot.id);

        if (context.mounted) {
          if (_selectedSpot?.id == spot.id) {
            setState(() {
              _selectedSpot = null;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Spot "${spot.title}" berhasil dihapus')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
      }
    }
  }

  void _showManageSpotsBottomSheet(BuildContext context, List<Spot> spots) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (spots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('Belum ada spot yang ditandai.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return Container(
          height: 380,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(
                      'Daftar & Kelola Spot Kenangan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: spots.length,
                  itemBuilder: (context, index) {
                    final item = spots[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.mediaType == 'image'
                            ? Image.file(
                                File(item.mediaUrl),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image, size: 24),
                                ),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                color: Colors.black12,
                                child: const Icon(Icons.videocam, size: 24),
                              ),
                      ),
                      title: Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Koordinat: ${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Hapus Spot Ini',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteSpotFromFirebase(context, item);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(spot: item),
                          ),
                        );
                      },
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

  Future<LatLng> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return const LatLng(-6.8871, 109.7745);
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return const LatLng(-6.8871, 109.7745);
    }

    Position position = await Geolocator.getCurrentPosition();
    _latestPosition = position;
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<LatLng>(
      future: _getCurrentLocation(),
      builder: (context, locationSnapshot) {
        if (!locationSnapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final currentLocation = locationSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SpotKu'),
            actions: [
              IconButton(
                icon: const Icon(Icons.my_location),
                tooltip: 'Refresh Lokasi Terkini',
                onPressed: () async {
                  try {
                    final pos = await Geolocator.getCurrentPosition();
                    if (context.mounted) {
                      setState(() {
                        _latestPosition = pos;
                      });
                      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lokasi GPS berhasil diperbarui'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    if (_cachedSpots.isNotEmpty) {
                      GeofenceService().checkGeofence(
                        currentPosition: pos,
                        spots: _cachedSpots,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal refresh lokasi: $e')),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'Daftar & Hapus Spot',
                onPressed: () => _showManageSpotsBottomSheet(context, _cachedSpots),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Keluar',
                onPressed: _logout,
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('spots')
                .where('user_id', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Terjadi error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final spots = snapshot.data!.docs
                  .map((d) => Spot.fromFirestore(d))
                  .toList();

              _cachedSpots = spots;

              if (_latestPosition != null && spots.isNotEmpty) {
                GeofenceService().checkGeofence(
                  currentPosition: _latestPosition!,
                  spots: spots,
                );
              }

              // Penanda Titik Spot Kenangan (Dot Marker Circle dengan Touch Area 44x44 Responsif)
              final spotsMarkers = spots.map((spot) {
                final isSelected = _selectedSpot?.id == spot.id;
                return Marker(
                  point: LatLng(spot.latitude, spot.longitude),
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _selectedSpot = spot;
                      });
                    },
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isSelected)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.teal.withValues(alpha: 0.35),
                                border: Border.all(color: Colors.teal, width: 2),
                              ),
                            ),
                          Container(
                            width: isSelected ? 24 : 20,
                            height: isSelected ? 24 : 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.teal : Colors.redAccent,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(
                              Icons.place,
                              size: isSelected ? 13 : 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList();

              // Penanda Titik Lokasi Anda Saat Ini (Google Maps Style Blue Dot)
              final userLatLng = _latestPosition != null
                  ? LatLng(_latestPosition!.latitude, _latestPosition!.longitude)
                  : currentLocation;

              final userLocationMarker = Marker(
                point: userLatLng,
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo Biru Transparan (Google Maps Pulse Ring)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.22),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.4), width: 1),
                      ),
                    ),
                    // Titik Biru Utama dengan Border Putih Presisi
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              // Hitung Spot Terdekat untuk Garis Dinamis & Distance Tooltip
              Spot? nearestSpot;
              double minDistance = double.infinity;
              for (final spot in spots) {
                final dist = Geolocator.distanceBetween(
                  userLatLng.latitude,
                  userLatLng.longitude,
                  spot.latitude,
                  spot.longitude,
                );
                if (dist < minDistance) {
                  minDistance = dist;
                  nearestSpot = spot;
                }
              }

              // Buat Garis Polyline Dinamis & Tooltip Jarak ke Marker Terdekat
              Polyline? dynamicPolyline;
              Marker? distanceLabelMarker;

              if (nearestSpot != null && minDistance.isFinite) {
                final spotLatLng = LatLng(nearestSpot.latitude, nearestSpot.longitude);
                final isInside = minDistance <= GeofenceService().entryRadiusMeters;

                dynamicPolyline = Polyline(
                  points: [userLatLng, spotLatLng],
                  strokeWidth: 3.0,
                  color: isInside ? Colors.green.shade600 : Colors.teal.shade600,
                  borderStrokeWidth: 1.5,
                  borderColor: Colors.white,
                );

                // Hitung koordinat tengah (Midpoint) untuk memasang badge jarak
                final midLat = (userLatLng.latitude + spotLatLng.latitude) / 2;
                final midLng = (userLatLng.longitude + spotLatLng.longitude) / 2;
                final distText = minDistance >= 1000
                    ? "${(minDistance / 1000).toStringAsFixed(2)} km"
                    : "${minDistance.toStringAsFixed(1)} m";

                distanceLabelMarker = Marker(
                  point: LatLng(midLat, midLng),
                  width: 96,
                  height: 28,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInside ? Colors.greenAccent : Colors.tealAccent,
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isInside ? Icons.check_circle : Icons.straighten,
                          size: 11,
                          color: isInside ? Colors.greenAccent : Colors.tealAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distText,
                          style: TextStyle(
                            color: isInside ? Colors.greenAccent : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_isMapInitialized) {
                  if (spots.isEmpty) {
                    _mapController.move(currentLocation, 15);
                  } else if (spots.length == 1) {
                    _mapController.move(
                      LatLng(spots.first.latitude, spots.first.longitude),
                      15,
                    );
                  } else {
                    final bounds = LatLngBounds.fromPoints(
                      spots
                          .map((e) => LatLng(e.latitude, e.longitude))
                          .toList(),
                    );

                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(60),
                      ),
                    );
                  }
                  _isMapInitialized = true;
                }
              });

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: currentLocation,
                      initialZoom: 15,
                      onTap: (tapPosition, point) {
                        if (_selectedSpot != null) {
                          setState(() {
                            _selectedSpot = null;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.spotku',
                      ),
                      if (dynamicPolyline != null)
                        PolylineLayer(polylines: [dynamicPolyline]),
                      if (distanceLabelMarker != null)
                        MarkerLayer(markers: [distanceLabelMarker]),
                      MarkerLayer(markers: [userLocationMarker]),
                      MarkerLayer(markers: spotsMarkers),
                      if (_selectedSpot != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_selectedSpot!.latitude,
                                  _selectedSpot!.longitude),
                              width: 140,
                              height: 140,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetailScreen(spot: _selectedSpot!),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 24),
                                        width: 120,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 6,
                                              offset: Offset(0, 3),
                                            )
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: _selectedSpot!.mediaType == 'image'
                                              ? Image.file(
                                                  File(_selectedSpot!.mediaUrl),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Center(
                                                    child: Icon(Icons.broken_image,
                                                        color: Colors.grey),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.videocam,
                                                      size: 40, color: Colors.grey),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () => _deleteSpotFromFirebase(
                                              context, _selectedSpot!),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_location_btn',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      tooltip: 'Lokasi Saya',
                      onPressed: () {
                        _mapController.move(userLatLng, 16);
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                  if (kDebugMode)
                    GpsDebugPanel(spots: spots),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSpotScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
