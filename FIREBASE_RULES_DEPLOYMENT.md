# Firebase Rules Deployment Guide

## Overview
This guide explains how to deploy the Firebase security rules that enable global connectivity for your app's calling feature, similar to Instagram's architecture.

## Rules Architecture

The rules are designed to enable:
- ✅ **Global User Discovery** - Users can find and connect with anyone
- ✅ **Secure Calling** - Only authenticated users can initiate/receive calls
- ✅ **Privacy Protection** - Users control their own data
- ✅ **Media Sharing** - Secure image/video/audio sharing
- ✅ **Scalable Architecture** - Supports millions of users

## Deployment Steps

### 1. Deploy Firestore Rules

#### Option A: Firebase Console (Recommended for Quick Setup)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the entire content from `firestore.rules`
5. Paste and click **Publish**

#### Option B: Firebase CLI
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project directory
firebase init firestore

# Deploy the rules
firebase deploy --only firestore:rules
```

### 2. Deploy Storage Rules

#### Option A: Firebase Console
1. In Firebase Console, go to **Storage** → **Rules**
2. Copy the entire content from `storage.rules`
3. Paste and click **Publish**

#### Option B: Firebase CLI
```bash
# Deploy storage rules
firebase deploy --only storage:rules
```

### 3. Verify Deployment

Test the rules are working:
```bash
# Run this command to test your app
flutter run
```

## Rules Breakdown

### Firestore Rules Features

#### 1. **Calls Collection** - Video/Audio Calling
```javascript
match /calls/{userId} {
  // Users can receive calls from anyone (global connectivity)
  // Users can manage their own call state
  // Automatic cleanup of ended calls
}
```

#### 2. **Users Collection** - Profiles
```javascript
match /users/{userId} {
  // Public profiles for discovery
  // Private data protection
  // Profile updates by owner only
}
```

#### 3. **Conversations Collection** - Messaging
```javascript
match /conversations/{conversationId} {
  // Secure messaging between users
  // Read receipts support
  // Media sharing in chats
}
```

### Storage Rules Features

#### 1. **Profile Pictures**
- Public viewing for all authenticated users
- Owner-only uploads
- 50MB size limit

#### 2. **Chat Media**
- Images up to 50MB
- Videos up to 200MB
- Voice notes up to 5MB

#### 3. **Posts Media**
- Global viewing for discovery
- Owner-controlled uploads

## Security Features

### 1. **Authentication Required**
- All operations require authentication
- No anonymous access to user data

### 2. **Owner Verification**
```javascript
function isOwner(userId) {
  return request.auth.uid == userId;
}
```

### 3. **File Type Validation**
```javascript
function isImage() {
  return request.resource.contentType.matches('image/.*');
}
```

### 4. **Size Limits**
- Images: 50MB max
- Videos: 200MB max
- Voice notes: 5MB max

## Global Connectivity Rules

The rules enable Instagram-like global connectivity:

### 1. **User Discovery**
- Any authenticated user can view profiles
- Search and discovery enabled
- Privacy settings respected

### 2. **Call Initiation**
- Users can call anyone in the network
- Receiver controls acceptance
- No pre-approval needed (like Instagram)

### 3. **Message Initiation**
- Users can start conversations
- Spam prevention through rate limiting
- Block lists supported

## Testing the Rules

### Test Call Flow
```dart
// 1. User A initiates call to User B
await webRTCService.initiateCall(
  receiver: userB,
  callType: CallType.video,
);

// 2. User B receives notification (automatic via CallManager)
// 3. User B accepts/rejects
// 4. Connection established via Agora
```

### Test Permissions
1. **Profile Access**: ✅ Any authenticated user can view
2. **Call Initiation**: ✅ Any user can call any user
3. **Media Upload**: ✅ Users can upload their media
4. **Message Sending**: ✅ Users can message connections

## Production Checklist

Before going live:

- [ ] Deploy Firestore rules
- [ ] Deploy Storage rules
- [ ] Test with multiple user accounts
- [ ] Verify call functionality works
- [ ] Test media uploads
- [ ] Check error handling
- [ ] Monitor Firebase usage quotas
- [ ] Set up Firebase Analytics
- [ ] Configure Firebase Crashlytics
- [ ] Enable Firebase Performance Monitoring

## Monitoring & Limits

### Firebase Quotas (Free Tier)
- **Firestore**: 50K reads/20K writes per day
- **Storage**: 5GB storage, 1GB/day download
- **Authentication**: Unlimited users

### Recommended Monitoring
1. Set up Firebase Alerts for quota usage
2. Monitor Firestore usage in Console
3. Track Storage bandwidth
4. Monitor Agora usage (10,000 free minutes/month)

## Scaling Considerations

When your app grows:

1. **Implement Caching**
   - Cache user profiles locally
   - Cache recent conversations
   - Reduce Firestore reads

2. **Optimize Queries**
   - Use composite indexes
   - Paginate large lists
   - Implement lazy loading

3. **Upgrade Plans**
   - Firebase Blaze plan for production
   - Agora paid plans for more minutes
   - Consider CDN for media delivery

## Security Best Practices

1. **Never expose sensitive data**
   - Keep API keys secure
   - Use environment variables
   - Implement token authentication

2. **Rate Limiting**
   - Implement call rate limits
   - Message spam prevention
   - Upload throttling

3. **Content Moderation**
   - Implement reporting system
   - Review reported content
   - Block abusive users

## Support & Resources

- **Firebase Documentation**: https://firebase.google.com/docs
- **Agora Documentation**: https://docs.agora.io/
- **Security Rules Reference**: https://firebase.google.com/docs/rules
- **Firebase Status**: https://status.firebase.google.com/

## Troubleshooting

### Common Issues

1. **"Permission Denied" Errors**
   - Check user is authenticated
   - Verify rules are published
   - Check rule conditions

2. **Calls Not Connecting**
   - Verify Agora App ID is correct
   - Check network connectivity
   - Ensure permissions granted

3. **Media Upload Fails**
   - Check file size limits
   - Verify file type
   - Check storage rules

## Conclusion

Your app now has Instagram-like global connectivity with:
- ✅ Anyone can discover and connect with users
- ✅ Secure video/audio calling
- ✅ Media sharing capabilities
- ✅ Scalable architecture
- ✅ Privacy protection

The rules ensure that while users can connect globally, their data remains secure and under their control.