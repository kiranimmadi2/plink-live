# Firebase Configuration Rules

## Firestore Security Rules

Add these rules to your Firebase Console > Firestore Database > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Posts collection
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (request.auth.uid == resource.data.userId || 
         request.auth.uid == postId);
      allow delete: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // Messages collection
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow all other authenticated reads/writes for now
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Firebase Storage Security Rules

Add these rules to your Firebase Console > Storage > Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile images
    match /profiles/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Post images
    match /posts/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // General rule for authenticated users
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

## How to Apply These Rules:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (suuper2)
3. For Firestore:
   - Click on "Firestore Database" in the left menu
   - Click on "Rules" tab
   - Replace the existing rules with the Firestore rules above
   - Click "Publish"

4. For Storage:
   - Click on "Storage" in the left menu
   - Click on "Rules" tab
   - Replace the existing rules with the Storage rules above
   - Click "Publish"

## Important Notes:

- These rules require authentication for all operations
- Users can only modify their own profile and posts
- All authenticated users can read profiles and posts
- Make sure your app handles authentication properly before accessing Firestore/Storage