import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalsPage extends StatefulWidget {
  const HospitalsPage({super.key});

  @override
  State<HospitalsPage> createState() => _HospitalsPageState();
}

class _HospitalsPageState extends State<HospitalsPage> {
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color border = Color(0xFFE3ECEC);

  final TextEditingController searchController = TextEditingController();

  // Fallback location while waiting for actual location.
  LatLng currentLocation = const LatLng(
    3.1390,
    101.6869,
  );

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

      serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          locationLoaded = true;
        });
        return;
      }

      permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        setState(() {
          locationLoaded = true;
        });
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        currentLocation = LatLng(
          position.latitude,
          position.longitude,
        );

        locationLoaded = true;
      });
    } catch (e) {
      setState(() {
        locationLoaded = true;
      });
    }
  }

  Future<void> _openGoogleMaps(
    String hospitalName,
  ) async {
    final String query =
        Uri.encodeComponent(hospitalName);

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openWaze(
    String hospitalName,
  ) async {
    final String query =
        Uri.encodeComponent(hospitalName);

    final Uri url = Uri.parse(
      'https://waze.com/ul?q=$query&navigate=yes',
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  void _showDirections(
    BuildContext context,
    String hospitalName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),

      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            30,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,

                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFD7E1E1),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Open directions with',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkTeal,
                ),
              ),

              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,

                leading: const CircleAvatar(
                  backgroundColor: lightTeal,
                  child: Icon(
                    Icons.map_outlined,
                    color: darkTeal,
                  ),
                ),

                title: const Text(
                  'Google Maps',
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),

                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: grey,
                ),

                onTap: () {
                  Navigator.pop(context);

                  _openGoogleMaps(
                    hospitalName,
                  );
                },
              ),

              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,

                leading: const CircleAvatar(
                  backgroundColor: lightTeal,
                  child: Icon(
                    Icons.navigation_outlined,
                    color: darkTeal,
                  ),
                ),

                title: const Text(
                  'Waze',
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),

                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: grey,
                ),

                onTap: () {
                  Navigator.pop(context);

                  _openWaze(
                    hospitalName,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            30,
          ),

          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 600,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  // BRAND
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 23,
                            fontWeight:
                                FontWeight.w700,
                          ),

                          children: [
                            TextSpan(
                              text: 'Triage',
                              style: TextStyle(
                                color: darkTeal,
                              ),
                            ),

                            TextSpan(
                              text: 'MY',
                              style: TextStyle(
                                color: teal,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 42,
                        height: 42,

                        decoration:
                            const BoxDecoration(
                          color: lightTeal,
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons
                              .notifications_none_rounded,
                          color: darkTeal,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 34),

                  // TITLE
                  const Text(
                    'Hospitals & Clinics',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 28,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: -0.6,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Browse nearby care options.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SEARCH BAR
                  TextField(
                    controller:
                        searchController,

                    decoration:
                        InputDecoration(
                      hintText:
                          'Search hospital or clinic',

                      hintStyle:
                          const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 14,
                        color:
                            Color(0xFFA5B2B2),
                      ),

                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,
                        color: grey,
                      ),

                      filled: true,
                      fillColor: Colors.white,

                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(16),

                        borderSide:
                            const BorderSide(
                          color: border,
                        ),
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(16),

                        borderSide:
                            const BorderSide(
                          color: border,
                        ),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(16),

                        borderSide:
                            const BorderSide(
                          color: teal,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // LOCATION INFO
                  Container(
                    width: double.infinity,

                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),

                    decoration: BoxDecoration(
                      color: lightTeal,
                      borderRadius:
                          BorderRadius
                              .circular(14),
                    ),

                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .location_on_outlined,
                          color: darkTeal,
                          size: 19,
                        ),

                        const SizedBox(
                            width: 8),

                        Expanded(
                          child: Text(
                            locationLoaded
                                ? 'Showing hospitals and clinics near your location.'
                                : 'Getting your current location...',

                            style:
                                const TextStyle(
                              fontFamily:
                                  'Helvetica',
                              fontSize: 12,
                              color: darkTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // MAP
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(18),

                    child: SizedBox(
                      width: double.infinity,
                      height: 230,

                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter:
                              currentLocation,
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
                                point:
                                    currentLocation,
                                width: 45,
                                height: 45,

                                child: Container(
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.white,
                                    shape: BoxShape
                                        .circle,
                                    border:
                                        Border.all(
                                      color: teal,
                                      width: 2,
                                    ),
                                  ),

                                  child:
                                      const Icon(
                                    Icons
                                        .my_location_rounded,
                                    color: teal,
                                    size: 23,
                                  ),
                                ),
                              ),

                              // HOSPITAL 1
                              Marker(
                                point:
                                    hospital1,
                                width: 42,
                                height: 42,

                                child:
                                    _mapMarker(
                                  Icons
                                      .local_hospital_rounded,
                                ),
                              ),

                              // HOSPITAL 2
                              Marker(
                                point:
                                    hospital2,
                                width: 42,
                                height: 42,

                                child:
                                    _mapMarker(
                                  Icons
                                      .local_hospital_rounded,
                                ),
                              ),

                              // CLINIC
                              Marker(
                                point: clinic1,
                                width: 42,
                                height: 42,

                                child:
                                    _mapMarker(
                                  Icons
                                      .medical_services_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Nearby care',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _hospitalCard(
                    context: context,
                    name:
                        'Central General Hospital',
                    type:
                        'General Hospital',
                    distance: '2.3 km',
                    travelTime: '8 min',
                    status: 'Open 24/7',
                    address:
                        '123 Health Avenue',
                  ),

                  const SizedBox(height: 14),

                  _hospitalCard(
                    context: context,
                    name:
                        'Riverside Medical Centre',
                    type:
                        'Private Hospital',
                    distance: '5.1 km',
                    travelTime: '15 min',
                    status: 'Open Now',
                    address:
                        '88 Riverdale Road',
                  ),

                  const SizedBox(height: 14),

                  _hospitalCard(
                    context: context,
                    name:
                        'Maple Community Clinic',
                    type: 'Clinic',
                    distance: '1.2 km',
                    travelTime: '5 min',
                    status: 'Open Now',
                    address: '45 Maple Road',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapMarker(
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: darkTeal,
        shape: BoxShape.circle,

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.12),
            blurRadius: 5,
          ),
        ],
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 21,
      ),
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

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width: 46,
                height: 46,

                decoration:
                    const BoxDecoration(
                  color: lightTeal,
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons
                      .local_hospital_outlined,
                  color: darkTeal,
                  size: 23,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      name,

                      style:
                          const TextStyle(
                        fontFamily:
                            'Helvetica',
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                        color: darkTeal,
                      ),
                    ),

                    const SizedBox(
                        height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .location_on_outlined,
                          size: 15,
                          color: grey,
                        ),

                        const SizedBox(
                            width: 4),

                        Text(
                          '$distance away',
                          style:
                              const TextStyle(
                            fontFamily:
                                'Helvetica',
                            fontSize: 12,
                            color: grey,
                          ),
                        ),

                        const SizedBox(
                            width: 8),

                        const Text(
                          '•',
                          style:
                              TextStyle(
                            color: grey,
                          ),
                        ),

                        const SizedBox(
                            width: 8),

                        Text(
                          travelTime,

                          style:
                              const TextStyle(
                            fontFamily:
                                'Helvetica',
                            fontSize: 12,
                            color: grey,
                          ),
                        ),
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
              _smallTag(
                icon:
                    Icons.apartment_rounded,
                text: type,
              ),

              _smallTag(
                icon:
                    Icons.schedule_rounded,
                text: status,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 17,
                color: grey,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  address,

                  style:
                      const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 12,
                    color: grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // DIRECTIONS ONLY
          SizedBox(
            width: double.infinity,
            height: 48,

            child:
                ElevatedButton.icon(
              onPressed: () {
                _showDirections(
                  context,
                  name,
                );
              },

              icon: const Icon(
                Icons
                    .navigation_outlined,
                size: 18,
              ),

              label: const Text(
                'Directions',

                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor: teal,
                foregroundColor:
                    Colors.white,
                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                          13),
                ),
              ),
            ),
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color:
            const Color(0xFFF3F7F7),

        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 15,
            color: darkTeal,
          ),

          const SizedBox(width: 5),

          Text(
            text,

            style:
                const TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 11,
              color: darkTeal,
            ),
          ),
        ],
      ),
    );
  }
}