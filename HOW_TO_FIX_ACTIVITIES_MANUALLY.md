# How to Fix Activities Manually - Remove Level Information

## Problem
Activities are showing as "(level: intermediate, name: Running)" instead of just "Running"

This happens because old data in Firestore has activities stored in Map format with level information.

---

## ✅ METHOD 1: Use the Migration Button (EASIEST)

I've added an orange **cleaning icon button** (🧹) next to the Activities section in your profile.

### Steps:
1. **Open the app**
2. **Go to Profile screen**
3. **Look for the Activities section**
4. **Click the orange cleaning icon button** (🧹) next to "Activities:"
5. **Wait for "Migration Complete" dialog**
6. **Restart the app**
7. **Done!** Activities will now show as just names (e.g., "Running")

**Location:** Profile Screen → Activities Section → Orange Button (🧹)

---

## 🔧 METHOD 2: Manual Firestore Cleanup (Advanced)

If the button doesn't work, you can manually clean the data in Firebase Console:

### Steps:

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com/
   - Select your project

2. **Navigate to Firestore Database**
   - Click "Firestore Database" in left menu
   - Click on "users" collection

3. **Find Your User Document**
   - Find your user ID (same as your Firebase Auth UID)
   - Click on your user document

4. **Edit Activities Field**
   - Find the `activities` field
   - Click on it to edit

5. **Change Format**

**OLD FORMAT (with level):**
```json
[
  {"name": "Running", "level": "intermediate"},
  {"name": "Gym", "level": "advanced"},
  {"name": "Tennis", "level": "beginner"}
]
```

**NEW FORMAT (only names):**
```json
[
  "Running",
  "Gym",
  "Tennis"
]
```

6. **Save Changes**
   - Click "Update"
   - Close Firebase Console

7. **Restart App**
   - Force close the app
   - Open it again
   - Activities should now show correctly

---

## 🔄 METHOD 3: Delete and Re-add Activities (Simple)

If you don't have many activities, you can just delete and re-add them:

### Steps:

1. **Open the app**
2. **Go to Profile**
3. **Enable Edit Mode** (click edit button)
4. **Delete all activities** (one by one)
5. **Click "+ Add Activity" button**
6. **Add your activities again**
7. **Save profile**
8. **Done!** New activities will be in correct format

---

## 🧪 Verify It's Fixed

After using any method above:

1. Open your profile
2. Look at Activities section
3. Activities should display as:
   - ✅ **Correct:** "Running", "Gym", "Tennis"
   - ❌ **Wrong:** "(level: intermediate, name: Running)"

---

## 🚨 Troubleshooting

### Issue: Button doesn't work
**Solution:** Try Method 2 or Method 3

### Issue: Activities still show level after migration
**Solution:**
1. Force close the app completely
2. Clear app cache: Settings → Apps → Supper → Clear Cache
3. Restart the app

### Issue: Can't find the orange button
**Solution:** The button is always visible in the Activities section header:
```
Activities:  [➕] [🧹]
             ↑    ↑
        Add   Clean/Fix
```

### Issue: Migration says "No activities to migrate"
**Solution:** This means your activities are already in the new format. The level display might be from cache. Try:
1. Force close app
2. Clear cache
3. Restart

---

## 📱 What Each Method Does

| Method | What It Does | Time | Difficulty |
|--------|-------------|------|------------|
| **Method 1 (Button)** | Automatically converts Map format to String format | 5 seconds | ⭐ Easy |
| **Method 2 (Firestore)** | Manually edit the database | 2-3 minutes | ⭐⭐⭐ Advanced |
| **Method 3 (Delete/Re-add)** | Deletes old data and creates new clean data | 1-2 minutes | ⭐⭐ Simple |

---

## ✅ Recommended Approach

1. **First, try Method 1** (orange cleaning button)
2. **If that doesn't work, try Method 3** (delete and re-add)
3. **If still not working, use Method 2** (manual Firestore edit)

---

## 🔍 Technical Details

### What the Migration Does:
1. Reads your activities from Firestore
2. Checks if any are in Map format: `{"name": "X", "level": "Y"}`
3. Converts them to simple strings: `"X"`
4. Saves back to Firestore
5. Reloads your profile
6. Shows success message

### Why This Happens:
- Old version of the app stored activities with level information
- New version only stores activity names
- Old data needs to be converted to new format
- Migration is safe and non-destructive

---

## 📞 If Nothing Works

If you still see level information after trying all methods:

1. **Check Firebase Console** directly to see current data format
2. **Share a screenshot** of the activities field in Firestore
3. **Check app version** - make sure you're running the latest build
4. **Clear app data** (Settings → Apps → Supper → Clear Data) - WARNING: This logs you out!

---

**Quick Summary:**
Just click the orange cleaning button (🧹) next to "Activities:" in your profile, wait for success message, restart app. Done!
