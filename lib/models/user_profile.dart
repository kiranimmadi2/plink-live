import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? phone;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  final bool isVerified;
  final bool showOnlineStatus;
  final String bio;
  final List<String> interests;
  final String? fcmToken;
  final Map<String, dynamic>? additionalInfo;
  
  // Add photoUrl getter for backward compatibility
  String? get photoUrl => profileImageUrl;

  UserProfile({
    required this.uid,
    String? id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.phone,
    this.location,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.lastSeen,
    this.isOnline = false,
    this.isVerified = false,
    this.showOnlineStatus = true,
    this.bio = '',
    this.interests = const [],
    this.fcmToken,
    this.additionalInfo,
  }) : id = id ?? uid;

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? data['photoUrl'],
      phone: data['phone'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      bio: data['bio'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      fcmToken: data['fcmToken'],
      additionalInfo: data['additionalInfo'],
    );
  }

  static UserProfile fromMap(Map<String, dynamic> data, String userId) {
    return UserProfile(
      uid: userId,
      id: userId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? data['photoUrl'],
      phone: data['phone'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      bio: data['bio'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      fcmToken: data['fcmToken'],
      additionalInfo: data['additionalInfo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'photoUrl': profileImageUrl, // Also save as photoUrl for compatibility
      'phone': phone,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
      'isVerified': isVerified,
      'showOnlineStatus': showOnlineStatus,
      'bio': bio,
      'interests': interests,
      'fcmToken': fcmToken,
      'additionalInfo': additionalInfo,
    };
  }
}