/// Optional tracking-site settings. Clinical data uses the authenticated backend
/// API by default; Flutter does not need Supabase credentials or demo flags.
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
