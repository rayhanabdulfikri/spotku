import sys
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#0f766e"))
        
        # Header (Top)
        self.drawString(45, 805, "PANDUAN PRESENTASI DOSEN: SISTEM LOKASI, GEOFENCING & NOTIFIKASI SPOTKU")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        self.drawRightString(550, 805, "Dokumentasi Akademik Flutter")
        
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.75)
        self.line(45, 797, 550, 797)
        
        # Footer (Bottom)
        self.line(45, 45, 550, 45)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        self.drawString(45, 32, "SpotKu - Mini Travel & Memory Diary (Single Source of Truth Architecture)")
        page_text = f"Halaman {self._pageNumber} dari {page_count}"
        self.drawRightString(550, 32, page_text)
        self.restoreState()

def build_pdf(filename="PANDUAN_PRESENTASI_DOSEN_SPOTKU.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=45,
        rightMargin=45,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=colors.HexColor('#0f766e'),
        spaceAfter=4
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#475569'),
        spaceAfter=12
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor('#0f766e'),
        spaceBefore=12,
        spaceAfter=6
    )

    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#1e293b'),
        spaceBefore=8,
        spaceAfter=4
    )

    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=colors.HexColor('#1e293b'),
        spaceAfter=6
    )

    bullet_style = ParagraphStyle(
        'BulletText',
        parent=body_style,
        leftIndent=12,
        spaceAfter=3
    )

    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7.5,
        leading=10.5,
        textColor=colors.HexColor('#f8fafc'),
        spaceAfter=0
    )

    code_explain_style = ParagraphStyle(
        'CodeExplain',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.HexColor('#0f172a'),
        spaceAfter=0
    )

    highlight_style = ParagraphStyle(
        'HighlightText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor('#166534'),
        spaceAfter=0
    )

    story = []

    # Title & Header
    story.append(Paragraph("PANDUAN PRESENTASI DOSEN & BEDAH KODE TEKNIS", title_style))
    story.append(Paragraph("Sistem Lokasi GPS, Geofencing Event-Driven, & Notifikasi Stacking pada Aplikasi SpotKu", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#0f766e"), spaceAfter=10))

    # Ringkasan Eksekutif
    story.append(Paragraph("1. Ringkasan Evaluasi & Evolusi Sistem (Sebelum vs Sesudah)", h1_style))
    story.append(Paragraph(
        "Aplikasi <b>SpotKu</b> telah mengalami transformasi arsitektur dari yang awalnya menggunakan notifikasi pemicu manual / tombol sederhana "
        "menjadi <b>Geofencing Engine Terpusat (Event-Driven)</b> berbasis <i>Single Source of Truth</i> yang bekerja secara latar belakang tanpa perlu interaksi pengguna.",
        body_style
    ))

    # Tabel Perbandingan Sebelum & Sesudah
    table_data = [
        [
            Paragraph("<b>Komponen / Fitur</b>", body_style),
            Paragraph("<b>Kondisi Awal (Sebelum Refactoring)</b>", body_style),
            Paragraph("<b>Kondisi Hasil Akhir (Sesudah Refactoring)</b>", body_style)
        ],
        [
            Paragraph("<b>Metode Pemicu Notifikasi</b>", body_style),
            Paragraph("Tombol manual / pemicu sederhana.", body_style),
            Paragraph("<b>Otomatis & Latar Belakang</b>: Dipicu oleh <i>Position Stream</i> saat lokasi fisik bergerak mendekati marker (&le;15m).", body_style)
        ],
        [
            Paragraph("<b>Arsitektur Stream GPS</b>", body_style),
            Paragraph("<i>Dual Stream</i>: HomeScreen & Debug Panel masing-masing membuka listener Geolocator sendiri.", body_style),
            Paragraph("<b>Single Source of Truth</b>: Hanya 1 stream terpusat di <code>GeofenceService</code> yang membroadcast <code>GeofenceState</code> ke seluruh komponen.", body_style)
        ],
        [
            Paragraph("<b>Kualitas Koordinat Marker</b>", body_style),
            Paragraph("<i>Single Fix</i>: Simpan 1 koordinat mentah dari GPS saat tombol ditekan (sering meleset 14m-16m).", body_style),
            Paragraph("<b>Multi-Sample Averaging</b>: Merata-ratakan 10 sampel GPS real-time (&plusmn;3m akurasi) + metadata <code>accuracy</code> &amp; <code>sample_count</code> di Firestore.", body_style)
        ],
        [
            Paragraph("<b>Penanganan Marker Dihapus</b>", body_style),
            Paragraph("Notifikasi &amp; timer tetap berjalan berulang (spam) meskipun marker sudah dihapus dari Firestore.", body_style),
            Paragraph("<b>Pembersihan Seketika</b>: <code>onSpotDeleted()</code> membatalkan timer 5 detik dan menghapus notifikasi dari status bar HP dalam 0 detik.", body_style)
        ],
        [
            Paragraph("<b>Tampilan Visual Peta</b>", body_style),
            Paragraph("Pin merah statis standar.", body_style),
            Paragraph("<b>Google Maps Style</b>: Titik biru berpendar (<i>User Blue Dot</i>), <i>Dot Spot Markers</i>, <b>Garis Dinamis (Polyline)</b>, &amp; <b>Tooltip Jarak</b> di titik tengah.", body_style)
        ],
        [
            Paragraph("<b>Diagnosis Debugging</b>", body_style),
            Paragraph("Log terminal seadanya.", body_style),
            Paragraph("<b>Status Monitor UI &amp; Live Event Logger</b>: Merekam kronologi event (<code>ENTER</code>, <code>EXIT</code>, <code>TIMER</code>, <code>NOTIF</code>) ber-timestamp <code>[HH:mm:ss]</code>.", body_style)
        ]
    ]

    comp_table = Table(table_data, colWidths=[110, 190, 205])
    comp_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#e6fffa')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(comp_table)
    story.append(Spacer(1, 10))

    # Section 2: Arsitektur Lokasi & Geofencing
    story.append(Paragraph("2. Konsep Arsitektur Terpusat (Single Source of Truth)", h1_style))
    story.append(Paragraph(
        "Untuk mencegah ketidaksesuaian data antara tampilan UI, Notifikasi, dan Panel Debug, seluruh data lokasi diproses "
        "oleh satu engine tunggal (<b>GeofenceService</b>) yang membroadcast objek snapshot <b>GeofenceState</b>.",
        body_style
    ))
    
    arch_box = (
        "<b>Diagram Alur Data Terpusat:</b><br/>"
        "Cloud Firestore ('spots') ──&gt; GeofenceService.checkGeofence() &lt;── Geolocator Position Stream<br/>"
        "                                      │<br/>"
        "                           [ Memproses Logic &amp; Hysteresis ]<br/>"
        "                                      │<br/>"
        "                                      ▼<br/>"
        "                              GeofenceState Snapshot<br/>"
        "                                      │<br/>"
        "          ┌───────────────────────────┼───────────────────────────┐<br/>"
        "          ▼                           ▼                           ▼<br/>"
        "  NotificationService           GpsDebugPanel             Live Console Log<br/>"
        " (Trigger Inbox Stacking)     (Status Monitor UI)         (debugPrint Format)"
    )
    arch_table = Table([[Paragraph(arch_box, code_explain_style)]], colWidths=[505])
    arch_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f1f5f9')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#94a3b8')),
        ('PADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(arch_table)
    story.append(Spacer(1, 10))

    # Section 3: Bedah Kode Rinci Per Bagian
    story.append(Paragraph("3. Bedah Kode Rinci (Line-by-Line &amp; Block-by-Block Explanation)", h1_style))

    # 3.1 main.dart
    story.append(Paragraph("A. Inisialisasi Aplikasi (lib/main.dart)", h2_style))
    code_main = (
        "1: WidgetsFlutterBinding.ensureInitialized();\n"
        "2: await initializeDateFormatting('id_ID', null);\n"
        "3: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);\n"
        "4: await NotificationService.init();"
    )
    explain_main = (
        "<b>Penjelasan Baris per Baris:</b><br/>"
        "&bull; <b>Baris 1</b>: Memastikan <i>native engine bindings</i> Flutter telah siap sebelum menjalankan proses async.<br/>"
        "&bull; <b>Baris 2</b>: Menginisialisasi data simbol tanggal Bahasa Indonesia (<code>id_ID</code>) agar paket <code>intl</code> tidak melempar <code>LocaleDataException</code>.<br/>"
        "&bull; <b>Baris 3</b>: Menghubungkan aplikasi ke Firebase backend.<br/>"
        "&bull; <b>Baris 4</b>: Mendaftarkan channel notifikasi lokal Android."
    )
    story.append(Table([[Paragraph(code_main, code_style), Paragraph(explain_main, code_explain_style)]], colWidths=[200, 305],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 6)]))
    story.append(Spacer(1, 8))

    # 3.2 geofence_service.dart
    story.append(Paragraph("B. Engine Geofencing & Event Logger (lib/services/geofence_service.dart)", h2_style))
    code_geo = (
        "1: final StreamController<GeofenceState> _stateController = StreamController.broadcast();\n"
        "2: for (final spot in spots) {\n"
        "3:   final distance = Geolocator.distanceBetween(pos.lat, pos.lng, spot.lat, spot.lng);\n"
        "4:   if (distance <= 15.0) closestInsideSpot = spot;\n"
        "5: }\n"
        "6: if (!spots.any((s) => s.id == _activeSpot?.id)) _stopSpamTimer();\n"
        "7: _stateController.add(_lastState);"
    )
    explain_geo = (
        "<b>Penjelasan Blok Kode:</b><br/>"
        "&bull; <b>Baris 1</b>: <code>StreamController.broadcast</code> membuat pipa data terpusat agar State dapat didengarkan banyak listener.<br/>"
        "&bull; <b>Baris 2-5</b>: Evaluasi jarak <b>otomatis</b> dari GPS ke seluruh marker. Jika jarak &le; 15m (Entry Radius), masuk status <code>INSIDE</code>.<br/>"
        "&bull; <b>Baris 6</b>: <b>Perbaikan Bug Hapus Marker</b>: Jika spot aktif sudah tidak ada di Firestore, timer notifikasi 5s seketika dihentikan.<br/>"
        "&bull; <b>Baris 7</b>: Mengirimkan snapshot state terbaru ke UI &amp; Debug Panel."
    )
    story.append(Table([[Paragraph(code_geo, code_style), Paragraph(explain_geo, code_explain_style)]], colWidths=[200, 305],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 6)]))
    story.append(Spacer(1, 8))

    # 3.3 notification_service.dart
    story.append(Paragraph("C. Layanan Notifikasi Stacking (lib/services/notification_service.dart)", h2_style))
    code_notif = (
        "1: final inboxStyle = InboxStyleInformation(_messageHistory);\n"
        "2: final androidDetails = AndroidNotificationDetails(\n"
        "3:   'spotku_geofence_channel', 'SpotKu Reminders',\n"
        "4:   importance: Importance.max, priority: Priority.high,\n"
        "5:   styleInformation: inboxStyle, onlyAlertOnce: true);\n"
        "6: await _plugin.show(101, title, body, details);"
    )
    explain_notif = (
        "<b>Penjelasan Blok Kode:</b><br/>"
        "&bull; <b>Baris 1</b>: <code>InboxStyleInformation</code> menumpuk hingga 5 baris riwayat pesan di dalam 1 notifikasi (gaya WhatsApp).<br/>"
        "&bull; <b>Baris 2-5</b>: Mengatur prioritas tinggi dan <code>onlyAlertOnce: true</code> agar HP tidak berdering keras terus-menerus setiap 5 detik.<br/>"
        "&bull; <b>Baris 6</b>: Menggunakan **Notification ID tetap (101)** agar notifikasi baru memperbarui notifikasi lama di status bar."
    )
    story.append(Table([[Paragraph(code_notif, code_style), Paragraph(explain_notif, code_explain_style)]], colWidths=[200, 305],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 6)]))
    story.append(Spacer(1, 8))

    # 3.4 add_spot_screen.dart & detail_screen.dart
    story.append(Paragraph("D. Multi-Sample GPS Averaging &amp; Kalibrasi (lib/screens/add_spot_screen.dart)", h2_style))
    code_add = (
        "1: _sub = Geolocator.getPositionStream().listen((pos) {\n"
        "2:   _locationSamples.add(pos);\n"
        "3:   if (_locationSamples.length >= 10) _sub.cancel();\n"
        "4: });\n"
        "5: double avgLat = sumLat / 10; double avgLng = sumLng / 10;\n"
        "6: await firestore.add({'latitude': avgLat, 'accuracy': avgAcc});"
    )
    explain_add = (
        "<b>Penjelasan Kualitas Lokasi:</b><br/>"
        "&bull; <b>Baris 1-4</b>: Mengumpulkan 10 sampel titik posisi GPS real-time.<br/>"
        "&bull; <b>Baris 5</b>: Merata-ratakan koordinat ($\text{lat}_{\text{avg}}, \text{lng}_{\text{avg}}$) untuk mengeliminasi error GPS mentah.<br/>"
        "&bull; <b>Baris 6</b>: Menyimpan metadata <code>accuracy</code> &amp; <code>sample_count</code> ke Firestore untuk transparansi kualitas koordinat."
    )
    story.append(Table([[Paragraph(code_add, code_style), Paragraph(explain_add, code_explain_style)]], colWidths=[200, 305],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 6)]))
    story.append(Spacer(1, 8))

    # 3.5 gps_debug_panel.dart & home_screen.dart
    story.append(Paragraph("E. Visual Peta Google Maps Style &amp; Debug Panel (lib/screens/home_screen.dart &amp; widgets/gps_debug_panel.dart)", h2_style))
    code_ui = (
        "1: MarkerLayer(markers: [userLocationMarker]); // Blue Dot\n"
        "2: Polyline(points: [userLatLng, spotLatLng], strokeWidth: 3.0);\n"
        "3: Marker(point: midLatLng, child: Text('$distText')); // Midpoint Tooltip\n"
        "4: GestureDetector(onTap: () => setState(() => _isMinimized = !_isMinimized));"
    )
    explain_ui = (
        "<b>Penjelasan Visual Peta &amp; Debug:</b><br/>"
        "&bull; <b>Baris 1</b>: Merender <i>User Blue Dot</i> berpendar yang berpindah real-time.<br/>"
        "&bull; <b>Baris 2-3</b>: Menghubungkan garis elastis menuju spot terdekat dan memasang badge jarak di titik tengah (midpoint).<br/>"
        "&bull; <b>Baris 4</b>: Panel debug dapat diminimize dengan mengetuk seluruh area header tanpa error overflow."
    )
    story.append(Table([[Paragraph(code_ui, code_style), Paragraph(explain_ui, code_explain_style)]], colWidths=[200, 305],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 6)]))
    story.append(Spacer(1, 10))

    # Section 4: Naskah Presentasi Dosen
    story.append(Paragraph("4. Naskah Presentasi Siap Pakai untuk Menjawab Dosen Penguji", h1_style))

    story.append(Paragraph("<b>Pertanyaan 1: Bagaimana sistem geofencing aplikasi Anda bekerja di latar belakang?</b>", h2_style))
    ans1 = (
        "<i>\"Sistem geofencing pada SpotKu bersifat fully event-driven. Layanan Singleton <code>GeofenceService</code> berlangganan <code>Geolocator.getPositionStream()</code>. "
        "Setiap kali lokasi bergerak, engine secara otomatis menghitung jarak Euclidean/Haversine ke seluruh marker di Firestore. Jika jarak &le; 15 meter, "
        "sistem mengaktifkan <code>NotificationService</code> dengan gaya penumpukan InboxStyle (ID 101). Untuk mencegah flicker saat di batas radius, "
        "kami mengimplementasikan konsep <b>Hysteresis</b> dengan Radius Keluar 20 meter.\"</i>"
    )
    story.append(Table([[Paragraph(ans1, highlight_style)]], colWidths=[505],
                       style=[('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f0fdf4')), ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#bbf7d0')), ('PADDING', (0,0), (-1,-1), 8)]))
    story.append(Spacer(1, 6))

    story.append(Paragraph("<b>Pertanyaan 2: Mengapa posisi GPS saat pembuatan marker sering meleset dan bagaimana solusinya?</b>", h2_style))
    ans2 = (
        "<i>\"Kelemahan pembacaan GPS mentah (single fix) adalah rentan terhadap error fluktuasi hingga 15 meter. Solusi yang kami terapkan pada <code>AddSpotScreen</code> "
        "adalah <b>Multi-Sample GPS Averaging</b>. Aplikasi mengumpulkan 10 sampel koordinat real-time lalu merata-ratakannya sebelum disimpan ke Firestore, "
        "lengkap dengan metadata <code>accuracy</code> dan <code>sample_count</code>. Kami juga menyediakan tombol <b>Kalibrasi Ulang Lokasi</b> di <code>DetailScreen</code> "
        "sehingga koordinat dapat diperbarui kapan saja.\"</i>"
    )
    story.append(Table([[Paragraph(ans2, highlight_style)]], colWidths=[505],
                       style=[('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f0fdf4')), ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#bbf7d0')), ('PADDING', (0,0), (-1,-1), 8)]))
    story.append(Spacer(1, 6))

    story.append(Paragraph("<b>Pertanyaan 3: Bagaimana Anda memastikan tidak ada memory leak dan data antara UI serta Notifikasi tetap konsisten?</b>", h2_style))
    ans3 = (
        "<i>\"Kami menerapkan arsitektur <b>Single Source of Truth</b>. Seluruh komponen (UI HomeScreen, Status Monitor Debug Panel, dan Notifikasi) mendengarkan "
        "satu stream terpusat <code>GeofenceService().stateStream</code> yang membroadcast objek snapshot <code>GeofenceState</code>. "
        "Selain itu, semua <code>StreamSubscription</code> dan <code>Timer</code> dibatalkan secara bersih pada method <code>dispose()</code>, "
        "serta jika marker dihapus, method <code>onSpotDeleted()</code> membatalkan timer dan notifikasi di status bar dalam hitungan 0 detik.\"</i>"
    )
    story.append(Table([[Paragraph(ans3, highlight_style)]], colWidths=[505],
                       style=[('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f0fdf4')), ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#bbf7d0')), ('PADDING', (0,0), (-1,-1), 8)]))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF berhasil dibuat: {filename}")

if __name__ == "__main__":
    build_pdf()
