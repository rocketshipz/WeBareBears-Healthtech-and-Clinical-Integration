import 'package:flutter/widgets.dart';

/// Languages the hospital side can be shown in.
enum AdminLang {
  en('EN', 'English'),
  ms('BM', 'Bahasa Melayu');

  final String code;
  final String label;

  const AdminLang(this.code, this.label);
}

/// The language currently shown. Change it with [setAdminLang].
final ValueNotifier<AdminLang> adminLang = ValueNotifier(AdminLang.en);

/// Switches language and redraws every open screen in place, so staff stay
/// where they are (open patient, half-filled form, etc.).
void setAdminLang(AdminLang lang) {
  if (adminLang.value == lang) return;
  adminLang.value = lang;

  void rebuild(Element e) {
    e.markNeedsBuild();
    e.visitChildren(rebuild);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
}

/// Translates [en] into the current language. The English text is the key,
/// so a missing translation simply shows English. `{name}` placeholders are
/// filled from [args].
///
/// Stored data (log entries, outcomes, step names typed by staff) is kept in
/// English; wrap it in [tr] only when displaying it.
String tr(String en, [Map<String, Object?> args = const {}]) {
  var s = adminLang.value == AdminLang.ms ? (_ms[en] ?? en) : en;

  args.forEach((key, value) => s = s.replaceAll('{$key}', '$value'));

  return s;
}

const Map<String, String> _ms = {
  'Update results': 'Kemas kini keputusan',
  'Update triage zone': 'Kemas kini zon triaj',
  'Save triage results': 'Simpan keputusan triaj',
  'Update': 'Kemas kini',
  'Custom test': 'Ujian tersuai',
  'Add / update next step': 'Tambah / kemas kini langkah seterusnya',
  'Choose the next step for this patient.':
      'Pilih langkah seterusnya untuk pesakit ini.',
  'Next step': 'Langkah seterusnya',
  'Select next step': 'Pilih langkah seterusnya',
  'Custom step': 'Langkah tersuai',
  'Step name': 'Nama langkah',
  'Enter step or test name': 'Masukkan nama langkah atau ujian',
  'Enter a unique step or test name.':
      'Masukkan nama langkah atau ujian yang unik.',
  'Next step saved.': 'Langkah seterusnya disimpan.',
  'Update step': 'Kemas kini langkah',
  'Add step': 'Tambah langkah',

  'Pending Triage': 'Menunggu triaj',
  'Awaiting zone assignment': 'Menunggu penetapan zon',
  'Add remarks': 'Tambah catatan',
  'Remarks (optional, staff only)': 'Catatan (pilihan, kakitangan sahaja)',
  'Select a triage zone before completing triage.':
      'Pilih zon triaj sebelum melengkapkan triaj.',
  'Add tests or a doctor consultation to this visit.':
      'Tambah ujian atau konsultasi doktor untuk lawatan ini.',
  // ---------------- common ----------------
  'Language': 'Bahasa',
  'Hospital': 'Hospital',
  'Staff': 'Kakitangan',
  'Staff ID': 'ID kakitangan',
  'Role': 'Peranan',
  'Name': 'Nama',
  'Department': 'Jabatan',
  'Emergency Department': 'Jabatan Kecemasan',
  'Nurse': 'Jururawat',
  'Doctor': 'Doktor',
  'Admin': 'Pentadbir',
  'Female': 'Perempuan',
  'Male': 'Lelaki',
  'Queue': 'Giliran',
  'Register': 'Daftar',
  'Account': 'Akaun',
  'Just now': 'Baru sahaja',
  '{n} min ago': '{n} min lalu',
  '{h}h ago': '{h}j lalu',
  '{h}h {m}m ago': '{h}j {m}m lalu',
  '{n} yrs': '{n} thn',
  '{n} page': '{n} halaman',
  '{n} pages': '{n} halaman',

  // ---------------- zones & stages ----------------
  'Red': 'Merah',
  'Yellow': 'Kuning',
  'Green': 'Hijau',
  'Critical': 'Kritikal',
  'Urgent': 'Segera',
  'Non-urgent': 'Tidak segera',
  '{zone} zone': 'Zon {zone}',
  '{zone} Zone · Level {level}': 'Zon {zone} · Tahap {level}',
  'Registration': 'Pendaftaran',
  'Triage': 'Triaj',
  'Doctor consultation': 'Konsultasi doktor',
  'Discharge / admission decision': 'Keputusan discaj / kemasukan wad',
  'Blood test': 'Ujian darah',
  'X-ray': 'X-ray',
  'CT scan': 'Imbasan CT',
  'ECG': 'ECG',
  'Ultrasound': 'Ultrabunyi',
  '{name} completed': '{name} selesai',
  '{name} in progress': '{name} sedang berjalan',
  '{name} pending': '{name} belum bermula',
  'Waiting for {name}': 'Menunggu {name}',
  'Start {name}': 'Mulakan {name}',
  'Mark {name} completed': 'Tandakan {name} selesai',
  'Done': 'Selesai',
  'In progress': 'Sedang berjalan',
  'Waiting': 'Menunggu',
  'Visit completed': 'Lawatan selesai',
  'Discharged home': 'Discaj pulang ke rumah',
  'Admitted to ward': 'Dimasukkan ke wad',
  'Transferred to another facility': 'Dipindahkan ke fasiliti lain',

  // ---------------- patient-app triage values ----------------
  'Not specified': 'Tidak dinyatakan',
  'Mild': 'Ringan',
  'Moderate': 'Sederhana',
  'Severe': 'Teruk',
  'Less than 24 hours': 'Kurang daripada 24 jam',
  '1–3 days': '1–3 hari',
  'Cough': 'Batuk',
  'Chest pain': 'Sakit dada',
  'Abdominal pain': 'Sakit perut',
  'Minor injury': 'Kecederaan ringan',
  'Other': 'Lain-lain',

  // ---------------- sample / common clinical data ----------------
  'Wheezing and shortness of breath': 'Berdehit dan sesak nafas',
  'Sprained ankle': 'Buku lali terseliuh',
  'Fever for 3 days': 'Demam selama 3 hari',
  'Fever': 'Demam',
  'Headache': 'Sakit kepala',
  'Vomiting': 'Muntah',
  'Hypertension': 'Darah tinggi',
  'Diabetes': 'Kencing manis',
  'Asthma': 'Asma',
  'Penicillin': 'Penisilin',
  'None': 'Tiada',

  // ---------------- activity log (fixed sentences) ----------------
  'Progress tracking link enabled': 'Pautan penjejakan kemajuan diaktifkan',
  'Progress tracking link disabled':
      'Pautan penjejakan kemajuan dinyahaktifkan',
  'Progress tracking link replaced (old link revoked)':
      'Pautan penjejakan kemajuan diganti (pautan lama dibatalkan)',

  // ---------------- landing ----------------
  'Hospital staff portal': 'Portal kakitangan hospital',
  'Log each stage of a patient\'s emergency visit so patients and families always know what happens next.': 'Rekod setiap peringkat lawatan kecemasan pesakit supaya pesakit dan keluarga sentiasa tahu apa yang berlaku seterusnya.',
  'Live emergency queue': 'Giliran kecemasan secara langsung',
  'See every patient, their zone and current stage.':
      'Lihat setiap pesakit, zon dan peringkat semasa mereka.',
  'One-tap progress logging': 'Rekod kemajuan dengan satu ketikan',
  'Start and complete each stage in seconds.':
      'Mula dan selesaikan setiap peringkat dalam beberapa saat.',
  'Family updates': 'Makluman untuk keluarga',
  'Authorised family can follow the visit in the app.':
      'Keluarga yang dibenarkan boleh mengikuti lawatan dalam aplikasi.',
  'Staff login': 'Log masuk kakitangan',
  'Not hospital staff? ': 'Bukan kakitangan hospital? ',
  'Open the patient app': 'Buka aplikasi pesakit',

  // ---------------- login ----------------
  'Sign in to update patient progress.':
      'Log masuk untuk mengemas kini kemajuan pesakit.',
  'Select hospital': 'Pilih hospital',
  'Password': 'Kata laluan',
  'e.g. N-1021': 'cth. N-1021',
  'e.g. 000101-00-0000': 'cth. 000101-00-0000',
  'e.g. 0123456789': 'cth. 0123456789',
  'Enter your password': 'Masukkan kata laluan anda',
  'Log in': 'Log masuk',
  'Prototype: any staff ID and password will work.':
      'Prototaip: sebarang ID kakitangan dan kata laluan boleh digunakan.',
  'Please enter your staff ID and password.':
      'Sila masukkan ID kakitangan dan kata laluan anda.',
  'Sign in failed. Check your staff ID and password.':
      'Log masuk gagal. Semak ID kakitangan dan kata laluan anda.',

  // ---------------- queue ----------------
  'New patient': 'Pesakit baharu',
  'In queue': 'Dalam giliran',
  'Completed': 'Selesai',
  'Search queue no. or name': 'Cari no. giliran atau nama',
  'Active': 'Aktif',
  'No patients found': 'Tiada pesakit dijumpai',
  'Try another filter or register a new patient.':
      'Cuba penapis lain atau daftar pesakit baharu.',
  'Updated {ago}': 'Dikemas kini {ago}',

  // ---------------- register ----------------
  'Please enter the patient\'s name, age and main complaint.':
      'Sila masukkan nama, umur dan aduan utama pesakit.',
  'Please enter the patient\'s phone number, e.g. 0123456789.':
      'Sila masukkan nombor telefon pesakit, cth. 0123456789.',
  'Could not register the patient. Please try again.':
      'Pesakit tidak dapat didaftarkan. Sila cuba lagi.',
  '{queue} registered.': '{queue} didaftarkan.',
  'Register patient': 'Daftar pesakit',
  'For walk-ins. Patients who used the TriageMY app appear under Incoming in the queue, with their details already filled in.': 'Untuk pesakit walk-in. Pesakit yang menggunakan aplikasi TriageMY dipaparkan di bawah Akan Tiba dalam giliran, dengan butiran mereka sudah diisi.',
  'Patient details': 'Butiran pesakit',
  'Full name': 'Nama penuh',
  'Patient name': 'Nama pesakit',
  'IC / ID number (optional)': 'No. KP / ID (pilihan)',
  'Age': 'Umur',
  'Years': 'Tahun',
  'Sex': 'Jantina',
  'Main complaint': 'Aduan utama',
  'e.g. Chest pain': 'cth. Sakit dada',
  'Triage zone': 'Zon triaj',
  'Can be changed later after nurse triage.':
      'Boleh ditukar kemudian selepas triaj jururawat.',
  'Tests required': 'Ujian diperlukan',
  'Optional. More can be added during the visit.':
      'Pilihan. Ujian lain boleh ditambah semasa lawatan.',
  'Patient phone number': 'Nombor telefon pesakit',
  'Required. The live tracking link is sent to this number.':
      'Wajib. Pautan penjejakan langsung dihantar ke nombor ini.',
  'Registering...': 'Mendaftar...',
  'Register & start queue': 'Daftar & mula giliran',

  // ---------------- account ----------------
  'Demo mode: sample data only. Nothing is saved and everything resets when the app restarts.': 'Mod demo: data contoh sahaja. Tiada apa yang disimpan dan semuanya ditetapkan semula apabila aplikasi dimulakan semula.',
  'Connected to Supabase. Every update you make is saved with your name and staff ID.': 'Disambungkan ke Supabase. Setiap kemas kini anda disimpan bersama nama dan ID kakitangan anda.',
  'Log out': 'Log keluar',

  // ---------------- patient detail ----------------
  'Visit completed: {outcome}.': 'Lawatan selesai: {outcome}.',
  'Update after nurse assessment.': 'Kemas kini selepas penilaian jururawat.',
  'Add a test': 'Tambah ujian',
  'It is added before the doctor consultation.':
      'Ia ditambah sebelum konsultasi doktor.',
  'All available tests are already added.':
      'Semua ujian yang ada telah ditambah.',
  'Follow the live progress of your hospital visit at {hospital}: {link}\n\nYou can forward this link to your family so they can follow too.': 'Ikuti kemajuan langsung lawatan hospital anda di {hospital}: {link}\n\nAnda boleh kongsi pautan ini dengan keluarga supaya mereka juga boleh mengikutinya.',
  'Could not open WhatsApp.': 'Tidak dapat membuka WhatsApp.',
  'Queue No.': 'No. Giliran',
  'Arrived {time}': 'Tiba {time}',
  'Allergy: {x}': 'Alahan: {x}',
  'Blood type {x}': 'Jenis darah {x}',
  'Medication: {x}': 'Ubat: {x}',
  'Triage report (patient app)': 'Laporan triaj (aplikasi pesakit)',
  'Submitted {ago}': 'Dihantar {ago}',
  'Outcome': 'Keputusan',
  'Main symptom': 'Simptom utama',
  'Severity': 'Tahap keterukan',
  'Duration': 'Tempoh',
  'Danger signs': 'Tanda bahaya',
  'None reported': 'Tiada dilaporkan',
  'All stages are done.': 'Semua peringkat telah selesai.',
  'Current stage': 'Peringkat semasa',
  'Scan results document': 'Imbas dokumen keputusan',
  'Scan another document ({n} uploaded)':
      'Imbas dokumen lain ({n} dimuat naik)',
  'Undid: {x}.': 'Dibatalkan: {x}.',
  'Undo last update ({x})': 'Batal kemas kini terakhir ({x})',
  'Progress timeline': 'Garis masa kemajuan',
  'Add test': 'Tambah ujian',
  'Tap a stage to edit it. Drag unfinished tests to reorder them. Patients see this timeline live.': 'Ketik peringkat untuk menyuntingnya. Seret ujian yang belum selesai untuk menyusun semula. Pesakit melihat garis masa ini secara langsung.',
  'Started {time}': 'Bermula {time}',
  '{n} result document': '{n} dokumen keputusan',
  '{n} result documents': '{n} dokumen keputusan',
  'Progress tracking link': 'Pautan penjejakan kemajuan',
  'Link is active': 'Pautan aktif',
  'Not shared': 'Tidak dikongsi',
  'Link copied.': 'Pautan disalin.',
  'Send via WhatsApp': 'Hantar melalui WhatsApp',
  'Send to patient ({phone})': 'Hantar kepada pesakit ({phone})',
  'Shows live progress only (stages and times). No name, IC or medical details. The link stops working 2 hours after the visit ends.': 'Hanya menunjukkan kemajuan langsung (peringkat dan masa). Tiada nama, No. KP atau butiran perubatan. Pautan tamat 2 jam selepas lawatan berakhir.',
  'New link created. The old link no longer works.':
      'Pautan baharu dicipta. Pautan lama tidak lagi berfungsi.',
  'Revoke and create a new link': 'Batalkan dan cipta pautan baharu',
  'Activity log': 'Log aktiviti',
  'Who updated what, and when.': 'Siapa mengemas kini apa, dan bila.',
  'No activity yet.': 'Belum ada aktiviti.',
  '{x} (undone)': '{x} (dibatalkan)',
  'by {x}': 'oleh {x}',
  'Choose the final outcome of this visit.':
      'Pilih keputusan akhir lawatan ini.',
  'The test name cannot be empty.': 'Nama ujian tidak boleh kosong.',
  'Test name': 'Nama ujian',
  'e.g. Chest X-ray': 'cth. X-ray dada',
  'Status': 'Status',
  'Changes are logged with your staff ID and can be undone.':
      'Perubahan direkodkan dengan ID kakitangan anda dan boleh dibatalkan.',
  'Result documents': 'Dokumen keputusan',
  'No documents uploaded yet.': 'Belum ada dokumen dimuat naik.',
  'Start the test before uploading results.':
      'Mulakan ujian sebelum memuat naik keputusan.',
  'Note (optional)': 'Nota (pilihan)',
  'e.g. Patient moved to Radiology, Level 1':
      'cth. Pesakit dipindahkan ke Radiologi, Aras 1',
  'Save changes': 'Simpan perubahan',
  'Remove this test': 'Buang ujian ini',

  // ---------------- scan results ----------------
  'Could not open the scanner. Using the camera instead.':
      'Tidak dapat membuka pengimbas. Menggunakan kamera.',
  'Could not open the camera. Try "Choose from gallery" instead.':
      'Tidak dapat membuka kamera. Cuba "Pilih dari galeri".',
  '{name} result uploaded.': 'Keputusan {name} dimuat naik.',
  'Upload failed. Check the connection and try again. Your scanned pages are still here.': 'Muat naik gagal. Semak sambungan dan cuba lagi. Halaman yang diimbas masih ada di sini.',
  'Scan results': 'Imbas keputusan',
  'Place the document flat in good light. The scanner finds the page edges and straightens it. You can scan several pages in one go.': 'Letakkan dokumen rata dalam cahaya yang baik. Pengimbas akan mengesan tepi halaman dan meluruskannya. Anda boleh mengimbas beberapa halaman sekali gus.',
  'Place the document flat in good light. Add one photo per page.': 'Letakkan dokumen rata dalam cahaya yang baik. Tambah satu foto bagi setiap halaman.',
  'No pages yet': 'Belum ada halaman',
  'Scan first page': 'Imbas halaman pertama',
  'Scan another page': 'Imbas halaman lain',
  'Choose from gallery': 'Pilih dari galeri',
  'The name on the document matches {name}.':
      'Nama pada dokumen sepadan dengan {name}.',
  'Uploading...': 'Memuat naik...',
  'Upload as PDF ({pages})': 'Muat naik sebagai PDF ({pages})',
  'Patient and doctors can open it once uploaded.':
      'Pesakit dan doktor boleh membukanya selepas dimuat naik.',
  'Page {n}': 'Halaman {n}',
  'Could not load this document.': 'Tidak dapat memuatkan dokumen ini.',
};

// ============================================================
// STORED DATA  (log entries, complaints, conditions...)
// ============================================================

/// Translates text that is *stored* in English (activity log entries,
/// complaints, conditions, staff names...) for display only.
/// Tries an exact match, then the known log sentence patterns, then each
/// part of a "a · b" or "a, b" value. Unknown text is shown as it is.
String trText(String s) {
  if (adminLang.value == AdminLang.en || s.trim().isEmpty) return s;

  final exact = _ms[s];
  if (exact != null) return exact;

  for (final (pattern, build) in _logPatterns) {
    final m = pattern.firstMatch(s);
    if (m != null) return build(m);
  }

  for (final sep in const [' · ', ', ']) {
    if (s.contains(sep)) return s.split(sep).map(trText).join(sep);
  }

  // "moderate" -> "Moderate" -> "Sederhana" -> "sederhana"
  final cap = s[0].toUpperCase() + s.substring(1);
  final capped = _ms[cap];
  if (capped != null) return capped[0].toLowerCase() + capped.substring(1);

  return s;
}

/// Log sentences written by AdminStore, in Bahasa Melayu.
final List<(RegExp, String Function(Match))> _logPatterns = [
  (RegExp(r'^Undid: (.+)$'), (m) => 'Dibatalkan: ${trText(m[1]!)}'),
  (
    RegExp(r'^Triage zone set to (\w+) \((.+)\)$'),
    (m) => 'Zon triaj ditetapkan kepada ${trText(m[1]!)} (${trText(m[2]!)})',
  ),
  (
    RegExp(r'^(.+) result uploaded \((\d+) pages?\)$'),
    (m) => 'Keputusan ${trText(m[1]!)} dimuat naik (${m[2]} halaman)',
  ),
  (
    RegExp(r'^(.+) set back to waiting$'),
    (m) => '${trText(m[1]!)} dikembalikan kepada menunggu',
  ),
  (
    RegExp(r'^(.+) added to the visit$'),
    (m) => '${trText(m[1]!)} ditambah ke lawatan',
  ),
  (
    RegExp(r'^(.+) removed from the visit$'),
    (m) => '${trText(m[1]!)} dibuang daripada lawatan',
  ),
  (
    RegExp(r'^(.+) renamed to (.+)$'),
    (m) => '${trText(m[1]!)} dinamakan semula kepada ${m[2]}',
  ),
  (
    RegExp(r'^(.+) moved before (.+)$'),
    (m) => '${trText(m[1]!)} dipindahkan sebelum ${trText(m[2]!)}',
  ),
  (
    RegExp(r'^(.+) moved after (.+)$'),
    (m) => '${trText(m[1]!)} dipindahkan selepas ${trText(m[2]!)}',
  ),
  (RegExp(r'^(.+) started$'), (m) => '${trText(m[1]!)} dimulakan'),
  (RegExp(r'^(.+) completed$'), (m) => '${trText(m[1]!)} selesai'),
  (RegExp(r'^Staff (\S+)$'), (m) => 'Kakitangan ${m[1]}'),
];
