import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _mediaFile;
  String _mediaType = 'image';
  
  // Data Lokasi Berbasis Sampel Multi-Point Averaging
  final List<Position> _locationSamples = [];
  double _avgLat = 0.0;
  double _avgLng = 0.0;
  double _avgAccuracy = 0.0;
  bool _saving = false;
  bool _gettingLocation = true;
  String _locationStatusText = "Menyiapkan GPS...";
  StreamSubscription<Position>? _sampleSubscription;

  @override
  void initState() {
    super.initState();
    _startLocationSampling();
  }

  @override
  void dispose() {
    _sampleSubscription?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Mengumpulkan 10 sampel GPS real-time & menghitung posisi rata-rata terbaik (Averaging)
  void _startLocationSampling() async {
    setState(() {
      _gettingLocation = true;
      _locationStatusText = "Memeriksa layanan GPS...";
      _locationSamples.clear();
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Layanan lokasi (GPS) tidak aktif';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw 'Izin lokasi ditolak';
      }

      setState(() {
        _locationStatusText = "Mengumpulkan 10 sampel GPS untuk akurasi presisi...";
      });

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      _sampleSubscription = Geolocator.getPositionStream(locationSettings: settings)
          .listen((Position position) {
        if (!mounted) return;

        setState(() {
          _locationSamples.add(position);
          _calculateAverageLocation();

          if (_locationSamples.length < 10) {
            _locationStatusText =
                "Mengumpulkan sampel ${_locationSamples.length}/10 (Akurasi: ${position.accuracy.toStringAsFixed(1)}m)...";
          } else {
            _locationStatusText = "Kalibrasi GPS Selesai (10 Sampel Stabil)";
            _gettingLocation = false;
            _sampleSubscription?.cancel();
          }
        });
      }, onError: (e) {
        if (mounted) {
          setState(() {
            _locationStatusText = "Gagal mengambil sampel GPS: $e";
            _gettingLocation = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationStatusText = "Error GPS: $e";
          _gettingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ambil lokasi: $e')),
        );
      }
    }
  }

  /// Menghitung koordinat rata-rata (Average Lat, Lng, & Accuracy)
  void _calculateAverageLocation() {
    if (_locationSamples.isEmpty) return;

    double sumLat = 0.0;
    double sumLng = 0.0;
    double sumAcc = 0.0;

    for (final pos in _locationSamples) {
      sumLat += pos.latitude;
      sumLng += pos.longitude;
      sumAcc += pos.accuracy;
    }

    _avgLat = sumLat / _locationSamples.length;
    _avgLng = sumLng / _locationSamples.length;
    _avgAccuracy = sumAcc / _locationSamples.length;
  }

  String _getAccuracyQualityLabel(double acc) {
    if (acc <= 3) return "Excellent (Sangat Presisi)";
    if (acc <= 5) return "Very Good (Presisi)";
    if (acc <= 10) return "Good (Cukup Bagus)";
    if (acc <= 20) return "Fair (Sedang)";
    return "Poor (Kurang Akurat)";
  }

  Future<void> _pickPhoto() async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) {
      setState(() {
        _mediaFile = file;
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    if (file != null) {
      setState(() {
        _mediaFile = file;
        _mediaType = 'video';
      });
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Judul wajib diisi')));
      return;
    }
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ambil foto atau video dulu')));
      return;
    }
    if (_locationSamples.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lokasi GPS belum siap')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('spots').add({
        'user_id': uid,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'latitude': _avgLat,
        'longitude': _avgLng,
        'accuracy': _avgAccuracy,
        'sample_count': _locationSamples.length,
        'media_type': _mediaType,
        'media_url': _mediaFile!.path,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Spot Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Kalibrasi Ulang GPS',
            onPressed: _startLocationSampling,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media Preview Card
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _mediaFile == null
                  ? const Center(
                      child: Icon(Icons.image, size: 64, color: Colors.grey))
                  : _mediaType == 'image'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_mediaFile!.path),
                              fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam,
                                  size: 64, color: Colors.grey),
                              Text('Video siap disimpan'),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Video (maks 15s)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nama Spot Wisata / Kenangan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan / Deskripsi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Card Indikator Akurasi GPS & Sampel Averaging
            Card(
              elevation: 2,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _gettingLocation ? Icons.sync : Icons.verified,
                          color: Colors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Kualitas Koordinat GPS (Multi-Sampling)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.teal,
                          ),
                        ),
                        const Spacer(),
                        if (_gettingLocation)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      _locationStatusText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (_locationSamples.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Koordinat Rata-rata: ${_avgLat.toStringAsFixed(6)}, ${_avgLng.toStringAsFixed(6)}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                      Text(
                        'Estimasi Error: ±${_avgAccuracy.toStringAsFixed(1)} m (${_getAccuracyQualityLabel(_avgAccuracy)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _avgAccuracy <= 5 ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'Jumlah Sampel GPS: ${_locationSamples.length} titik lokasi',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Simpan SpotKu Presisi High-Quality',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
