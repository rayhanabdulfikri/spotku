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
        self.drawString(45, 805, "SPESIFIKASI TEKNIS: SISTEM NOTIFIKASI, PENGUKURAN JARAK & SAMPLING KOORDINAT (SPOTKU)")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        self.drawRightString(550, 805, "Dokumentasi Notifikasi & GIS")
        
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.75)
        self.line(45, 797, 550, 797)
        
        # Footer (Bottom)
        self.line(45, 45, 550, 45)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        self.drawString(45, 32, "SpotKu - Focus Report: Inbox Stacking, 10 GPS Samples Averaging & Distance Algorithm")
        page_text = f"Halaman {self._pageNumber} dari {page_count}"
        self.drawRightString(550, 32, page_text)
        self.restoreState()

def build_pdf(filename="DOKUMENTASI_TEKNIS_NOTIFIKASI_DAN_PENGUKURAN_JARAK.pdf"):
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
        fontSize=16,
        leading=20,
        textColor=colors.HexColor('#0f766e'),
        spaceAfter=4
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor('#475569'),
        spaceAfter=10
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=14.5,
        textColor=colors.HexColor('#0f766e'),
        spaceBefore=9,
        spaceAfter=4
    )

    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=12.5,
        textColor=colors.HexColor('#1e293b'),
        spaceBefore=5,
        spaceAfter=3
    )

    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.HexColor('#1e293b'),
        spaceAfter=4
    )

    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7.2,
        leading=10,
        textColor=colors.HexColor('#f8fafc'),
        spaceAfter=0
    )

    code_explain_style = ParagraphStyle(
        'CodeExplain',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor('#0f172a'),
        spaceAfter=0
    )

    highlight_style = ParagraphStyle(
        'HighlightText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor('#166534'),
        spaceAfter=0
    )

    story = []

    # Title & Header
    story.append(Paragraph("DOKUMENTASI TEKNIS: NOTIFIKASI, JARAK &amp; 10 SAMPEL KOORDINAT", title_style))
    story.append(Paragraph("Sistem Stacking Notifikasi, Interaksi Klik Penanda, &amp; Algoritma Averaging 10 Sampel GPS", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#0f766e"), spaceAfter=8))

    # Section 1: Ringkasan Notifikasi Stacking
    story.append(Paragraph("1. Arsitektur Notifikasi Lokal Stacking (WhatsApp Style)", h1_style))
    story.append(Paragraph(
        "Sistem Notifikasi pada <b>SpotKu</b> menggunakan paket <code>flutter_local_notifications</code> dengan gaya "
        "<b>InboxStyleInformation</b> dan <b>Notification ID Tunggal (101)</b>. Tanda counter <code>#</code> telah dihapus "
        "dan diganti dengan format tanggal &amp; jam presisi pembuatan spot.",
        body_style
    ))

    notif_features = [
        [
            Paragraph("<b>Parameter Notifikasi</b>", body_style),
            Paragraph("<b>Format Baru &amp; Penjelasan Teknis</b>", body_style),
            Paragraph("<b>Manfaat UX</b>", body_style)
        ],
        [
            Paragraph("<b>Pesan Tanpa Counter '#'</b>", body_style),
            Paragraph("<code>[$HH:mm:ss] Pernah ke $placeName (Ditandai: $formattedDate)</code>", body_style),
            Paragraph("Informatif &amp; profesional tanpa simbol <code>#1</code>.", body_style)
        ],
        [
            Paragraph("<b>Notification ID 101</b>", body_style),
            Paragraph("<code>_plugin.show(101, title, body, details)</code>", body_style),
            Paragraph("Menumpuk halus di 1 notifikasi tunggal.", body_style)
        ],
        [
            Paragraph("<b>Pencegahan Berisik</b>", body_style),
            Paragraph("<code>onlyAlertOnce: true</code> &amp; <code>playSound: _count == 1</code>", body_style),
            Paragraph("Bunyi berdering hanya di pengingat pertama.", body_style)
        ],
        [
            Paragraph("<b>Pembersihan Instant (0s)</b>", body_style),
            Paragraph("<code>onSpotDeleted()</code> memanggil <code>cancelAllNotifications()</code>", body_style),
            Paragraph("Notifikasi hilang seketika jika spot dihapus.", body_style)
        ]
    ]

    notif_table = Table(notif_features, colWidths=[115, 200, 190])
    notif_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#e6fffa')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(notif_table)
    story.append(Spacer(1, 6))

    # Section 2: Interaksi Klik Penanda & Kalibrasi 10 Sampel Koordinat
    story.append(Paragraph("2. Interaksi Klik Penanda &amp; Multi-Sample GPS Averaging (10 Sampel Titik)", h1_style))
    story.append(Paragraph(
        "Untuk mengeliminasi error GPS mentah (yang sering meleset 14m-16m akibat <i>single fix</i>), aplikasi menerapkan "
        "<b>Mekanisme Kalibrasi 10 Sampel Koordinat</b> saat pengguna mengeklik penanda / tombol kalibrasi lokasi.",
        body_style
    ))

    # Diagram Alur Klik Penanda & 10 Sampel
    flow_box = (
        "<b>Alur Kerja Klik Penanda &amp; Sampling 10 Koordinat:</b><br/>"
        "[ 1. Pengguna Mengeklik Penanda Spot / Tombol 'Kalibrasi Ulang' di DetailScreen ]<br/>"
        "                                │<br/>"
        "                                ▼<br/>"
        "[ 2. Sistem Membuka Stream GPS High Accuracy &amp; Mengumpulkan 10 Sampel Titik Lokasi ]<br/>"
        "                                │  (Sampel 1/10 ──&gt; Sampel 2/10 ──&gt; ... ──&gt; Sampel 10/10)<br/>"
        "                                ▼<br/>"
        "[ 3. Sistem Menghitung Rata-Rata Koordinat &amp; Akurasi Matematik ]<br/>"
        "    lat_avg = (∑ lat_i) / 10  │  lng_avg = (∑ lng_i) / 10  │  acc_avg = (∑ acc_i) / 10<br/>"
        "                                ▼<br/>"
        "[ 4. Menyimpan lat_avg, lng_avg, accuracy, &amp; sample_count: 10 ke Firestore ]"
    )
    flow_table = Table([[Paragraph(flow_box, code_explain_style)]], colWidths=[505])
    flow_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f1f5f9')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#94a3b8')),
        ('PADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(flow_table)
    story.append(Spacer(1, 6))

    # Section 3: Algoritma Jarak & Hysteresis
    story.append(Paragraph("3. Algoritma Pengukuran Jarak &amp; Hysteresis Radius", h1_style))

    geo_data = [
        [
            Paragraph("<b>Konsep GIS</b>", body_style),
            Paragraph("<b>Nilai &amp; Rumus Teknis</b>", body_style),
            Paragraph("<b>Penjelasan Fungsi</b>", body_style)
        ],
        [
            Paragraph("<b>Radius Masuk (Entry)</b>", body_style),
            Paragraph("<code>15.0 meter</code>", body_style),
            Paragraph("Memicu status <code>INSIDE</code> dan memulai timer notifikasi 5 detik.", body_style)
        ],
        [
            Paragraph("<b>Radius Keluar (Exit Hysteresis)</b>", body_style),
            Paragraph("<code>20.0 meter</code> (+5m)", body_style),
            Paragraph("Mencegah notifikasi berkedip (*flicker*) di perbatasan radius.", body_style)
        ],
        [
            Paragraph("<b>Formula Jarak Geodesik</b>", body_style),
            Paragraph("<code>Geolocator.distanceBetween()</code>", body_style),
            Paragraph("Menghitung jarak lintang/bujur riil antara GPS user &amp; spot.", body_style)
        ],
        [
            Paragraph("<b>Garis &amp; Badge Jarak</b>", body_style),
            Paragraph("<code>Polyline</code> &amp; Midpoint Marker", body_style),
            Paragraph("Merender garis elastis ke spot terdekat beserta badge jarak real-time.", body_style)
        ]
    ]

    geo_table = Table(geo_data, colWidths=[115, 200, 190])
    geo_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#e6fffa')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(geo_table)
    story.append(Spacer(1, 6))

    # Section 4: Bedah Kode Rinci
    story.append(Paragraph("4. Bedah Kode Rinci (Klik Penanda &amp; 10 Sampel Koordinat)", h1_style))

    # 4.1 Code DetailScreen Kalibrasi 10 Sampel
    story.append(Paragraph("A. Mengumpulkan 10 Sampel Koordinat saat Klik Penanda (lib/screens/detail_screen.dart)", h2_style))
    code_calib = (
        "1: sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {\n"
        "2:   samples.add(pos); // Tambahkan sampel koordinat ke daftar\n"
        "3:   if (samples.length >= 10) { sub?.cancel(); completer.complete(); }\n"
        "4: });\n"
        "5: double avgLat = sumLat / 10; double avgLng = sumLng / 10; double avgAcc = sumAcc / 10;\n"
        "6: await firestore.doc(spot.id).update({\n"
        "7:   'latitude': avgLat, 'longitude': avgLng, 'accuracy': avgAcc, 'sample_count': 10\n"
        "8: });"
    )
    explain_calib = (
        "<b>Penjelasan Kode:</b><br/>"
        "&bull; <b>Baris 1-4</b>: Saat pengguna mengeklik penanda &amp; tombol kalibrasi, sistem mengambil 10 sampel titik koordinat secara berurutan.<br/>"
        "&bull; <b>Baris 5</b>: Merata-ratakan koordinat ($\text{lat}_{\text{avg}}, \text{lng}_{\text{avg}}$) dan akurasi ($\text{acc}_{\text{avg}}$) dari 10 sampel.<br/>"
        "&bull; <b>Baris 6-8</b>: Meng-update dokumen Firestore dengan koordinat presisi baru dan menyimpan metadata <code>sample_count: 10</code>."
    )
    story.append(Table([[Paragraph(code_calib, code_style), Paragraph(explain_calib, code_explain_style)]], colWidths=[210, 295],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 5)]))
    story.append(Spacer(1, 6))

    # 4.2 Code AddSpotScreen 10 Sampel
    story.append(Paragraph("B. Multi-Sample Averaging saat Tambah Spot Baru (lib/screens/add_spot_screen.dart)", h2_style))
    code_add_spec = (
        "1: void _calculateAverageLocation() {\n"
        "2:   for (final pos in _locationSamples) {\n"
        "3:     sumLat += pos.latitude; sumLng += pos.longitude; sumAcc += pos.accuracy;\n"
        "4:   }\n"
        "5:   _avgLat = sumLat / _locationSamples.length;\n"
        "6:   _avgLng = sumLng / _locationSamples.length;\n"
        "7: }"
    )
    explain_add_spec = (
        "<b>Penjelasan Kode:</b><br/>"
        "&bull; <b>Baris 1-7</b>: Fungsi matematika yang menghitung rata-rata dari seluruh sampel GPS yang terkumpul sebelum pengguna menekan tombol Simpan."
    )
    story.append(Table([[Paragraph(code_add_spec, code_style), Paragraph(explain_add_spec, code_explain_style)]], colWidths=[210, 295],
                       style=[('BACKGROUND', (0,0), (0,0), colors.HexColor('#0f172a')), ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')), ('PADDING', (0,0), (-1,-1), 5)]))
    story.append(Spacer(1, 8))

    # Section 5: Jawaban Dosen
    story.append(Paragraph("5. Naskah Jawaban Dosen (Fokus Klik Penanda &amp; 10 Sampel Koordinat)", h1_style))

    ans_dosen = (
        "<b>Dosen: Bagaimana cara aplikasi Anda menjamin koordinat pada penanda spot benar-benar presisi?</b><br/>"
        "<i>\"Saat pengguna mengeklik penanda spot untuk melakukan kalibrasi atau membuat spot baru, aplikasi tidak hanya mengambil satu titik lokasi mentah. "
        "Sistem kami membuka stream GPS presisi tinggi dan mengumpulkan <b>10 sampel titik koordinat secara berurutan</b>. "
        "Seluruh sampel tersebut kemudian dirata-ratakan koordinat lintang dan bujurnya (lat_avg, lng_avg) untuk mengeliminasi fluktuasi error pembacaan GPS mentah "
        "yang biasa meleset hingga 15 meter. Koordinat hasil rerata ini disimpan ke Firestore bersama metadata <code>accuracy</code> dan <code>sample_count: 10</code>, "
        "sehingga pengukuran jarak geofencing menjadi jauh lebih stabil dan akurat.\"</i>"
    )
    story.append(Table([[Paragraph(ans_dosen, highlight_style)]], colWidths=[505],
                       style=[('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f0fdf4')), ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#bbf7d0')), ('PADDING', (0,0), (-1,-1), 7)]))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF spesifik berhasil diperbarui: {filename}")

if __name__ == "__main__":
    build_pdf()
