import '../localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

class HospitalsPage extends StatefulWidget {
  const HospitalsPage({super.key});

  @override
  State<HospitalsPage> createState() => _HospitalsPageState();
}

class _HospitalsPageState extends State<HospitalsPage> {
  final TextEditingController searchController = TextEditingController();

  // Fallback location while waiting for actual location.
  LatLng currentLocation = const LatLng(3.1390, 101.6869);

  bool locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          locationLoaded = true;
        });
        return;
      }

      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          locationLoaded = true;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        locationLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        locationLoaded = true;
      });
    }
  }

  Future<void> _openGoogleMaps(String hospitalName) async {
    final String query = Uri.encodeComponent(hospitalName);

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWaze(String hospitalName) async {
    final String query = Uri.encodeComponent(hospitalName);

    final Uri url = Uri.parse(
      'https://waze.com/ul?q=$query&navigate=yes',
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _showDirections(BuildContext context, String hospitalName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              LocalizedText('Open directions with', style: AppText.heading),
              const SizedBox(height: 4),
              LocalizedText(hospitalName, style: AppText.caption),
              const SizedBox(height: 14),
              _routeTile(
                icon: Icons.map_outlined,
                title: 'Google Maps',
                onTap: () {
                  Navigator.pop(context);
                  _openGoogleMaps(hospitalName);
                },
              ),
              const SizedBox(height: 10),
              _routeTile(
                icon: Icons.navigation_outlined,
                title: 'Waze',
                onTap: () {
                  Navigator.pop(context);
                  _openWaze(hospitalName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _routeTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.paleTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.darkTeal, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: LocalizedText(title, style: AppText.bodyStrong)),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    // Sample nearby locations for the prototype.
    final LatLng hospital1 = LatLng(
      currentLocation.latitude + 0.008,
      currentLocation.longitude + 0.004,
    );

    final LatLng hospital2 = LatLng(
      currentLocation.latitude - 0.006,
      currentLocation.longitude + 0.007,
    );

    final LatLng clinic1 = LatLng(
      currentLocation.latitude + 0.003,
      currentLocation.longitude - 0.008,
    );

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
                          LocalizedText('Hospitals & Clinics', style: AppText.display),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'Browse nearby care options.',
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
                                locationLoaded
                                    ? 'Showing hospitals and clinics near your location.'
                                    : 'Getting your current location...',
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
                              options: MapOptions(
                                initialCenter: currentLocation,
                                initialZoom: 13.5,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.triagemy',
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

                                    // HOSPITAL 1
                                    Marker(
                                      point: hospital1,
                                      width: 42,
                                      height: 42,
                                      child: _mapMarker(
                                        Icons.local_hospital_rounded,
                                      ),
                                    ),

                                    // HOSPITAL 2
                                    Marker(
                                      point: hospital2,
                                      width: 42,
                                      height: 42,
                                      child: _mapMarker(
                                        Icons.local_hospital_rounded,
                                      ),
                                    ),

                                    // CLINIC
                                    Marker(
                                      point: clinic1,
                                      width: 42,
                                      height: 42,
                                      child: _mapMarker(
                                        Icons.medical_services_rounded,
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

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 5,
                      child: _hospitalCard(
                        context: context,
                        name: 'Central General Hospital',
                        type: 'General Hospital',
                        distance: '2.3 km',
                        travelTime: '8 min',
                        status: 'Open 24/7',
                        address: '123 Health Avenue',
                      ),
                    ),

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 6,
                      child: _hospitalCard(
                        context: context,
                        name: 'Riverside Medical Centre',
                        type: 'Private Hospital',
                        distance: '5.1 km',
                        travelTime: '15 min',
                        status: 'Open Now',
                        address: '88 Riverdale Road',
                      ),
                    ),

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 7,
                      child: _hospitalCard(
                        context: context,
                        name: 'Maple Community Clinic',
                        type: 'Clinic',
                        distance: '1.2 km',
                        travelTime: '5 min',
                        status: 'Open Now',
                        address: '45 Maple Road',
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _hospitalCard({
    required BuildContext context,
    required String name,
    required String type,
    required String distance,
    required String travelTime,
    required String status,
    required String address,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.paleTeal,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.local_hospital_outlined,
                  color: AppColors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(name, style: AppText.heading),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.grey,
                        ),
                        const SizedBox(width: 4),
                        LocalizedText('$distance away', style: AppText.caption),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        LocalizedText(travelTime, style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallTag(icon: Icons.apartment_rounded, text: type),
              _smallTag(icon: Icons.schedule_rounded, text: status),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 17,
                color: AppColors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(child: LocalizedText(address, style: AppText.caption)),
            ],
          ),

          const SizedBox(height: 16),

          // DIRECTIONS ONLY
          PrimaryButton(
            label: 'Directions',
            icon: Icons.navigation_outlined,
            onPressed: () {
              _showDirections(context, name);
            },
          ),
        ],
      ),
    );
  }

  Widget _smallTag({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.darkTeal),
          const SizedBox(width: 5),
          LocalizedText(
            text,
            style: AppText.style(12, FontWeight.w600, AppColors.darkTeal),
          ),
        ],
      ),
    );
  }
}