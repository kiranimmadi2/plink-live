import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'other providers/app_providers.dart';

/// LIVE CONNECT FILTER STATE

/// State class for Live Connect filters
class LiveConnectFilterState {
  final bool filterByInterests;
  final bool filterByGender;
  final bool filterByAge;
  final double distanceFilter;
  final String locationFilter;
  final List<String> selectedGenders;
  final double minAge;
  final double maxAge;
  final String searchQuery;

  const LiveConnectFilterState({
    this.filterByInterests = false,
    this.filterByGender = false,
    this.filterByAge = false,
    this.distanceFilter = 50.0,
    this.locationFilter = 'Worldwide',
    this.selectedGenders = const [],
    this.minAge = 18,
    this.maxAge = 50,
    this.searchQuery = '',
  });

  LiveConnectFilterState copyWith({
    bool? filterByInterests,
    bool? filterByGender,
    bool? filterByAge,
    double? distanceFilter,
    String? locationFilter,
    List<String>? selectedGenders,
    double? minAge,
    double? maxAge,
    String? searchQuery,
  }) {
    return LiveConnectFilterState(
      filterByInterests: filterByInterests ?? this.filterByInterests,
      filterByGender: filterByGender ?? this.filterByGender,
      filterByAge: filterByAge ?? this.filterByAge,
      distanceFilter: distanceFilter ?? this.distanceFilter,
      locationFilter: locationFilter ?? this.locationFilter,
      selectedGenders: selectedGenders ?? this.selectedGenders,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      filterByInterests ||
      filterByGender ||
      filterByAge ||
      searchQuery.isNotEmpty;
}

/// LIVE CONNECT FILTER NOTIFIER

class LiveConnectFilterNotifier extends Notifier<LiveConnectFilterState> {
  @override
  LiveConnectFilterState build() {
    return const LiveConnectFilterState();
  }

  void setFilterByInterests(bool value) {
    state = state.copyWith(filterByInterests: value);
  }

  void setFilterByGender(bool value) {
    state = state.copyWith(filterByGender: value);
  }

  void setFilterByAge(bool value) {
    state = state.copyWith(filterByAge: value);
  }

  void setDistanceFilter(double value) {
    state = state.copyWith(distanceFilter: value);
  }

  void setLocationFilter(String value) {
    state = state.copyWith(locationFilter: value);
  }

  void setSelectedGenders(List<String> genders) {
    state = state.copyWith(selectedGenders: genders);
  }

  void toggleGender(String gender) {
    final currentGenders = List<String>.from(state.selectedGenders);
    if (currentGenders.contains(gender)) {
      currentGenders.remove(gender);
    } else {
      currentGenders.add(gender);
    }
    state = state.copyWith(selectedGenders: currentGenders);
  }

  void setAgeRange(double min, double max) {
    state = state.copyWith(minAge: min, maxAge: max);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.toLowerCase());
  }

  void clearFilters() {
    state = const LiveConnectFilterState();
  }

  void reset() {
    state = const LiveConnectFilterState();
  }
}

/// Provider for Live Connect filters
final liveConnectFilterProvider =
    NotifierProvider<LiveConnectFilterNotifier, LiveConnectFilterState>(
      LiveConnectFilterNotifier.new,
    );

/// NEARBY PEOPLE STATE

/// State class for nearby people list
class NearbyPeopleState {
  final List<Map<String, dynamic>> people;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  const NearbyPeopleState({
    this.people = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDocument,
    this.error,
  });

  NearbyPeopleState copyWith({
    List<Map<String, dynamic>>? people,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
    String? error,
    bool clearLastDocument = false,
  }) {
    return NearbyPeopleState(
      people: people ?? this.people,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: clearLastDocument
          ? null
          : (lastDocument ?? this.lastDocument),
      error: error,
    );
  }
}

/// NEARBY PEOPLE NOTIFIER

class NearbyPeopleNotifier extends Notifier<NearbyPeopleState> {
  static const int _pageSize = 20;

  @override
  NearbyPeopleState build() {
    return const NearbyPeopleState();
  }

  String? get currentUserId => ref.watch(currentUserIdProvider);

  /// Load initial users
  Future<void> loadInitial() async {
    if (currentUserId == null || state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      clearLastDocument: true,
    );

    try {
      final query = FirebaseFirestore.instance
          .collection('users')
          .where('uid', isNotEqualTo: currentUserId)
          .limit(_pageSize);

      final snapshot = await query.get();
      final people = snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();

      state = state.copyWith(
        people: people,
        isLoading: false,
        hasMore: snapshot.docs.length >= _pageSize,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load more users (pagination)
  Future<void> loadMore() async {
    if (currentUserId == null ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.lastDocument == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final query = FirebaseFirestore.instance
          .collection('users')
          .where('uid', isNotEqualTo: currentUserId)
          .startAfterDocument(state.lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();
      final newPeople = snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();

      state = state.copyWith(
        people: [...state.people, ...newPeople],
        isLoadingMore: false,
        hasMore: snapshot.docs.length >= _pageSize,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Refresh the list
  Future<void> refresh() async {
    state = const NearbyPeopleState();
    await loadInitial();
  }

  /// Update a person in the list
  void updatePerson(String odlalud, Map<String, dynamic> data) {
    final updatedPeople = state.people.map((p) {
      if (p['uid'] == odlalud) {
        return {...p, ...data};
      }
      return p;
    }).toList();
    state = state.copyWith(people: updatedPeople);
  }

  /// Remove a person from the list
  void removePerson(String odlalud) {
    state = state.copyWith(
      people: state.people.where((p) => p['uid'] != odlalud).toList(),
    );
  }
}

/// Provider for nearby people
final nearbyPeopleProvider =
    NotifierProvider<NearbyPeopleNotifier, NearbyPeopleState>(
      NearbyPeopleNotifier.new,
    );

/// CONNECTION STATUS CACHE

/// State for connection status caching
class ConnectionStatusCacheState {
  final Map<String, bool> isConnected;
  final Map<String, String?> requestStatus; // 'sent', 'received', or null
  final List<String> myConnections;

  const ConnectionStatusCacheState({
    this.isConnected = const {},
    this.requestStatus = const {},
    this.myConnections = const [],
  });

  ConnectionStatusCacheState copyWith({
    Map<String, bool>? isConnected,
    Map<String, String?>? requestStatus,
    List<String>? myConnections,
  }) {
    return ConnectionStatusCacheState(
      isConnected: isConnected ?? this.isConnected,
      requestStatus: requestStatus ?? this.requestStatus,
      myConnections: myConnections ?? this.myConnections,
    );
  }
}

class ConnectionStatusCacheNotifier extends Notifier<ConnectionStatusCacheState> {
  @override
  ConnectionStatusCacheState build() {
    return const ConnectionStatusCacheState();
  }

  void setConnected(String odlalud, bool value) {
    state = state.copyWith(isConnected: {...state.isConnected, odlalud: value});
  }

  void setRequestStatus(String odlalud, String? status) {
    state = state.copyWith(
      requestStatus: {...state.requestStatus, odlalud: status},
    );
  }

  void setMyConnections(List<String> connections) {
    state = state.copyWith(myConnections: connections);
  }

  void addConnection(String odlalud) {
    if (!state.myConnections.contains(odlalud)) {
      state = state.copyWith(
        myConnections: [...state.myConnections, odlalud],
        isConnected: {...state.isConnected, odlalud: true},
      );
    }
  }

  void removeConnection(String odlalud) {
    state = state.copyWith(
      myConnections: state.myConnections.where((id) => id != odlalud).toList(),
      isConnected: {...state.isConnected, odlalud: false},
    );
  }

  bool isUserConnected(String odlalud) {
    return state.isConnected[odlalud] ?? state.myConnections.contains(odlalud);
  }

  String? getRequestStatus(String odlalud) {
    return state.requestStatus[odlalud];
  }

  void clearCache() {
    state = const ConnectionStatusCacheState();
  }
}

/// Provider for connection status cache
final connectionStatusCacheProvider =
    NotifierProvider<ConnectionStatusCacheNotifier, ConnectionStatusCacheState>(
      ConnectionStatusCacheNotifier.new,
    );

/// SELECTED INTERESTS PROVIDER

/// State for selected interests
class SelectedInterestsState {
  final List<String> interests;

  const SelectedInterestsState({this.interests = const []});

  SelectedInterestsState copyWith({List<String>? interests}) {
    return SelectedInterestsState(interests: interests ?? this.interests);
  }
}

class SelectedInterestsNotifier extends Notifier<SelectedInterestsState> {
  @override
  SelectedInterestsState build() {
    return const SelectedInterestsState();
  }

  void setInterests(List<String> interests) {
    state = state.copyWith(interests: interests);
  }

  void addInterest(String interest) {
    if (!state.interests.contains(interest)) {
      state = state.copyWith(interests: [...state.interests, interest]);
    }
  }

  void removeInterest(String interest) {
    state = state.copyWith(
      interests: state.interests.where((i) => i != interest).toList(),
    );
  }

  void clear() {
    state = const SelectedInterestsState();
  }
}

/// Provider for user's selected interests
final selectedInterestsProvider =
    NotifierProvider<SelectedInterestsNotifier, SelectedInterestsState>(
      SelectedInterestsNotifier.new,
    );

/// AVAILABLE INTERESTS

/// List of available interests
const List<String> availableInterests = [
  'Dating',
  'Friendship',
  'Business',
  'Roommate',
  'Job Seeker',
  'Hiring',
  'Selling',
  'Buying',
  'Lost & Found',
  'Events',
  'Sports',
  'Travel',
  'Food',
  'Music',
  'Movies',
  'Gaming',
  'Fitness',
  'Art',
  'Technology',
  'Photography',
  'Fashion',
];

/// Available genders
const List<String> availableGenders = ['Male', 'Female', 'Other'];
