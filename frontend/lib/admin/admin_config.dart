/// Build-time settings for the hospital side.
///
/// Pass them when running, so no keys are stored in the code:
///
///   flutter run -t lib/main_admin.dart -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
///
/// Without them the app runs in DEMO mode (sample data, nothing is saved).
/// Only ever use the public "anon" key here, never the service_role key.
class AdminConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Where the progress tracking page is hosted.
  static const String shareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://track.triagemy.my',
  );

  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String shareLink(String token) => '$shareBaseUrl/t/$token';
}