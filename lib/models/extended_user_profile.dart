import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String name;
  final String level; // 'beginner', 'intermediate', 'advanced'

  Activity({
    required this.name,
    this.level = 'intermediate',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'level': level,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      name: map['name'] ?? '',
      level: map['level'] ?? 'intermediate',
    );
  }
}

class ExtendedUserProfile {
  final String uid;
  final String name;
  final String? photoUrl;
  final String? city;
  final String? location;
  final double? latitude;
  final double? longitude;
  final List<String> interests;

  // New fields
  final bool verified;
  final List<String> connectionTypes;
  final List<Activity> activities;
  final String? aboutMe;
  final bool isOnline;
  final Timestamp? lastSeen;
  final int? age;
  final String? gender; // 'Male', 'Female', 'Other', 'Prefer not to say'

  // Calculated field
  double? distance; // Will be calculated based on current user's location

  ExtendedUserProfile({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.city,
    this.location,
    this.latitude,
    this.longitude,
    this.interests = const [],
    this.verified = false,
    this.connectionTypes = const [],
    this.activities = const [],
    this.aboutMe,
    this.isOnline = false,
    this.lastSeen,
    this.age,
    this.gender,
    this.distance,
  });

  factory ExtendedUserProfile.fromMap(Map<String, dynamic> map, String uid) {
    // Parse activities from map
    List<Activity> activities = [];
    if (map['activities'] != null) {
      final activitiesData = map['activities'] as List<dynamic>;
      activities = activitiesData
          .map((item) => Activity.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return ExtendedUserProfile(
      uid: uid,
      name: map['name'] ?? 'Unknown',
      photoUrl: map['photoUrl'],
      city: map['city'],
      location: map['location'] ?? map['displayLocation'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      interests: List<String>.from(map['interests'] ?? []),
      verified: map['verified'] ?? false,
      connectionTypes: List<String>.from(map['connectionTypes'] ?? []),
      activities: activities,
      aboutMe: map['aboutMe'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] as Timestamp?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photoUrl': photoUrl,
      'city': city,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'interests': interests,
      'verified': verified,
      'connectionTypes': connectionTypes,
      'activities': activities.map((a) => a.toMap()).toList(),
      'aboutMe': aboutMe,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'age': age,
      'gender': gender,
    };
  }

  // Helper to get display location
  String get displayLocation {
    if (city != null && city!.isNotEmpty) {
      return city!;
    } else if (location != null && location!.isNotEmpty) {
      return location!;
    }
    return 'Location not set';
  }

  // Helper to get formatted distance
  String? get formattedDistance {
    if (distance == null) return null;
    if (distance! < 1) {
      return '${(distance! * 1000).round()} m away';
    } else {
      return '${distance!.toStringAsFixed(1)} km away';
    }
  }

  // Check if user has specific connection type
  bool hasConnectionType(String type) {
    return connectionTypes.contains(type);
  }

  // Get activity names
  List<String> get activityNames {
    return activities.map((a) => a.name).toList();
  }
}
