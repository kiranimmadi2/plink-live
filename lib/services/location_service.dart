import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'geocoding_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Debouncing: Prevent multiple simultaneous location updates
  bool _isUpdatingLocation = false;
  DateTime? _lastLocationUpdate;
  bool _periodicUpdatesStarted = false; // Prevent multiple periodic update loops

  // Location freshness: Consider location stale after 24 hours
  static const Duration locationFreshnessThreshold = Duration(hours: 24);

  // Check if permission has been requested before
  Future<bool> hasRequestedPermissionBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_permission_requested') ?? false;
  }

  // Mark that permission has been requested
  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_permission_requested', true);
  }

  // Get current location SILENTLY in background (no user prompts)
  Future<Position?> getCurrentLocation({bool silent = true}) async {
    try {
      print('LocationService: Starting getCurrentLocation (silent=$silent), isWeb=$kIsWeb');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('LocationService: Services enabled=$serviceEnabled');

      if (!serviceEnabled) {
        print('Location services are disabled - fetching silently failed');
        // Don't show any alerts, just return null silently
        if (!kIsWeb) {
          return null;
        }
      }

      // Check permission status SILENTLY
      LocationPermission permission = await Geolocator.checkPermission();
      print('LocationService: Current permission=$permission');

      // If permission not granted and this is a silent background fetch
      if (silent && permission == LocationPermission.denied) {
        print('LocationService: Permission not granted, skipping silent fetch');
        // Don't request permission during silent background fetch
        return null;
      }

      // Only request permission if NOT silent mode (user initiated)
      if (!silent && permission == LocationPermission.denied) {
        final hasRequested = await hasRequestedPermissionBefore();
        print('LocationService: Has requested before=$hasRequested');

        if (!hasRequested || kIsWeb) { // Always try on web
          // Request permission for the first time
          print('LocationService: Requesting permission...');
          permission = await Geolocator.requestPermission();
          print('LocationService: New permission=$permission');
          await markPermissionRequested();
        } else {
          print('Permission denied previously');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied - silent fetch skipped');
        return null;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // SILENT BACKGROUND FETCH: Try to get location quickly without blocking UI
        print('LocationService: Getting position silently with fallback strategy...');

        // Strategy 1: Try last known position FIRST (instant, no GPS wait)
        try {
          print('LocationService: Trying last known position first...');
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            print('LocationService: Got last known position lat=${lastPosition.latitude}, lng=${lastPosition.longitude}');
            // Continue fetching fresh location in background, but return this immediately
            _fetchFreshLocationInBackground();
            return lastPosition;
          }
        } catch (e) {
          print('LocationService: Last known position failed: $e');
        }

        // Strategy 2: Try medium accuracy with moderate timeout (balanced)
        try {
          print('LocationService: Trying medium accuracy with 30s timeout...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 30),
          );
          print('LocationService: Got medium accuracy position lat=${position.latitude}, lng=${position.longitude}');
          return position;
        } catch (e) {
          print('LocationService: Medium accuracy failed: $e');
        }

        // Strategy 3: Try low accuracy as fallback (works even with weak GPS)
        try {
          print('LocationService: Trying low accuracy with 20s timeout...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 20),
          );
          print('LocationService: Got low accuracy position lat=${position.latitude}, lng=${position.longitude}');
          return position;
        } catch (e) {
          print('LocationService: Low accuracy failed: $e');
        }
      }

      return null;
    } catch (e) {
      print('LocationService: Error getting location: $e');
      // On web, try a simpler approach
      if (kIsWeb) {
        try {
          print('LocationService: Trying web fallback...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );
          print('LocationService: Web fallback success lat=${position.latitude}, lng=${position.longitude}');
          return position;
        } catch (webError) {
          print('LocationService: Web fallback failed: $webError');
        }
      }
      return null;
    }
  }

  // Fetch fresh location in background without blocking
  void _fetchFreshLocationInBackground() async {
    try {
      print('LocationService: Fetching fresh location in background...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 60),
      );
      print('LocationService: Background fetch completed lat=${position.latitude}, lng=${position.longitude}');
      // Update user location silently in background
      await updateUserLocation(position: position);
    } catch (e) {
      print('LocationService: Background fetch failed (not critical): $e');
      // Silently fail - don't show errors to user
    }
  }

  // Get city name from coordinates - Enhanced with real API
  Future<Map<String, dynamic>?> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      print('LocationService: Getting detailed address for lat=$latitude, lng=$longitude');
      
      // Use the new geocoding service for all platforms
      final addressData = await GeocodingService.getAddressFromCoordinates(latitude, longitude);
      
      if (addressData != null) {
        print('LocationService: Got address data: ${addressData['display']}');
        return addressData;
      }
      
      // Fallback to old geocoding method if API fails
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            latitude,
            longitude,
          );

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];

            return {
              'formatted': '${place.locality ?? place.subLocality ?? ''}, ${place.administrativeArea ?? ''}',
              'area': place.subLocality ?? '',
              'city': place.locality ?? '',
              'state': place.administrativeArea ?? '',
              'pincode': place.postalCode ?? '',
              'country': place.country ?? '',
              'display': place.locality ?? '',
            };
          }
        } catch (e) {
          print('LocationService: Fallback geocoding failed: $e');
        }
      }

      // If all geocoding fails, return null - don't fake location
      print('LocationService: Could not reverse geocode coordinates');
      return null;
    } catch (e) {
      print('LocationService: Error getting address: $e');
      return null;
    }
  }

  // Update user's location in Firestore with detailed address - SILENT MODE SUPPORTED
  Future<bool> updateUserLocation({Position? position, bool silent = true}) async {
    try {
      print('LocationService: updateUserLocation called (silent=$silent)');

      // DEBOUNCE: If already updating, skip this call
      if (_isUpdatingLocation) {
        print('LocationService: Already updating location, skipping duplicate call');
        return false;
      }

      // RATE LIMIT: Don't update more than once per minute
      if (_lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate.inSeconds < 60) {
          print('LocationService: Updated ${timeSinceLastUpdate.inSeconds}s ago, skipping (rate limit: 60s)');
          return false;
        }
      }

      _isUpdatingLocation = true;

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('LocationService: No authenticated user');
        _isUpdatingLocation = false;
        return false;
      }

      Position? currentPosition = position ?? await getCurrentLocation(silent: silent);

      if (currentPosition != null) {
        // Get detailed address from coordinates SILENTLY
        final addressData = await getCityFromCoordinates(
          currentPosition.latitude,
          currentPosition.longitude,
        );

        if (addressData != null && addressData['city'] != null && addressData['city'].toString().isNotEmpty) {
          print('LocationService: Updating user location silently with detailed address: ${addressData['display']}');

          Map<String, dynamic> locationData = {
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
            'location': addressData['formatted'] ?? addressData['display'] ?? addressData['city'],
            'city': addressData['city'],
            'area': addressData['area'] ?? '',
            'state': addressData['state'] ?? '',
            'pincode': addressData['pincode'] ?? '',
            'country': addressData['country'] ?? '',
            'displayLocation': addressData['display'] ?? addressData['city'],
            'locationUpdatedAt': FieldValue.serverTimestamp(),
          };

          // Update user document SILENTLY in background - use set with merge to ensure document exists
          await _firestore.collection('users').doc(userId).set(
            locationData,
            SetOptions(merge: true),
          );

          print('LocationService: Location updated silently with area: ${addressData['area']}, city: ${addressData['city']}');
          _lastLocationUpdate = DateTime.now();
          _isUpdatingLocation = false;
          return true;
        } else {
          print('LocationService: Could not get valid address data from coordinates (silent fetch)');
          _isUpdatingLocation = false;
          return false;
        }
      } else {
        print('LocationService: Could not get current position (silent fetch)');
        _isUpdatingLocation = false;
        return false;
      }
    } catch (e) {
      print('LocationService: Error updating user location: $e');
      _isUpdatingLocation = false;
      // Fail silently - no user-facing errors or fake locations
      return false;
    }
  }

  // Initialize location on app start - SILENT BACKGROUND PROCESS
  Future<void> initializeLocation() async {
    try {
      print('LocationService: Initializing location silently in background...');

      // Check if location services are enabled SILENTLY
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        print('LocationService: Location services are disabled - skipping silent init');
        return; // Exit silently, no alerts
      }

      // Check if we have permission already SILENTLY
      LocationPermission permission = await Geolocator.checkPermission();
      print('LocationService: Current permission: $permission');

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // We have permission, update location SILENTLY in background
        print('LocationService: Have permission, fetching location silently...');
        final success = await updateUserLocation(silent: true);
        print('LocationService: Silent location update success: $success');
      } else if (permission == LocationPermission.denied) {
        // Check if this is the VERY FIRST TIME (app just installed)
        final hasRequested = await hasRequestedPermissionBefore();

        if (!hasRequested) {
          // ONLY on very first app launch, request permission once
          print('LocationService: First app launch - requesting location permission ONE TIME...');
          permission = await Geolocator.requestPermission();
          await markPermissionRequested();
          print('LocationService: Permission after request: $permission');

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            print('LocationService: Permission granted, updating location silently...');
            final success = await updateUserLocation(silent: true);
            print('LocationService: Silent location update success: $success');
          } else {
            print('LocationService: Permission denied by user - will not ask again');
          }
        } else {
          // Permission was already requested before, skip silently
          print('LocationService: Permission was requested before, skipping silent init');
        }
      } else if (permission == LocationPermission.deniedForever) {
        print('LocationService: Permission denied forever - skipping silent init');
      }
    } catch (e) {
      print('LocationService: Error initializing location: $e');
      // Fail silently - no user-facing errors
    }
  }

  // Request location permission manually (USER INITIATED - for settings)
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      await markPermissionRequested();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Permission granted, update location (NOT SILENT - user requested)
        return await updateUserLocation(silent: false);
      }

      return false;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  // Open app settings for location permission
  Future<void> openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  // Clear stored permission preference (for testing)
  Future<void> clearPermissionPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('location_permission_requested');
  }

  // Start periodic background location updates (SILENT)
  Future<void> startPeriodicLocationUpdates() async {
    try {
      // CRITICAL: Only start once to prevent multiple infinite loops
      if (_periodicUpdatesStarted) {
        print('LocationService: Periodic updates already running, skipping...');
        return;
      }

      _periodicUpdatesStarted = true;
      print('LocationService: Starting periodic background location updates (every 10 minutes)...');

      // Update location every 10 minutes in background SILENTLY
      Future.delayed(Duration.zero, () async {
        while (true) {
          try {
            // Wait 10 minutes between updates (reduced API calls)
            await Future.delayed(const Duration(minutes: 10));

            // Check if user is still authenticated
            if (_auth.currentUser != null) {
              print('LocationService: Running periodic silent location update...');
              await updateUserLocation(silent: true);
            } else {
              print('LocationService: User not authenticated, skipping periodic update');
            }
          } catch (e) {
            print('LocationService: Error in periodic update: $e');
            // Continue loop even if one update fails
          }
        }
      });
    } catch (e) {
      print('LocationService: Error starting periodic updates: $e');
    }
  }

  // Update location when app comes to foreground (SILENT)
  Future<void> onAppResume() async {
    try {
      print('LocationService: App resumed, checking location freshness...');
      await checkAndRefreshStaleLocation();
    } catch (e) {
      print('LocationService: Error updating location on resume: $e');
    }
  }

  // Check if location is stale and refresh if needed (SMART FRESHNESS CHECK)
  Future<bool> checkAndRefreshStaleLocation() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('LocationService: No authenticated user');
        return false;
      }

      // Get user's current location data from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final locationUpdatedAt = data?['locationUpdatedAt'] as Timestamp?;

        if (locationUpdatedAt != null) {
          final lastUpdate = locationUpdatedAt.toDate();
          final timeSinceUpdate = DateTime.now().difference(lastUpdate);

          print('LocationService: Last location update was ${timeSinceUpdate.inHours} hours ago');

          // If location is older than 24 hours, refresh it
          if (timeSinceUpdate > locationFreshnessThreshold) {
            print('LocationService: Location is stale (>${locationFreshnessThreshold.inHours}h old), refreshing...');
            return await updateUserLocation(silent: true);
          } else {
            print('LocationService: Location is fresh (${timeSinceUpdate.inHours}h old), no update needed');
            return true;
          }
        } else {
          // No location timestamp, update location
          print('LocationService: No location timestamp found, updating location...');
          return await updateUserLocation(silent: true);
        }
      } else {
        // User document doesn't exist, create with location
        print('LocationService: User document not found, creating with location...');
        return await updateUserLocation(silent: true);
      }
    } catch (e) {
      print('LocationService: Error checking location freshness: $e');
      return false;
    }
  }

  // Get location age in hours for UI display
  Future<int?> getLocationAgeInHours() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final locationUpdatedAt = data?['locationUpdatedAt'] as Timestamp?;

        if (locationUpdatedAt != null) {
          final lastUpdate = locationUpdatedAt.toDate();
          final timeSinceUpdate = DateTime.now().difference(lastUpdate);
          return timeSinceUpdate.inHours;
        }
      }
      return null;
    } catch (e) {
      print('LocationService: Error getting location age: $e');
      return null;
    }
  }

  // Check location status and return user-friendly error message
  Future<Map<String, dynamic>> checkLocationStatus() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        return {
          'canGetLocation': false,
          'reason': 'Location services are disabled',
          'message': 'Please enable location/GPS in your device settings',
          'canOpenSettings': true,
        };
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        return {
          'canGetLocation': false,
          'reason': 'Permission denied forever',
          'message': 'Please enable location permission for this app in your device settings',
          'canOpenSettings': true,
        };
      }

      if (permission == LocationPermission.denied) {
        return {
          'canGetLocation': false,
          'reason': 'Permission not granted',
          'message': 'Location permission is required to find matches near you',
          'canRequestPermission': true,
        };
      }

      return {
        'canGetLocation': true,
        'reason': 'All good',
        'message': 'Location is available',
      };
    } catch (e) {
      return {
        'canGetLocation': false,
        'reason': 'Error checking location',
        'message': 'Failed to check location status: $e',
      };
    }
  }

  // Force refresh location - SILENT background process (user can call manually from settings)
  Future<bool> forceRefreshLocation({bool silent = true}) async {
    try {
      print('LocationService: Force refreshing location (silent=$silent)...');
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('LocationService: No authenticated user');
        return false;
      }

      // Check if location services are enabled SILENTLY
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        print('LocationService: Location services are disabled - skipping silent refresh');
        return false;
      }

      // Check permission silently
      LocationPermission permission = await Geolocator.checkPermission();

      // Only request permission if user-initiated (not silent)
      if (!silent && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        await markPermissionRequested();
      }

      if (permission == LocationPermission.deniedForever) {
        print('LocationService: Permission denied forever - skipping silent refresh');
        return false;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get fresh location SILENTLY with fallback strategy
        final position = await getCurrentLocation(silent: silent);
        if (position != null) {
          print('LocationService: Got GPS position: ${position.latitude}, ${position.longitude}');

          // Update user location SILENTLY
          return await updateUserLocation(position: position, silent: silent);
        } else {
          print('LocationService: Could not get GPS position (silent fetch)');
          return false;
        }
      }

      return false;
    } catch (e) {
      print('LocationService: Error force refreshing location: $e');
      // Fail silently
      return false;
    }
  }
}