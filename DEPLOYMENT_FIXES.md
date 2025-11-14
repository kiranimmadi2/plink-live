# Firebase Deployment Fixes

## 1. Configure Firebase Storage CORS

Run this command in your terminal (requires gsutil):

```bash
gsutil cors set cors.json gs://suuper2.appspot.com
```

Or if you don't have gsutil:
1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
2. Run: `gcloud init` and select your project
3. Run the cors command above

## 2. Deploy Firestore Indexes

Run this command to deploy indexes:

```bash
firebase deploy --only firestore:indexes
```

Or manually create them in Firebase Console:
1. Go to https://console.firebase.google.com
2. Select your project (suuper2)
3. Go to Firestore Database > Indexes
4. Click "Create Index" for each index in firestore.indexes.json

## 3. Fix Google Sign-In Warning

The warning about `signIn()` being deprecated is from the Google Sign-In Web SDK.
The Flutter plugin will handle this internally in a future update.
For now, you can safely ignore this warning.

## 4. Photo URL Caching

The app now implements automatic photo URL caching to prevent 429 errors:
- Photos are cached for 1 hour
- Maximum 100 cached photos
- Automatic cleanup of expired entries

## 5. Testing the Fixes

1. Clear browser cache and cookies
2. Sign out and sign in again
3. Check if profile photo loads correctly
4. Create a post and verify photos show in post cards

## 6. Monitor Performance

Check these in Firebase Console:
- Firestore Usage: Monitor read/write operations
- Storage Bandwidth: Check download usage
- Authentication: Verify sign-in methods are configured

## 7. Production Checklist

Before deploying to production:
- [ ] CORS is configured for your domain
- [ ] Firestore indexes are deployed
- [ ] Storage rules are secure
- [ ] Photo caching is working
- [ ] All authentication providers are configured
- [ ] Error tracking is set up