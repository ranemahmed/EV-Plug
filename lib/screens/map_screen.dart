import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MapScreen extends StatefulWidget {
  final bool showNearby;

  const MapScreen({super.key, this.showNearby = false});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String googleApiKey =
      'Insert Your API key Here'; // api key

  GoogleMapController? mapController;
  final LatLng _initialPosition = const LatLng(30.0444, 31.2357);

  String? selectedChargerType;
  final TextEditingController searchController = TextEditingController();
  List<String> userChargerTypes = [];
  bool filterNearby = false;

  final List<String> chargerTypes = ['GB/T', 'Type 2', 'CCS 2', 'CHAdeMO'];

  List<Marker> stationMarkers = [];
  bool isLoading = false;
  String? errorMessage;
  bool isChargerTypeLoading = true;

  @override
  void initState() {
    super.initState();

    filterNearby = widget.showNearby;
    _checkConnectivity();

    _setupMap();
    fetchUserChargerType();

    if (widget.showNearby) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showFilters(context);
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (result != ConnectivityResult.wifi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ You are not connected to Wi-Fi.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> fetchUserChargerType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data != null && data['cars'] != null && data['cars'] is List) {
        final cars = data['cars'] as List<dynamic>;
        userChargerTypes =
            cars.map((car) => car['charger_type']?.toString() ?? '').toList();
        if (userChargerTypes.isNotEmpty) {
          final match = chargerTypes.firstWhere(
            (type) =>
                type.toLowerCase().trim() ==
                userChargerTypes.first.toLowerCase().trim(),
            orElse: () => '',
          );

          if (match.isNotEmpty) {
            setState(() {
              selectedChargerType = match;
            });
          } else {
            setState(() {
              selectedChargerType = null; // fallback
            });
          }
        }
      }
    }
    setState(() {
      isChargerTypeLoading = false;
    });
  }

  Future<void> _setupMap() async {
    await _checkLocationPermission();
    await fetchNearbyStations();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;
  }

  Future<void> fetchNearbyStations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final userPosition = await Geolocator.getCurrentPosition();
      final snapshot =
          await FirebaseFirestore.instance.collection('stations').get();

      final allStations =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

      List<Map<String, dynamic>> filteredStations = [];
      if (selectedChargerType != null && selectedChargerType!.isNotEmpty) {
        allStations.removeWhere(
          (station) =>
              station['plug_type']?.toString().toLowerCase().trim() !=
              selectedChargerType!.toLowerCase().trim(),
        );
      }

      if (filterNearby) {
        // Apply Google Distance Matrix filtering Only if nearby filter is on
        for (int i = 0; i < allStations.length; i += 25) {
          final batch = allStations.skip(i).take(25).toList();

          final destinations = batch
              .map((station) => '${station['lat']},${station['lng']}')
              .join('|');

          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/distancematrix/json'
            '?units=metric'
            '&origins=${userPosition.latitude},${userPosition.longitude}'
            '&destinations=$destinations'
            '&mode=driving'
            '&key=$googleApiKey',
          );

          final response = await http.get(url);
          if (response.statusCode != 200) continue;

          final data = json.decode(response.body);
          final elements = data['rows'][0]['elements'];

          for (int j = 0; j < elements.length; j++) {
            final element = elements[j];
            if (element['status'] == 'OK') {
              final distance = element['distance']['value'];
              if (distance <= 20000) {
                batch[j]['_distanceText'] = element['distance']['text'];
                batch[j]['_durationText'] = element['duration']['text'];
                filteredStations.add(batch[j]);
              }
            }
          }
        }
      } else {
        // Show all stations
        filteredStations = allStations;
      }

      // Convert to markers
      final markers =
          filteredStations.map((station) {
            return Marker(
              markerId: MarkerId(station['id']),
              position: LatLng(
                (station['lat'] as num).toDouble(),
                (station['lng'] as num).toDouble(),
              ),
              infoWindow: InfoWindow(
                title: station['name'] ?? 'Station',
                snippet:
                    filterNearby
                        ? '📍 ${station['_distanceText']}, ⏱ ${station['_durationText']}'
                        : (station['address'] ?? ''),
              ),
            );
          }).toList();

      setState(() {
        stationMarkers = markers;
      });

      if (mapController != null && markers.isNotEmpty) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(markers.first.position, 12),
        );
      }
    } catch (e) {
      print('Error fetching stations: $e');
      setState(() {
        errorMessage = 'Failed to load stations.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // (The rest of the code remains unchanged)

  Future<void> _moveToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filter Options',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Radio<bool>(
                      value: true,
                      groupValue: filterNearby,
                      onChanged: (value) {
                        setModalState(() => filterNearby = true);
                        setState(() => filterNearby = true);
                        fetchNearbyStations();
                      },
                      activeColor: AppColors.primary,
                    ),
                    title: const Text('Nearby My Location'),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Reset Filters',
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: () {
                        setModalState(() {
                          filterNearby = false;
                          selectedChargerType = null;
                        });
                        setState(() {
                          filterNearby = false;
                          selectedChargerType = null;
                          fetchNearbyStations();
                        });
                        Navigator.pop(context); // Close bottom sheet
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 12,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: Set<Marker>.of(stationMarkers),
              onMapCreated: (controller) => mapController = controller,
            ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (errorMessage != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  isChargerTypeLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                chargerTypes.contains(selectedChargerType)
                                    ? selectedChargerType
                                    : null,
                            hint: const Text('Select Charger Type'),
                            items:
                                chargerTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedChargerType = value;
                              });
                              fetchNearbyStations();
                            },
                          ),
                        ),
                      ),

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: searchController,
                            onSubmitted: (query) {
                              searchForStation(query);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search for a station...',
                              border: InputBorder.none,
                              icon: Icon(
                                Icons.search,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.filter_list,
                            color: Colors.white,
                          ),
                          onPressed: () => showFilters(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _moveToCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> searchForStation(String query) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('stations').get();
      final stations =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

      // Filter stations by name
      final matchedStations =
          stations
              .where(
                (station) => (station['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .take(25) //Limit to 25 max to avoid Google API crash
              .toList();

      if (matchedStations.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No stations found for "$query".';
        });
        return;
      }

      // Get user position once
      final userPosition = await Geolocator.getCurrentPosition();

      // Batch request to Distance Matrix API (limit to 25)
      final destinations = matchedStations
          .map((station) => '${station['lat']},${station['lng']}')
          .join('|');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?units=metric'
        '&origins=${userPosition.latitude},${userPosition.longitude}'
        '&destinations=$destinations'
        '&mode=driving'
        '&key=$googleApiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to get distances');
      }

      final data = json.decode(response.body);
      final elements = data['rows'][0]['elements'];

      List<Map<String, dynamic>> updatedStations = [];

      for (int i = 0; i < matchedStations.length; i++) {
        final station = matchedStations[i];
        final element = elements[i];

        if (element['status'] == 'OK') {
          station['_distanceText'] = element['distance']['text'];
          station['_durationText'] = element['duration']['text'];
          updatedStations.add(station);
        }
      }

      // Create markers
      final markers =
          updatedStations.map((station) {
            return Marker(
              markerId: MarkerId(station['id']),
              position: LatLng(
                (station['lat'] as num).toDouble(),
                (station['lng'] as num).toDouble(),
              ),
              infoWindow: InfoWindow(
                title: station['name'] ?? 'Station',
                snippet:
                    '📍 ${station['_distanceText']}, ⏱ ${station['_durationText']}',
              ),
            );
          }).toList();

      setState(() {
        stationMarkers = markers;
        isLoading = false;
      });

      // Focus camera on first result
      if (markers.isNotEmpty && mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(markers.first.position, 13),
        );
      }
    } catch (e) {
      print('Error in search: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to search stations.';
      });
    }
  }
}
