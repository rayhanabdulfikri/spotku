import sys
from reportlab.lib.pagesizes import letter, A4
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
            self.draw_page_number(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 9)
        self.setFillColor(colors.HexColor("#64748b"))
        # Header
        self.drawString(54, 800, "Dokumentasi Fitur Pop-Up Foto SpotKu — Panduan Akademik")
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.5)
        self.line(54, 792, 541, 792)
        
        # Footer
        page_text = f"Halaman {self._pageNumber} dari {page_count}"
        self.drawRightString(541, 36, page_text)
        self.drawString(54, 36, "Aplikasi Mobile SpotKu (Flutter & OpenStreetMap)")
        self.line(54, 48, 541, 48)
        self.restoreState()

def build_pdf(filename="Penjelasan_Popup_Pin_SpotKu.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=colors.HexColor('#0f766e'),
        spaceAfter=6
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=11,
        leading=15,
        textColor=colors.HexColor('#475569'),
        spaceAfter=15
    )

    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=colors.HexColor('#0f766e'),
        spaceBefore=14,
        spaceAfter=8
    )

    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#1e293b'),
        spaceAfter=8
    )

    bullet_style = ParagraphStyle(
        'BulletText',
        parent=body_style,
        leftIndent=15,
        spaceAfter=4
    )

    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.HexColor('#f8fafc'),
        spaceAfter=0
    )

    flow_style = ParagraphStyle(
        'FlowText',
        parent=styles['Normal'],
        fontName='Courier-Bold',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor('#0f172a'),
        spaceAfter=0
    )

    highlight_style = ParagraphStyle(
        'HighlightText',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=9.5,
        leading=14,
        textColor=colors.HexColor('#166534'),
        spaceAfter=0
    )

    story = []

    # Title & Header Banner
    story.append(Paragraph("DOKUMENTASI TEKNIS FITUR POP-UP FOTO PIN LOKASI", title_style))
    story.append(Paragraph("Aplikasi Android SpotKu &bull; Penjelasan Kode &amp; Alur Interaksi Pengguna", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor("#0d9488"), spaceAfter=12))

    # Introduction
    intro_p = Paragraph(
        "Dokumen ini memberikan penjelasan teknis komprehensif mengenai mekanisme <b>Fitur Pop-Up Preview Foto dari Pin Lokasi Peta</b> "
        "pada aplikasi <b>SpotKu</b> yang dikembangkan menggunakan framework <b>Flutter</b> dan perender peta <b>OpenStreetMap (flutter_map)</b>.",
        body_style
    )
    story.append(intro_p)

    # Section 1: Konsep Utama State
    story.append(Paragraph("1. Konsep Utama (State Management)", h1_style))
    s1_p = Paragraph(
        "Fitur pop-up ini dikontrol menggunakan mekanisme <i>State Management</i> lokal berbasis <code>StatefulWidget</code> "
        "pada berkas <code>lib/screens/home_screen.dart</code>. Variabel penentu utamanya ditaruh pada state kelas <code>_HomeScreenState</code>:",
        body_style
    )
    story.append(s1_p)

    code_state = "Spot? _selectedSpot; // Menyimpan data spot yang di-klik (null jika tidak ada)"
    code_table = Table([[Paragraph(code_state, code_style)]], colWidths=[483])
    code_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#0f172a')),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
        ('CORNERPAD', (0,0), (-1,-1), 0),
    ]))
    story.append(code_table)
    story.append(Spacer(1, 8))

    story.append(Paragraph("&bull; <b>Jika _selectedSpot == null</b>: Tidak ada kartu pop-up yang muncul di layar peta.", bullet_style))
    story.append(Paragraph("&bull; <b>Jika _selectedSpot berisi objek Spot</b>: Kartu pratinjau gambar dirender melayang tepat di atas koordinat lokasi pin tersebut.", bullet_style))

    # Section 2: Alur Kerja Interaksi
    story.append(Paragraph("2. Alur Kerja Interaksi Pengguna", h1_style))
    
    flow_content = (
        "[ Pengguna Mengetuk Pin Merah di Peta ]<br/>"
        "               │<br/>"
        "               ▼<br/>"
        "[ 1. setState() mengisi _selectedSpot dengan data tempat tersebut ]<br/>"
        "               │<br/>"
        "               ▼<br/>"
        "[ 2. Warna Pin berubah dari MERAH menjadi BIRU ]<br/>"
        "               │<br/>"
        "               ▼<br/>"
        "[ 3. Layer ekstra (MarkerLayer) menggambar Pop-Up Foto di atas Pin ]<br/>"
        "               │<br/>"
        "               ├──────────────────────────────────────────────┐<br/>"
        "               ▼                                              ▼<br/>"
        "[ Jika Pop-Up Foto Diklik ]                [ Jika Area Kosong Peta Diklik ]<br/>"
        "               │                                              │<br/>"
        "               ▼                                              ▼<br/>"
        "[ Pindah ke Layar DetailScreen ]             [ _selectedSpot diubah jadi null ]<br/>"
        "                                                              │<br/>"
        "                                                              ▼<br/>"
        "                                                     [ Pop-Up Tertutup ]"
    )
    flow_table = Table([[Paragraph(flow_content, flow_style)]], colWidths=[483])
    flow_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f8fafc')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#cbd5e1')),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(flow_table)
    story.append(Spacer(1, 10))

    # Section 3: Bedah Kode Rinci
    story.append(Paragraph("3. Bedah Kode Rinci (lib/screens/home_screen.dart)", h1_style))
    
    story.append(Paragraph("<b>A. Deteksi Sentuhan Pin & Perubahan Warna (Baris 112–128)</b>", body_style))
    code_a = (
        "GestureDetector(<br/>"
        "  onTap: () {<br/>"
        "    // 1. Simpan data spot yang diklik ke _selectedSpot<br/>"
        "    setState(() { _selectedSpot = spot; });<br/>"
        "  },<br/>"
        "  child: Icon(<br/>"
        "    Icons.location_pin,<br/>"
        "    // 2. Ubah warna pin terpilih dari Merah menjadi Biru<br/>"
        "    color: _selectedSpot?.id == spot.id ? Colors.blue : Colors.redAccent,<br/>"
        "    size: 40,<br/>"
        "  ),<br/>"
        ")"
    )
    table_a = Table([[Paragraph(code_a, code_style)]], colWidths=[483])
    table_a.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#0f172a')),
        ('PADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(table_a)
    story.append(Spacer(1, 8))

    story.append(Paragraph("<b>B. Menggambar Kartu Pop-Up Melayang (Baris 187–247)</b>", body_style))
    code_b = (
        "if (_selectedSpot != null)<br/>"
        "  MarkerLayer(<br/>"
        "    markers: [<br/>"
        "      Marker(<br/>"
        "        point: LatLng(_selectedSpot!.latitude, _selectedSpot!.longitude),<br/>"
        "        width: 140, height: 140,<br/>"
        "        child: Align(<br/>"
        "          alignment: Alignment.topCenter,<br/>"
        "          child: GestureDetector(<br/>"
        "            onTap: () {<br/>"
        "              // Pindah ke DetailScreen jika pop-up diklik<br/>"
        "              Navigator.push(context, MaterialPageRoute(<br/>"
        "                builder: (_) => DetailScreen(spot: _selectedSpot!),<br/>"
        "              ));<br/>"
        "            },<br/>"
        "            child: Container(<br/>"
        "              margin: const EdgeInsets.only(bottom: 24), // Melayang di atas pin<br/>"
        "              width: 120, height: 90,<br/>"
        "              decoration: BoxDecoration(<br/>"
        "                color: Colors.white,<br/>"
        "                borderRadius: BorderRadius.circular(12),<br/>"
        "                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],<br/>"
        "              ),<br/>"
        "              child: ClipRRect(<br/>"
        "                borderRadius: BorderRadius.circular(12),<br/>"
        "                child: _selectedSpot!.mediaType == 'image'<br/>"
        "                    ? Image.file(File(_selectedSpot!.mediaUrl), fit: BoxFit.cover)<br/>"
        "                    : const Center(child: Icon(Icons.videocam, size: 40)),<br/>"
        "              ),<br/>"
        "            ),<br/>"
        "          ),<br/>"
        "        ),<br/>"
        "      ),<br/>"
        "    ],<br/>"
        "  )"
    )
    table_b = Table([[Paragraph(code_b, code_style)]], colWidths=[483])
    table_b.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#0f172a')),
        ('PADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(table_b)
    story.append(Spacer(1, 8))

    story.append(Paragraph("<b>C. Penutupan Pop-Up Otomatis (Baris 167–173)</b>", body_style))
    code_c = (
        "onTap: (tapPosition, point) {<br/>"
        "  if (_selectedSpot != null) {<br/>"
        "    setState(() { _selectedSpot = null; }); // Reset ke null agar pop-up tertutup<br/>"
        "  }<br/>"
        "},"
    )
    table_c = Table([[Paragraph(code_c, code_style)]], colWidths=[483])
    table_c.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#0f172a')),
        ('PADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(table_c)
    story.append(Spacer(1, 10))

    # Section 4: Panduan Penjelasan Dosen
    story.append(Paragraph("4. Rekomendasi Kalimat Penjelasan untuk Dosen", h1_style))
    highlight_content = (
        "<b>Contoh Kalimat Presentasi Siap Pakai:</b><br/>"
        "<i>\"Fitur pop-up gambar ini dikontrol oleh variabel state <code>_selectedSpot</code> di <code>HomeScreen</code>. "
        "Saat pengguna mengeklik salah satu pin merah di peta, <code>setState()</code> menyimpan data tempat tersebut "
        "dan mengubah warna pin menjadi biru. <code>FlutterMap</code> kemudian merender layer <code>Marker</code> tambahan berupa "
        "kartu <code>Container</code> melayang yang menampilkan pratinjau foto dari file memori HP (<code>Image.file</code>). "
        "Jika kartu foto diklik, aplikasi membuka <code>DetailScreen</code>. Apabila area kosong pada peta diklik, "
        "<code>_selectedSpot</code> diubah menjadi <code>null</code> untuk menutup pop-up secara otomatis.\"</i>"
    )
    highlight_table = Table([[Paragraph(highlight_content, highlight_style)]], colWidths=[483])
    highlight_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f0fdf4')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#bbf7d0')),
        ('PADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(highlight_table)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF berhasil dibuat: {filename}")

if __name__ == "__main__":
    build_pdf()
