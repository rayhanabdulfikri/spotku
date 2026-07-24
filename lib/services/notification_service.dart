import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final List<String> _messageHistory = [];
  static int _reminderCount = 0;

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  /// Memunculkan 1 Notifikasi Tunggal yang Menumpuk Pesan di Dalamnya (Gaya WhatsApp Inbox)
  static Future<void> showGeofenceReminder({
    required String placeName,
    required String formattedDate,
  }) async {
    _reminderCount++;
    final timeNow = DateFormat('HH:mm:ss').format(DateTime.now());

    // Pesan riwayat tanpa counter #, mengganti dengan tanggal & jam terakhir kali menandai
    final newLine = '[$timeNow] Pernah ke $placeName (Ditandai: $formattedDate)';
    _messageHistory.insert(0, newLine);
    if (_messageHistory.length > 5) {
      _messageHistory.removeLast(); // Maksimal menyimpan 5 baris riwayat terakhir
    }

    // Tampilan InboxStyle khas WhatsApp (Menumpuk di 1 Notifikasi)
    final inboxStyle = InboxStyleInformation(
      _messageHistory,
      contentTitle: '📍 SpotKu — $placeName',
      summaryText: 'Ditandai: $formattedDate',
    );

    final androidDetails = AndroidNotificationDetails(
      'spotku_geofence_channel',
      'SpotKu Geofence Reminders',
      channelDescription: 'Notifikasi otomatis saat dekat titik kenangan',
      importance: Importance.max,
      priority: Priority.high,
      playSound: _reminderCount == 1, // Bunyi berdering hanya di pesan pertama
      enableVibration: true,
      styleInformation: inboxStyle, // 👈 Gaya Penumpukan WhatsApp
      onlyAlertOnce: true, // 👈 Agar menumpuk halus tanpa membunyikan alarm keras berkali-kali
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      101, // 👈 ID TETAP 101 agar menumpuk di 1 notifikasi tunggal (bukan membuat notifikasi baru)
      '📍 SpotKu — $placeName',
      'Anda pernah mengunjungi tempat ini, coba ingat-ingat kembali. (Ditandai: $formattedDate)',
      details,
    );
  }

  /// Membersihkan tumpukan notifikasi saat keluar radius
  static Future<void> cancelAllNotifications() async {
    _reminderCount = 0;
    _messageHistory.clear();
    await _plugin.cancel(101);
  }
}
