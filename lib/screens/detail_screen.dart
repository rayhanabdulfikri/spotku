import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/spot_model.dart';
import '../services/geofence_service.dart';

class DetailScreen extends StatefulWidget {
  final Spot spot;

  const DetailScreen({super.key, required this.spot});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _calibrating = false;

  Future<void> _openGoogleMaps(BuildContext context) async {
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${widget.spot.latitude},${widget.spot.longitude}');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
        );
      }
    }
  }

  /// Kalibrasi Ulang Lokasi Spot: Mengambil 10 sampel GPS presisi baru di tempat berdiri saat ini
  Future<void> _recalibrateLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalibrasi Ulang Lokasi Spot'),
        content: Text(
            'Apakah Anda ingin memperbarui koordinat "${widget.spot.title}" dengan posisi GPS Anda saat ini menggunakan 10 sampel presisi rata-rata?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Kalibrasi Sekarang'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _calibrating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS tidak aktif';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw 'Izin lokasi ditolak';
      }

      // Kumpulkan 10 sampel GPS
      final List<Position> samples = [];
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      final Completer<void> completer = Completer();
      StreamSubscription<Position>? sub;

      sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position pos) {
          samples.add(pos);
          if (samples.length >= 10) {
            sub?.cancel();
            completer.complete();
          }
        },
        onError: (e) {
          sub?.cancel();
          completer.completeError(e);
        },
      );

      await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        sub?.cancel();
      });

      if (samples.isEmpty) throw 'Gagal mendapatkan sampel GPS';

      // Hitung koordinat rata-rata
      double sumLat = 0.0;
      double sumLng = 0.0;
      double sumAcc = 0.0;

      for (final p in samples) {
        sumLat += p.latitude;
        sumLng += p.longitude;
        sumAcc += p.accuracy;
      }

      final avgLat = sumLat / samples.length;
      final avgLng = sumLng / samples.length;
      final avgAcc = sumAcc / samples.length;

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('spots')
          .doc(widget.spot.id)
          .update({
        'latitude': avgLat,
        'longitude': avgLng,
        'accuracy': avgAcc,
        'sample_count': samples.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Kalibrasi berhasil! Koordinat diperbarui (Estimasi Error: ±${avgAcc.toStringAsFixed(1)}m).'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali agar data di-refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal kalibrasi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _calibrating = false);
    }
  }

  Future<void> _deleteSpot(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Spot Kenangan'),
        content: Text(
            'Apakah Anda yakin ingin menghapus "${widget.spot.title}" dari peta? Data yang dihapus tidak dapat dikembalikan.'),
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
            .doc(widget.spot.id)
            .delete();

        // Notifikasi & Timer langsung dibatalkan seketika
        GeofenceService().onSpotDeleted(widget.spot.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Spot "${widget.spot.title}" berhasil dihapus')),
          );
          Navigator.pop(context); // Kembali ke HomeScreen
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

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    String formattedDate = 'Tidak diketahui';
    if (spot.createdAt != null) {
      try {
        formattedDate = DateFormat('d MMMM yyyy, HH:mm', 'id_ID')
            .format(spot.createdAt!.toDate());
      } catch (_) {
        formattedDate = DateFormat('d MMMM yyyy, HH:mm')
            .format(spot.createdAt!.toDate());
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(spot.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            tooltip: 'Kalibrasi Ulang Lokasi Spot',
            onPressed: _calibrating ? null : _recalibrateLocation,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Hapus Spot',
            onPressed: () => _deleteSpot(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media Preview (Foto / Icon Video)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: spot.mediaType == 'image'
                  ? Image.file(
                      File(spot.mediaUrl),
                      height: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 240,
                        color: Colors.grey.shade300,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Gambar tidak ditemukan di memori HP',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      height: 240,
                      color: Colors.black12,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            size: 72, color: Colors.teal),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Judul Spot
            Text(
              spot.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Deskripsi Kenangan
            Text(
              spot.description.isNotEmpty
                  ? spot.description
                  : 'Tidak ada deskripsi tambahan.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),

            // KARTU 1: Status Jarak Realtime (Live Distance Card)
            FutureBuilder<Position>(
              future: Geolocator.getCurrentPosition(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Menghitung jarak GPS...'),
                        ],
                      ),
                    ),
                  );
                }

                final currentPos = snapshot.data!;
                final distanceMeters = Geolocator.distanceBetween(
                  currentPos.latitude,
                  currentPos.longitude,
                  spot.latitude,
                  spot.longitude,
                );

                final bool isInside15m = distanceMeters <= 15.0;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isInside15m ? Colors.green : Colors.teal.shade200,
                      width: 1.5,
                    ),
                  ),
                  color: isInside15m ? Colors.green.shade50 : Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isInside15m
                                  ? Icons.check_circle
                                  : Icons.near_me_outlined,
                              color: isInside15m ? Colors.green : Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isInside15m
                                    ? '🎯 Anda Sedang Berada di Dalam Radius Geofence!'
                                    : '📍 Status Jarak Lokasi Saat Ini',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isInside15m ? Colors.green.shade900 : Colors.teal.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          distanceMeters >= 1000
                              ? 'Jarak: ${(distanceMeters / 1000).toStringAsFixed(2)} km dari posisi Anda'
                              : 'Jarak: ${distanceMeters.toStringAsFixed(1)} meter dari posisi Anda',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isInside15m
                              ? 'Notifikasi pengingat otomatis aktif (Radius <= 15m).'
                              : 'Dekati lokasi ini hingga radius <= 15 meter untuk memicu pengingat otomatis.',
                          style: TextStyle(
                              fontSize: 12,
                              color: isInside15m
                                  ? Colors.green.shade800
                                  : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // KARTU 2: Rincian Informasi Waktu, Koordinat, & Kualitas Akurasi Marker
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        const Text('Ditandai Pada:',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const Spacer(),
                        Text(formattedDate,
                            style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        const Text('Koordinat GPS:',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const Spacer(),
                        Text(
                          '${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.high_quality,
                            size: 18, color: Colors.teal),
                        const SizedBox(width: 10),
                        const Text('Akurasi Saat Disimpan:',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const Spacer(),
                        Text(
                          spot.accuracy > 0
                              ? '±${spot.accuracy.toStringAsFixed(1)}m (${spot.sampleCount} Sampel)'
                              : 'Single Fix Standard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: spot.accuracy > 0 && spot.accuracy <= 5
                                ? Colors.green.shade800
                                : Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // TOMBOL AKSI 1: Kalibrasi Ulang Lokasi
            OutlinedButton.icon(
              onPressed: _calibrating ? null : _recalibrateLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _calibrating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                _calibrating
                    ? 'Mengambil 10 Sampel GPS...'
                    : 'Kalibrasi Ulang Lokasi (10 Sampel Presisi)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            // TOMBOL AKSI 2: Petunjuk Arah Google Maps
            ElevatedButton.icon(
              onPressed: () => _openGoogleMaps(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.directions),
              label: const Text(
                'Petunjuk Arah (Buka di Google Maps)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            // TOMBOL AKSI 3: Hapus Spot Kenangan Ini
            TextButton.icon(
              onPressed: () => _deleteSpot(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.delete_forever, size: 20),
              label: const Text(
                'Hapus Spot Kenangan Ini',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
