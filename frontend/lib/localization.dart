import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the UI language separately from medical/profile values.
class AppLanguage extends ValueNotifier<Locale> {
  AppLanguage._() : super(const Locale('en'));
  static final instance = AppLanguage._();
  SharedPreferences? _preferences;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    value = Locale(
      _preferences!.getString('app_language') == 'ms' ? 'ms' : 'en',
    );
  }

  Future<void> select(String code) async {
    if (code != 'en' && code != 'ms') return;
    value = Locale(code);
    await _preferences?.setString('app_language', code);
  }
}

/// Presentation-only translation keeps stored selections and triage rules stable.
String tr(String text) {
  if (AppLanguage.instance.value.languageCode != 'ms') return text;
  final exact = malayTranslations[text];
  if (exact != null) return exact;
  for (final entry in translationTemplates.entries) {
    final match = entry.key.firstMatch(text);
    if (match != null) return entry.value(match);
  }
  // Translate complete sentences before individual composite values.
  if (text.contains('. ')) {
    return text.split('. ').map(tr).join('. ');
  }
  for (final separator in ['\n', ', ', ' / ', ': ', ' | ']) {
    if (text.contains(separator)) {
      return text.split(separator).map(tr).join(separator);
    }
  }
  return text;
}

final translationTemplates = <RegExp, String Function(RegExpMatch)>{
  RegExp(r'^A password reset link has been sent to (.*)$'): (m) =>
      'Pautan tetapan semula kata laluan telah dihantar ke ${m[1]}',
  RegExp(r'^A 6-digit TAC has been sent to (.*)$'): (m) =>
      'TAC 6 digit telah dihantar ke ${m[1]}',
  RegExp(r'^Outcome: (.*) \((.*)\)$'): (m) =>
      'Hasil: ${tr(m[1]!)} (${tr(m[2]!)})',
  RegExp(r'^Step (\d+) of (\d+) \u00b7 (.+)$'): (m) =>
      'Langkah ${m[1]} daripada ${m[2]} \u00b7 ${tr(m[3]!)}',
  RegExp(r'^(.*) · Level (\d+)$'): (m) => '${tr(m[1]!)} · Tahap ${m[2]}',
  RegExp(r'^(.*) away$'): (m) => '${m[1]} dari sini',
  RegExp(r'^(\d+) min ago$'): (m) => '${m[1]} minit lalu',
  RegExp(r'^(\d+) days ago$'): (m) => '${m[1]} hari lalu',
  RegExp(r'^(\d+) min$'): (m) => '${m[1]} minit',
  RegExp(r'^(\d+) years old$'): (m) => '${m[1]} tahun',
  RegExp(r'^A new TAC has been sent\. Prototype TAC: (.*)$'): (m) =>
      'TAC baharu telah dihantar. TAC prototaip: ${m[1]}',
  RegExp(r'^TAC sent to (.*)\. Prototype TAC: (.*)$'): (m) =>
      'TAC dihantar ke ${m[1]}. TAC prototaip: ${m[2]}',
  RegExp(r'^(\d+) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (.*)$'): (
    m,
  ) => '${m[1]} ${tr(m[2]!)} ${m[3]}',
};

/// A Text with the same styling that also reacts inside const widget subtrees.
class LocalizedText extends StatelessWidget {
  const LocalizedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: AppLanguage.instance,
    builder: (context, locale, child) => Text(
      tr(data),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
    ),
  );
}

const malayTranslations = <String, String>{
  'Language': 'Bahasa',
  'App language': 'Bahasa aplikasi',
  'e.g. 010101-01-1234': 'cth. 010101-01-1234',
  'e.g. 0123456789': 'cth. 0123456789',
  'Choose your preferred app language.': 'Pilih bahasa aplikasi anda.',
  "Welcome back": "Selamat kembali",
  "Phone Number": "Nombor Telefon",
  "Log in": "Log masuk",
  "Log in to continue your screening.":
      "Log masuk untuk meneruskan saringan anda.",
  "Welcome to TriageMY": "Selamat datang ke TriageMY",
  "Password": "Kata Laluan",
  "Forgot password?": "Lupa kata laluan?",
  "Forgot your password?": "Lupa kata laluan anda?",
  "Don't have an account? ": "Belum mempunyai akaun? ",
  "Already have an account? ": "Sudah mempunyai akaun? ",
  "Create Account": "Cipta Akaun",
  "Create account": "Cipta akaun",
  "Create your account": "Cipta akaun anda",
  "Set up your account to start using TriageMY.":
      "Sediakan akaun anda untuk mula menggunakan TriageMY.",
  "Full Name": "Nama Penuh",
  "IC Number": "Nombor Kad Pengenalan",
  "Email": "E-mel",
  "Email Address": "Alamat E-mel",
  "Enter your password": "Masukkan kata laluan anda",
  "Confirm Password": "Sahkan Kata Laluan",
  "Re-enter your password": "Masukkan semula kata laluan anda",
  "Use at least 8 characters.": "Gunakan sekurang-kurangnya 8 aksara.",
  "Your details": "Maklumat anda",
  "Verify phone": "Sahkan telefon",
  "New password": "Kata laluan baharu",
  "New Password": "Kata Laluan Baharu",
  "Confirm New Password": "Sahkan Kata Laluan Baharu",
  "Enter new password": "Masukkan kata laluan baharu",
  "Re-enter new password": "Masukkan semula kata laluan baharu",
  "Create a password": "Cipta kata laluan",
  "Send Reset Link": "Hantar Pautan Tetapan Semula",
  "Verify Reset Link": "Sahkan Pautan Tetapan Semula",
  "Change Password": "Tukar Kata Laluan",
  "Verify link": "Sahkan pautan",
  "Resend email": "Hantar semula e-mel",
  "Enter your registered email address and we'll send you a password reset link.": "Masukkan alamat e-mel berdaftar anda dan kami akan menghantar pautan untuk menetapkan semula kata laluan.",
  "A password reset link has been sent to ":
      "Pautan tetapan semula kata laluan telah dihantar ke ",
  "A 6-digit TAC has been sent to ": "TAC 6 digit telah dihantar ke ",
  "Enter 6-digit TAC": "Masukkan TAC 6 digit",
  "Enter TAC": "Masukkan TAC",
  "Resend TAC": "Hantar semula TAC",
  "Verify TAC & Create Account": "Sahkan TAC & Cipta Akaun",
  "Verified": "Disahkan",
  "Please enter your email address.": "Sila masukkan alamat e-mel anda.",
  "Please enter your new password.": "Sila masukkan kata laluan baharu anda.",
  "Please enter your phone number and password.":
      "Sila masukkan nombor telefon dan kata laluan anda.",
  "Please complete all required fields.": "Sila lengkapkan semua medan wajib.",
  "Please enter the TAC.": "Sila masukkan TAC.",
  "Invalid TAC. Please try again.": "TAC tidak sah. Sila cuba lagi.",
  "Passwords do not match.": "Kata laluan tidak sepadan.",
  "Password must contain at least 8 characters.":
      "Kata laluan mesti mengandungi sekurang-kurangnya 8 aksara.",
  "Password changed successfully.": "Kata laluan berjaya ditukar.",
  "Password reset link sent. Prototype mode.":
      "Pautan tetapan semula kata laluan dihantar. Mod prototaip.",
  "Email link verified.": "Pautan e-mel disahkan.",
  "Email verified. You can now create a new password.":
      "E-mel disahkan. Anda kini boleh mencipta kata laluan baharu.",
  "Account created successfully!": "Akaun berjaya dicipta!",
  "Your phone number is verified using TAC before your account is activated.": "Nombor telefon anda disahkan menggunakan TAC sebelum akaun anda diaktifkan.",
  "Home": "Utama",
  "Triage": "Triage",
  "AI Triage": "Triage AI",
  "Profile": "Profil",
  "Progress": "Kemajuan",
  "Hospitals": "Hospital",
  "Notifications": "Pemberitahuan",
  "User Profile": "Profil Pengguna",
  "Personal and medical information": "Maklumat peribadi dan perubatan",
  "Personal Information": "Maklumat Peribadi",
  "Medical Information": "Maklumat Perubatan",
  "Medical History": "Sejarah Perubatan",
  "Date of Birth": "Tarikh Lahir",
  "Age": "Umur",
  "Age / Sex": "Umur / Jantina",
  "Sex at Birth": "Jantina Semasa Lahir",
  "Nationality": "Kewarganegaraan",
  "Preferred Language": "Bahasa Pilihan",
  "Height": "Ketinggian",
  "Weight": "Berat",
  "Blood Type": "Kumpulan Darah",
  "Blood type": "Kumpulan darah",
  "Chronic Conditions": "Penyakit Kronik",
  "Chronic conditions": "Penyakit kronik",
  "Allergies": "Alahan",
  "Current Medications": "Ubat Semasa",
  "Current medication": "Ubat semasa",
  "Past Surgeries": "Pembedahan Terdahulu",
  "Family History": "Sejarah Keluarga",
  "Smoking Status": "Status Merokok",
  "Alcohol Use": "Pengambilan Alkohol",
  "Organ Donor": "Penderma Organ",
  "Emergency Contact": "Hubungan Kecemasan",
  "Contact Name": "Nama Kenalan",
  "Contact Number": "Nombor Telefon Kenalan",
  "Relationship": "Hubungan",
  "Permissions": "Kebenaran",
  "Location Consent": "Kebenaran Lokasi",
  "Allow TriageMY to use your location for nearby care.": "Benarkan TriageMY menggunakan lokasi anda untuk mencari rawatan berdekatan.",
  "Calculated automatically from IC number.":
      "Dikira secara automatik daripada nombor kad pengenalan.",
  "Please specify": "Sila nyatakan",
  "Select one or more": "Pilih satu atau lebih",
  "Select all that apply.": "Pilih semua yang berkenaan.",
  "You can select multiple options or add your own.":
      "Anda boleh memilih beberapa pilihan atau menambah pilihan sendiri.",
  "Add your own": "Tambah pilihan sendiri",
  "Add another allergy": "Tambah alahan lain",
  "Add another condition": "Tambah penyakit lain",
  "Add another medication": "Tambah ubat lain",
  "Add another surgery": "Tambah pembedahan lain",
  "Edit": "Sunting",
  "Save": "Simpan",
  "Done": "Selesai",
  "Remove": "Buang",
  "Yes": "Ya",
  "No": "Tidak",
  "None": "Tiada",
  "Other": "Lain-lain",
  "Unknown": "Tidak diketahui",
  "Unsure": "Tidak pasti",
  "Not specified": "Tidak dinyatakan",
  "None selected": "Tiada pilihan",
  "None reported": "Tiada dilaporkan",
  "Male": "Lelaki",
  "Female": "Perempuan",
  "Intersex": "Interseks",
  "English": "Inggeris",
  "Mandarin": "Mandarin",
  "Tamil": "Tamil",
  "Asthma": "Asma",
  "Diabetes": "Diabetes",
  "Hypertension": "Hipertensi",
  "Heart disease": "Penyakit jantung",
  "Epilepsy": "Epilepsi",
  "Kidney disease": "Penyakit buah pinggang",
  "Stroke": "Strok",
  "Cancer": "Kanser",
  "Medication": "Ubat",
  "Food": "Makanan",
  "Latex": "Lateks",
  "Environmental": "Persekitaran",
  "No known allergies": "Tiada alahan yang diketahui",
  "Painkillers": "Ubat tahan sakit",
  "Antibiotics": "Antibiotik",
  "Blood pressure medication": "Ubat tekanan darah",
  "Diabetes medication": "Ubat diabetes",
  "Asthma medication": "Ubat asma",
  "Appendectomy": "Pembedahan apendiks",
  "Caesarean section": "Pembedahan Caesarean",
  "Gallbladder surgery": "Pembedahan pundi hempedu",
  "Heart surgery": "Pembedahan jantung",
  "Orthopaedic surgery": "Pembedahan ortopedik",
  "Never": "Tidak pernah",
  "Former": "Bekas perokok",
  "Current": "Masih merokok",
  "Occasional": "Sekali-sekala",
  "Regular": "Kerap",
  "Mother": "Ibu",
  "Father": "Bapa",
  "Child": "Anak",
  "Spouse": "Pasangan",
  "Sibling": "Adik-beradik",
  "Guardian": "Penjaga",
  "Relative": "Saudara",
  "Friend": "Rakan",
  "Profile saved. Some fields are still empty.":
      "Profil disimpan. Beberapa medan masih kosong.",
  "Profile updated.": "Profil dikemas kini.",
  "years old": "tahun",
  "How are you feeling?": "Bagaimanakah keadaan anda?",
  "Check your symptoms and get guidance on what to do next.":
      "Semak gejala anda dan dapatkan panduan tentang langkah seterusnya.",
  "Check urgency": "Semak tahap kecemasan",
  "Find appropriate care": "Cari rawatan yang sesuai",
  "Nearby care": "Rawatan berdekatan",
  "Browse nearby care options.": "Lihat pilihan rawatan berdekatan.",
  "Quick access": "Akses pantas",
  "Start triage": "Mulakan triage",
  "Complete your medical profile": "Lengkapkan profil perubatan anda",
  "Help us provide more relevant guidance.":
      "Bantu kami memberikan panduan yang lebih sesuai.",
  "Recent activity": "Aktiviti terkini",
  "No recent triage": "Tiada triage terkini",
  "Your latest screening result will appear here.":
      "Keputusan saringan terkini anda akan dipaparkan di sini.",
  "Triage completed": "Triage selesai",
  "Triage result ready": "Keputusan triage tersedia",
  "Your latest triage screening has been completed.":
      "Saringan triage terkini anda telah selesai.",
  "Suggested care options": "Pilihan rawatan yang dicadangkan",
  "Based on your triage result and available care information.":
      "Berdasarkan keputusan triage anda dan maklumat rawatan yang tersedia.",
  "How TriageMY works": "Cara TriageMY berfungsi",
  "Guide": "Panduan",
  "3 steps": "3 langkah",
  "Tell us": "Beritahu kami",
  "Screen": "Saringan",
  "Use TriageMY to screen symptoms and explore suitable care options.": "Gunakan TriageMY untuk menyaring gejala dan mencari pilihan rawatan yang sesuai.",
  "Need urgent help?": "Perlukan bantuan segera?",
  "Need immediate help?": "Perlukan bantuan segera?",
  "Emergency Services": "Perkhidmatan Kecemasan",
  "Call emergency services": "Hubungi perkhidmatan kecemasan",
  "Copy 999": "Salin 999",
  "999 copied. Open your dialer to call.":
      "999 disalin. Buka pendail telefon untuk membuat panggilan.",
  "For a medical emergency, call 999.":
      "Untuk kecemasan perubatan, hubungi 999.",
  "If you are experiencing a medical emergency, call 999 immediately.":
      "Jika anda mengalami kecemasan perubatan, hubungi 999 dengan segera.",
  "In an emergency, call 999.": "Dalam kecemasan, hubungi 999.",
  "In an emergency call 999.": "Dalam kecemasan, hubungi 999.",
  "TriageMY does not diagnose conditions or replace assessment by a healthcare professional.": "TriageMY tidak mendiagnosis penyakit atau menggantikan penilaian oleh profesional kesihatan.",
  "Your health information": "Maklumat kesihatan anda",
  "Review your medical history": "Semak sejarah perubatan anda",
  "Keep your allergies, medications, and medical conditions up to date.":
      "Pastikan maklumat alahan, ubat dan penyakit anda sentiasa terkini.",
  "Emergency contact reminder": "Peringatan hubungan kecemasan",
  "Make sure your emergency contact information is correct.":
      "Pastikan maklumat hubungan kecemasan anda betul.",
  "Only information necessary for screening and care should be stored and used.": "Hanya maklumat yang diperlukan untuk saringan dan rawatan patut disimpan dan digunakan.",
  "Answer a few questions to help us understand your condition.":
      "Jawab beberapa soalan untuk membantu kami memahami keadaan anda.",
  "Step 1": "Langkah 1",
  "What are you feeling?": "Apakah gejala yang anda alami?",
  "Select the main symptom.": "Pilih gejala utama.",
  "Your symptoms": "Gejala anda",
  "Fever": "Demam",
  "Cough": "Batuk",
  "Chest pain": "Sakit dada",
  "Stomach pain": "Sakit perut",
  "Minor injury": "Kecederaan ringan",
  "How severe is it?": "Sejauh manakah keterukannya?",
  "Choose the level that best describes your condition.":
      "Pilih tahap yang paling menggambarkan keadaan anda.",
  "Mild": "Ringan",
  "Moderate": "Sederhana",
  "Severe": "Teruk",
  "How long have you had it?": "Berapa lamakah anda mengalaminya?",
  "Select the duration.": "Pilih tempoh.",
  "Less than 24 hours": "Kurang daripada 24 jam",
  "More than 3 days": "Lebih daripada 3 hari",
  "1\u20133 days": "1\u20133 hari",
  "Any danger signs?": "Ada tanda bahaya?",
  "Difficulty breathing": "Kesukaran bernafas",
  "Heavy bleeding": "Pendarahan banyak",
  "None of these": "Tiada yang di atas",
  "Finish triage": "Selesaikan triage",
  "Triage Report": "Laporan Triage",
  "A summary of your screening, ready to save or share.":
      "Ringkasan saringan anda, sedia untuk disimpan atau dikongsi.",
  "Save PDF": "Simpan PDF",
  "Print": "Cetak",
  "Copy": "Salin",
  "Hospital routing": "Laluan ke hospital",
  "Triage outcome": "Hasil triage",
  "Reported symptoms": "Gejala yang dilaporkan",
  "Patient information": "Maklumat pesakit",
  "Main symptom": "Gejala utama",
  "Severity": "Keterukan",
  "Duration": "Tempoh",
  "Danger signs": "Tanda bahaya",
  "Name": "Nama",
  "Red Zone": "Zon Merah",
  "Yellow Zone": "Zon Kuning",
  "Green Zone": "Zon Hijau",
  "Emergency care advised": "Rawatan kecemasan disarankan",
  "Urgent assessment advised": "Penilaian segera disarankan",
  "Medical review advised": "Pemeriksaan doktor disarankan",
  "Non-critical case": "Kes tidak kritikal",
  "You reported danger signs. Call 999 or go to the nearest emergency department immediately.": "Anda melaporkan tanda bahaya. Hubungi 999 atau pergi ke jabatan kecemasan terdekat dengan segera.",
  "Your symptoms are severe. Seek medical care as soon as possible and do not wait for them to worsen.": "Gejala anda teruk. Dapatkan rawatan perubatan secepat mungkin dan jangan tunggu sehingga keadaan bertambah buruk.",
  "Arrange to see a doctor within the next day. Seek care sooner if your symptoms get worse.": "Aturkan pemeriksaan doktor dalam masa sehari. Dapatkan rawatan lebih awal jika gejala bertambah buruk.",
  "Your screening indicates a non-critical case. You may consider facilities with a shorter waiting time.": "Saringan anda menunjukkan kes tidak kritikal. Anda boleh mempertimbangkan kemudahan dengan masa menunggu yang lebih singkat.",
  "Report copied to clipboard.": "Laporan disalin ke papan keratan.",
  "Could not create the PDF. Please try again.":
      "PDF tidak dapat dihasilkan. Sila cuba lagi.",
  "Could not open the print dialog.": "Dialog cetakan tidak dapat dibuka.",
  "TriageMY - Triage Report": "TriageMY - Laporan Triage",
  "Report ID": "ID Laporan",
  "Date": "Tarikh",
  "Outcome": "Hasil",
  "SYMPTOMS": "GEJALA",
  "PATIENT": "PESAKIT",
  "Hospitals & Clinics": "Hospital & Klinik",
  "Recommended Hospitals": "Hospital Disyorkan",
  "Search hospital or clinic": "Cari hospital atau klinik",
  "Getting your current location...": "Mendapatkan lokasi semasa anda...",
  "Showing hospitals and clinics near your location.":
      "Memaparkan hospital dan klinik berhampiran lokasi anda.",
  "Closest": "Terdekat",
  "Shortest wait": "Masa menunggu tersingkat",
  "Best match": "Paling sesuai",
  "Open Now": "Dibuka Sekarang",
  "Open 24/7": "Dibuka 24 jam",
  "General Hospital": "Hospital Umum",
  "Private Hospital": "Hospital Swasta",
  "Clinic": "Klinik",
  "Est. wait": "Anggaran menunggu",
  "Empty beds": "Katil kosong",
  "Patients": "Pesakit",
  "Directions": "Arah",
  "View Route": "Lihat Laluan",
  "Open directions with": "Buka arah menggunakan",
  "Open route with": "Buka laluan menggunakan",
  "Could not open Google Maps": "Google Maps tidak dapat dibuka",
  "Could not open Waze": "Waze tidak dapat dibuka",
  "You may consider facilities with a shorter waiting time.": "Anda boleh mempertimbangkan kemudahan dengan masa menunggu yang lebih singkat.",
  "Hospital wait time updated": "Masa menunggu hospital dikemas kini",
  "A nearby hospital now has a shorter estimated waiting time.": "Sebuah hospital berdekatan kini mempunyai anggaran masa menunggu yang lebih singkat.",
  "Just now": "Baru sahaja",
  "Yesterday": "Semalam",
  "Close": "Tutup",
  "Progress Tracking": "Penjejakan Kemajuan",
  "Follow hospital visit updates for you and approved family members.": "Ikuti perkembangan lawatan hospital untuk anda dan ahli keluarga yang dibenarkan.",
  "My Progress": "Kemajuan Saya",
  "My progress": "Kemajuan saya",
  "Family": "Keluarga",
  "Family members": "Ahli keluarga",
  "View progress for people who have approved you as an emergency contact.": "Lihat kemajuan individu yang telah meluluskan anda sebagai hubungan kecemasan.",
  "Family progress is only available when the patient has approved access.": "Kemajuan keluarga hanya tersedia apabila pesakit telah meluluskan akses.",
  "Active visit": "Lawatan aktif",
  "No active visit": "Tiada lawatan aktif",
  "No current hospital visit": "Tiada lawatan hospital semasa",
  "Visit progress": "Kemajuan lawatan",
  "Queue number": "Nombor giliran",
  "Department": "Jabatan",
  "Current status": "Status semasa",
  "Emergency Department": "Jabatan Kecemasan",
  "Paediatric Department": "Jabatan Pediatrik",
  "Waiting for doctor consultation": "Menunggu konsultasi doktor",
  "Waiting for X-ray": "Menunggu sinar-X",
  "Registration completed": "Pendaftaran selesai",
  "Primary screening": "Saringan awal",
  "Blood test completed": "Ujian darah selesai",
  "Doctor consultation pending": "Menunggu konsultasi doktor",
  "Discharge / admission decision pending":
      "Menunggu keputusan discaj / kemasukan",
  "X-ray in queue": "Menunggu giliran sinar-X",
  "Complete": "Selesai",
  "In progress": "Sedang berjalan",
  "Waiting": "Menunggu",
  "Next steps": "Langkah seterusnya",
  "Recent updates": "Kemas kini terkini",
  "Family visibility": "Akses keluarga",
  "Approved emergency contacts may view this visit's progress.":
      "Hubungan kecemasan yang dibenarkan boleh melihat kemajuan lawatan ini.",
  "Actual timing may change depending on clinical priority and hospital workflow.": "Masa sebenar mungkin berubah mengikut keutamaan klinikal dan aliran kerja hospital.",
  "Sample data is shown for the prototype.":
      "Data contoh dipaparkan untuk prototaip.",
  "You": "Anda",
  "Preliminary screening only": "Saringan awal sahaja",
  "May": "Mei",
  "Aug": "Ogo",
  "Oct": "Okt",
  "Dec": "Dis",
  "Check your\nsymptoms": "Semak gejala\nanda",
  "Difficulty\nbreathing": "Kesukaran\nbernafas",
  "Heavy\nbleeding": "Pendarahan\nbanyak",
  "Less than\n24 hours": "Kurang daripada\n24 jam",
  "More than\n3 days": "Lebih daripada\n3 hari",
  "This is a screening aid, not a medical diagnosis. In an emergency call 999.": "Ini ialah alat bantuan saringan, bukan diagnosis perubatan. Dalam kecemasan, hubungi 999.",
  "This report is a screening aid, not a medical diagnosis. In an emergency, call 999.": "Laporan ini ialah alat bantuan saringan, bukan diagnosis perubatan. Dalam kecemasan, hubungi 999.",
  "This report is a screening aid generated from the answers you provided. It is not a medical diagnosis. If your symptoms become severe or you develop emergency warning signs, call 999 or seek emergency care immediately.": "Laporan ini ialah alat bantuan saringan berdasarkan jawapan anda. Ia bukan diagnosis perubatan. Jika gejala anda menjadi teruk atau anda mengalami tanda amaran kecemasan, hubungi 999 atau dapatkan rawatan kecemasan dengan segera.",
  "Progress reflects the latest status recorded by the hospital. Actual timing may change depending on clinical priority and hospital workflow.": "Kemajuan menunjukkan status terkini yang direkodkan oleh hospital. Masa sebenar mungkin berubah mengikut keutamaan klinikal dan aliran kerja hospital.",
  "Your medical information is sensitive. Only information necessary for screening and care should be stored and used.": "Maklumat perubatan anda adalah sulit. Hanya maklumat yang diperlukan untuk saringan dan rawatan patut disimpan dan digunakan.",
  "If you are experiencing emergency warning signs, call 999 or seek emergency medical care immediately.": "Jika anda mengalami tanda amaran kecemasan, hubungi 999 atau dapatkan rawatan kecemasan dengan segera.",
  "If your symptoms become severe or you develop emergency warning signs, seek emergency care immediately.": "Jika gejala anda menjadi teruk atau anda mengalami tanda amaran kecemasan, dapatkan rawatan kecemasan dengan segera.",
  "Green Zone \u00b7 Level 4": "Zon Hijau \u00b7 Tahap 4",
  'Acquiring GPS location...': 'Mendapatkan lokasi GPS...',
  'Distances calculated from your live GPS.': 'Jarak dikira daripada lokasi GPS semasa anda.',
  'Using regional baseline coordinates.': 'Menggunakan koordinat rujukan kawasan.',
  'GPS Active': 'GPS Aktif',
  'Default': 'Lalai',
  'Email, Phone Number, or IC': 'E-mel, Nombor Telefon, atau IC',
  'Enter your full name': 'Masukkan nama penuh anda',
  'Select sex at birth': 'Pilih jantina semasa lahir',
  'Select a country': 'Pilih negara',
  'Select date of birth': 'Pilih tarikh lahir',
  'Please enter your date of birth.': 'Sila masukkan tarikh lahir anda.',
  'IC / Passport Number': 'Nombor Kad Pengenalan / Pasport',
  'Registered date of birth.': 'Tarikh lahir yang didaftarkan.',
};
