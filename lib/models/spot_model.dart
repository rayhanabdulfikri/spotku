import 'package:cloud_firestore/cloud_firestore.dart';

class Spot {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String mediaType; // "image" atau "video"
  final String mediaUrl; // jalur file lokal di HP
  final Timestamp? createdAt;
  final double accuracy; // Akurasi GPS saat marker dibuat/dikalibrasi (meter)
  final int sampleCount; // Jumlah sampel GPS yang dirata-ratakan

  Spot({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.mediaType,
    required this.mediaUrl,
    this.createdAt,
    this.accuracy = 0.0,
    this.sampleCount = 1,
  });

  factory Spot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Spot(
      id: doc.id,
      userId: data['user_id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      mediaType: data['media_type'] ?? 'image',
      mediaUrl: data['media_url'] ?? '',
      createdAt: data['created_at'],
      accuracy: (data['accuracy'] ?? 0.0).toDouble(),
      sampleCount: (data['sample_count'] ?? 1).toInt(),
    );
  }
}
