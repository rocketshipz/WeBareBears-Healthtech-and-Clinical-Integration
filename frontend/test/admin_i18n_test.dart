import 'package:flutter_test/flutter_test.dart';
import 'package:triagemy/admin/admin_i18n.dart';

void main() {
  test('stored English data is shown in Bahasa Melayu', () {
    adminLang.value = AdminLang.ms;

    expect(trText('Progress tracking link disabled'),
        'Pautan penjejakan kemajuan dinyahaktifkan');
    expect(trText('Doctor consultation started'), 'Konsultasi doktor dimulakan');
    expect(trText('Blood test completed'), 'Ujian darah selesai');
    expect(trText('Registration completed'), 'Pendaftaran selesai');
    expect(trText('Staff 123'), 'Kakitangan 123');
    expect(trText('Male'), 'Lelaki');
    expect(trText('Chest pain'), 'Sakit dada');
    expect(trText('Emergency Department'), 'Jabatan Kecemasan');
    expect(trText('Hypertension'), 'Darah tinggi');
    expect(trText('Wheezing and shortness of breath'), 'Berdehit dan sesak nafas');
    expect(trText('Cough · moderate'), 'Batuk · sederhana');
    expect(trText('X-ray moved before Blood test'),
        'X-ray dipindahkan sebelum Ujian darah');
    expect(trText('Undid: Triage completed'), 'Dibatalkan: Triaj selesai');
    expect(trText('Triage zone set to Red (Critical)'),
        'Zon triaj ditetapkan kepada Merah (Kritikal)');
    expect(trText('Blood test result uploaded (2 pages)'),
        'Keputusan Ujian darah dimuat naik (2 halaman)');
    expect(trText('Something unknown'), 'Something unknown');

    adminLang.value = AdminLang.en;
    expect(trText('Blood test completed'), 'Blood test completed');
  });
}
