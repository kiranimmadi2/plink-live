# WORKING FEATURES - DO NOT MODIFY

> **IMPORTANT**: This document lists all features that are currently working correctly in the Supper app.
> When implementing new features or fixing bugs, **DO NOT** modify or break these existing functionalities.

---

## Quick Reference - Protected Features

| Category | Features | Status |
|----------|----------|--------|
| AI Matching | Semantic embeddings, Intent analysis, No hardcoded categories | Working |
| Messaging | 1-on-1 chat, Group chat, Typing indicators, Read receipts | Working |
| Live Connect | Filters, Pagination, Distance calculation, Search | Working |
| Profile | Edit profile, Interests, Activities, Connection types | Working |
| Location | Background updates, City-only display, Silent permissions | Working |
| Connections | Send/Accept/Reject requests, Block users, Report users | Working |
| Notifications | FCM push, Local notifications, Badge counts | Working |
| Performance | Caching, Pagination, Offline persistence | Working |

---

## 1. Authentication & User Management

### Working Features:
- Email/password sign in and sign up
- Google Sign-In integration
- Automatic profile creation on first login
- Sign out functionality
- Auth state persistence
- Online/offline status tracking
- Last seen timestamp updates

### Files:
- `lib/services/auth_service.dart`
- `lib/services/profile_service.dart`
- `lib/screens/login_screen.dart`

---

## 2. AI-Powered Intent & Matching System

### Working Features:
- **NO HARDCODED CATEGORIES** - All intent understanding is AI-driven
- 768-dimensional vector embeddings via Google Gemini
- Semantic similarity matching with cosine similarity
- Multi-factor scoring algorithm:
  - Semantic similarity: 70% weight
  - Location proximity: 15% weight
  - Time/freshness: 10% weight
  - Keywords: 5% weight
- Complementary intent detection (buyer↔seller, seeking↔offering)
- Clarification dialogs for ambiguous intents
- Embedding caching (24-hour TTL)
- Match result caching (30-minute TTL)
- Fallback embedding generation when API quota exceeded

### Files:
- `lib/services/gemini_service.dart`
- `lib/services/unified_matching_service.dart`
- `lib/services/unified_intent_processor.dart`
- `lib/services/universal_intent_service.dart`
- `lib/services/vector_service.dart`

### DO NOT:
- Add hardcoded categories or intents
- Change embedding dimensions from 768
- Modify the matching weight percentages without testing
- Remove the caching mechanism

---

## 3. Messaging System

### Working Features:
- 1-on-1 direct messaging
- Group chat support
- Real-time typing indicators
- Message search functionality
- Image/media sharing
- Emoji picker (8 emoji quick access)
- Message reactions
- Message editing and deletion
- Read/unread status tracking
- Message pagination (20 messages per page)
- 8 chat theme colors (default, sunset, ocean, forest, berry, midnight, rose, golden)
- Reply/quote functionality
- Last message preview in conversation list
- Online status indicators with green dot
- Unread message badges

### Files:
- `lib/screens/enhanced_chat_screen.dart`
- `lib/screens/conversations_screen.dart`
- `lib/screens/group_chat_screen.dart`
- `lib/services/chat_service.dart`
- `lib/services/conversation_service.dart`
- `lib/services/hybrid_chat_service.dart`
- `lib/models/message_model.dart`
- `lib/models/conversation_model.dart`

### DO NOT:
- Change message pagination from 20 per page
- Modify conversation ID generation logic
- Remove typing indicator functionality
- Break the unread count system

---

## 4. Live Connect (Discovery)

### Working Features:
- Browse nearby people with real-time updates
- Distance-based filtering:
  - Near me (with GPS)
  - City (same city)
  - Worldwide (no location filter)
- Distance slider (1-500 km)
- Interest filtering (20+ interests)
- Gender filtering (Male, Female, Other)
- Age range filtering (18-50)
- Search by name, interests, or city
- User pagination (20 users per page)
- Connection status caching
- Filter persistence (saved to SharedPreferences)
- Real-time connection updates via stream
- Discovery mode toggle (visibility control)
- Profile detail bottom sheet with Edit button

### Files:
- `lib/screens/live_connect_tab_screen.dart`
- `lib/screens/my_connections_screen.dart`
- `lib/widgets/profile_detail_bottom_sheet.dart`
- `lib/widgets/edit_profile_bottom_sheet.dart`
- `lib/models/extended_user_profile.dart`

### DO NOT:
- Change user pagination from 20 per page
- Remove filter persistence
- Modify distance calculation formula (Haversine)
- Break the connection status caching

---

## 5. User Profile System

### Working Features:
- Profile editing (name, bio, photo, location)
- Profile photo upload and caching
- Interests selection and display
- Activities management
- Connection types (what user is looking for)
- About me section
- Age and gender info
- Post history with pagination
- Location auto-detection with GPS
- Profile visibility controls
- Online status privacy control

### Files:
- `lib/screens/profile/profile_edit_screen.dart`
- `lib/screens/profile_with_history_screen.dart`
- `lib/widgets/edit_profile_bottom_sheet.dart`
- `lib/widgets/profile_detail_bottom_sheet.dart`
- `lib/models/user_profile.dart`
- `lib/models/extended_user_profile.dart`

### DO NOT:
- Remove the interests section
- Break profile photo upload
- Modify the profile data structure without migration

---

## 6. Connection System

### Working Features:
- Send connection requests
- Accept/reject connection requests
- View pending requests with count badge
- View established connections
- Block users
- Report users (inappropriate behavior)
- Real-time connection updates
- Connection status in profile views
- Connection count display

### Files:
- `lib/services/connection_service.dart`
- `lib/screens/my_connections_screen.dart`
- `lib/services/block_report_service.dart`

### DO NOT:
- Change the connection request flow
- Remove blocking functionality
- Break the real-time connection updates

---

## 7. Location Services

### Working Features:
- Background location updates (every 10 minutes)
- Silent permission requests (no UI popup on updates)
- Movement-based location streaming (100m minimum)
- Location freshness checking (24-hour threshold)
- Distance calculation between users
- City extraction from coordinates (privacy-protected)
- Stale location auto-refresh
- Web platform compatibility (graceful handling)
- Location permission management

### Files:
- `lib/services/location_service.dart`
- `lib/services/geocoding_service.dart`

### DO NOT:
- Show exact GPS coordinates (privacy violation)
- Remove silent mode for background updates
- Change the 10-minute update interval without testing
- Break web platform compatibility

---

## 8. Notification System

### Working Features:
- FCM push notification setup
- Local notification display
- Connection request notifications
- Message notifications
- Badge count management
- Deep link routing
- Background message handling
- Notification permissions

### Files:
- `lib/services/notification_service.dart`

### DO NOT:
- Remove FCM initialization
- Break deep linking
- Modify notification channels without testing

---

## 9. Post System

### Working Features:
- AI-generated title and description from prompt
- Dynamic intent analysis
- Embedding generation for semantic search
- Price range support (min/max)
- Image attachments
- Location tagging
- Keyword extraction
- Clarification answers storage
- Active/inactive status
- Expiration handling
- View count tracking
- Matched users tracking

### Files:
- `lib/services/unified_post_service.dart`
- `lib/models/post_model.dart`

### DO NOT:
- Store posts in old collections (user_intents, intents, etc.)
- Remove embedding generation
- Break the intent analysis structure

---

## 10. Performance Optimizations

### Working Features:
- Firestore offline persistence (unlimited cache)
- Photo caching with CachedNetworkImage
- Embedding caching (24-hour TTL)
- Match result caching (30-minute TTL)
- Memory management via MemoryManager
- Pagination for all lists (20 items per page)
- Single status stream (avoid duplicate queries)
- Lazy loading of user data

### Files:
- `lib/services/cache_service.dart`
- `lib/services/photo_cache_service.dart`
- `lib/services/embedding_cache_service.dart`
- `lib/utils/memory_manager.dart`
- `lib/main.dart` (Firestore settings)

### DO NOT:
- Remove caching mechanisms
- Query Firestore without limit()
- Create duplicate streams for same data
- Disable offline persistence

---

## 11. Data Cleanup & Migration

### Working Features:
- One-time cleanup of old collections on first launch
- Automatic deletion of: user_intents, intents, processed_intents, embeddings
- SharedPreferences flag tracking (runs only once)
- Non-fatal error handling
- Conversation participant array fixing
- Activity data migration

### Files:
- `lib/services/database_cleanup_service.dart`
- `lib/services/user_migration_service.dart`
- `lib/services/conversation_migration_service.dart`
- `lib/services/activity_migration_service.dart`

### DO NOT:
- Remove the cleanup service
- Store data in old collections
- Break the migration logic

---

## 12. Theme & UI

### Working Features:
- Dark/Light mode toggle
- Material Design 3 theming
- Glassmorphic effects
- Animated gradients
- Floating particles
- Aurora backgrounds
- Smooth transitions
- Custom button styles

### Files:
- `lib/providers/theme_provider.dart`
- `lib/widgets/glassmorphic_container.dart`
- `lib/widgets/floating_particles.dart`
- `lib/widgets/animated_gradient_background.dart`

### DO NOT:
- Remove theme toggle functionality
- Break dark mode support

---

## 13. Voice Features

### Working Features:
- Voice recording in Home Screen
- Voice processing overlay with animations
- Voice orb visualizations
- Audio visualizer widget
- Haptic feedback integration

### Files:
- `lib/screens/home_screen.dart`
- `lib/widgets/voice_orb.dart`
- `lib/widgets/simple_voice_orb.dart`
- `lib/widgets/audio_visualizer.dart`
- `lib/widgets/liquid_wave_orb.dart`

### DO NOT:
- Remove voice recording UI
- Break the overlay animations

---

## Firestore Indexes Required

These composite indexes are required and should not be removed:

```
posts: userId (asc) + isActive (asc) + createdAt (desc)
conversations: participants (array) + lastMessageTime (desc)
messages: timestamp (desc) + read (asc)
connection_requests: receiverId (asc) + status (asc) + createdAt (desc)
```

---

## API Keys & Configuration

Configuration in `lib/config/api_config.dart`:
- Gemini API key (should move to env vars in production)
- Model names: gemini-1.5-flash-latest, text-embedding-004
- Embedding dimension: 768
- Matching thresholds

### DO NOT:
- Commit API keys to version control
- Change embedding dimension without full reindex
- Modify model names without testing

---

## Navigation Structure

Main navigation (bottom tabs):
1. **Discover** (HomeScreen) - Index 0
2. **Messages** (ConversationsScreen) - Index 1
3. **Live Connect** (LiveConnectTabScreen) - Index 2
4. **Profile** (ProfileWithHistoryScreen) - Index 3

### DO NOT:
- Change the navigation order
- Remove any main tabs
- Break the floating bottom menu

---

## Summary Checklist

Before submitting any changes, verify:

- [ ] AI matching still works (no hardcoded categories)
- [ ] Messaging works (send, receive, typing indicators)
- [ ] Live Connect filters work (location, interests, gender, age)
- [ ] Profile editing works (including interests)
- [ ] Location updates work silently in background
- [ ] Connections can be sent/accepted/rejected
- [ ] Notifications are received
- [ ] Offline mode works (cached data available)
- [ ] Pagination works (20 items per page)
- [ ] Dark/Light mode toggle works
- [ ] No console errors or warnings

---

*Last Updated: December 2024*
*App Version: 1.0.0+1*
*Branch: feature/live-connect-enhanced*
