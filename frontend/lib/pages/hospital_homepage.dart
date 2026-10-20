import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../widgets/hospital_option_card.dart';

class HospitalsPage extends StatefulWidget {
  const HospitalsPage({super.key});

  @override
  State<HospitalsPage> createState() => _HospitalsPageState();
}

class _HospitalsPageState extends State<HospitalsPage> {
  /// More than the post-triage page, so search has something to filter.
  static const int _hospitalCount = 10;

  final TextEditingController searchController = TextEditingController();

  // Fallback location while waiting for actual location.
  LatLng currentLocation = const LatLng(3.1390, 101.6869);

  bool locationLoaded = false;
  bool hasGps = false;

  // Ranked by the backend (travel time, ED busyness and any triage from the last 24 h).
  HospitalRecommendations? recommendations;
  bool loadingHospitals = true;
  String? hospitalError;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
    _getCurrentLocation();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        if (position != null) {
          currentLocation = LatLng(position.latitude, position.longitude);
          hasGps = true;
        }
        locationLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        locationLoaded = true;
      });
    }
    await _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      loadingHospitals = true;
      hospitalError = null;
    });
    try {
      final result = await HospitalService.fetchRecommendations(
        currentLocation.latitude,
        currentLocation.longitude,
        limit: _hospitalCount,
      );
      if (!mounted) return;
      setState(() {
        recommendations = result;
        loadingHospitals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingHospitals = false;
        hospitalError = 'Could not load nearby hospitals. Please try again.';
      });
    }
  }

  /// Ranked hospitals matching the search box (name or address).
  List<HospitalOption> get _visibleHospitals {
    final hospitals = recommendations?.hospitals ?? const <HospitalOption>[];
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return hospitals;
    return hospitals
        .where(
          (h) =>
              h.name.toLowerCase().contains(query) ||
              h.address.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final hospitals = _visibleHospitals;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BRAND
                    FadeSlideIn(
                      index: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const BrandWordmark(),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: cardDecoration(radius: 14),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textDark,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // TITLE
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'Hospitals & Clinics',
                            style: AppText.display,
                          ),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'Nearby emergency departments, ranked by travel time and how busy they are.',
                            style: AppText.body,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // SEARCH BAR
                    FadeSlideIn(
                      index: 2,
                      child: TextField(
                        controller: searchController,
                        style: AppText.input,
                        decoration: InputDecoration(
                          hintText: tr('Search hospital or clinic'),
                          hintStyle: AppText.style(
                            14,
                            FontWeight.w400,
                            const Color(0xFFA5B2B2),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 17,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // LOCATION INFO
                    FadeSlideIn(
                      index: 3,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              locationLoaded
                                  ? Icons.location_on_rounded
                                  : Icons.location_searching_rounded,
                              color: AppColors.teal,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: LocalizedText(
                                !locationLoaded
                                    ? 'Getting your current location...'
                                    : hasGps
                                    ? 'Showing hospitals near your location.'
                                    : 'Location unavailable. Showing hospitals near Kuala Lumpur.',
                                style: AppText.style(
                                  12,
                                  FontWeight.w600,
                                  AppColors.darkTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // MAP
                    FadeSlideIn(
                      index: 4,
                      child: Container(
                        decoration: cardDecoration(radius: 26),
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: SizedBox(
                            width: double.infinity,
                            height: 230,
                            child: FlutterMap(
                              key: ValueKey(currentLocation),
                              options: MapOptions(
                                initialCenter: currentLocation,
                                initialZoom: 12.5,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.triagemy',
                                ),
                                MarkerLayer(
                                  markers: [
                                    // USER
                                    Marker(
                                      point: currentLocation,
                                      width: 45,
                                      height: 45,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.teal,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.my_location_rounded,
                                          color: AppColors.teal,
                                          size: 23,
                                        ),
                                      ),
                                    ),

                                    for (final h in hospitals)
                                      Marker(
                                        point: LatLng(h.latitude, h.longitude),
                                        width: 42,
                                        height: 42,
                                        child: Tooltip(
                                          message: h.name,
                                          child: _mapMarker(
                                            Icons.local_hospital_rounded,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    LocalizedText('Nearby care', style: AppText.heading),

                    if (recommendations != null) ...[
                      const SizedBox(height: 4),
                      LocalizedText(
                        hospitalRankingCaption(recommendations!),
                        style: AppText.caption,
                      ),
                    ],

                    const SizedBox(height: 14),

                    if (loadingHospitals)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (hospitalError != null)
                      _statusMessage(
                        hospitalError!,
                        action: PrimaryButton(
                          label: 'Try again',
                          icon: Icons.refresh_rounded,
                          onPressed: _loadHospitals,
                        ),
                      )
                    else if (hospitals.isEmpty)
                      _statusMessage(
                        searchController.text.trim().isEmpty
                            ? 'No hospitals found near you.'
                            : 'No nearby hospital matches your search.',
                      )
                    else
                      for (final (i, h) in hospitals.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FadeSlideIn(
                            index: 5 + i,
                            child: HospitalOptionCard(hospital: h),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapMarker(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkTeal,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _statusMessage(String message, {Widget? action}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          LocalizedText(
            message,
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    );
  }
}
