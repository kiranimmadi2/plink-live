# 🧪 LIVE CONNECT - TESTING GUIDE

## ✅ Pre-Testing Checklist

Before you start testing, make sure you've completed these steps:

### **1. Firestore Security Rules**
- [ ] Open Firebase Console
- [ ] Navigate to Firestore Database → Rules
- [ ] Copy contents from `firestore_security_rules.txt`
- [ ] Paste into rules editor
- [ ] Click "Publish"
- [ ] Wait for confirmation message

### **2. App Dependencies**
- [ ] Run `flutter pub get` to ensure all dependencies are installed
- [ ] No compilation errors
- [ ] App builds successfully

### **3. Test Accounts**
- [ ] Have at least 2 Google accounts ready for testing
- [ ] Both accounts can sign into the app
- [ ] Both users have completed profiles (name, photo, location, interests)

---

## 🎯 TEST SCENARIOS

### **Test 1: First-Time Chat Creation**

**Objective**: Verify that a new chat is created when two users have never chatted before.

**Steps**:
1. **User A**: Sign in to the app
2. **User A**: Navigate to Live Connect tab
3. **User A**: Find User B in the list
4. **User A**: Click the chat icon (💬) on User B's card
5. **User A**: Wait for loading indicator

**Expected Results**:
- ✅ Loading spinner appears
- ✅ Chat screen opens after ~1-2 seconds
- ✅ Chat is empty (no previous messages)
- ✅ User B's name appears in the app bar
- ✅ User B's photo appears in the app bar
- ✅ Message input field is ready

**Verify in Firebase Console**:
```
1. Go to Firestore Database
2. Navigate to: conversations/
3. Find document with ID: "userA_uid_userB_uid" (alphabetically sorted)
4. Check fields:
   ✅ participantIds: [userA_uid, userB_uid]
   ✅ participantNames: { userA_uid: "Name A", userB_uid: "Name B" }
   ✅ participantPhotos: { userA_uid: "url", userB_uid: "url" }
   ✅ lastMessage: null
   ✅ createdAt: (timestamp)
   ✅ isGroup: false
```

---

### **Test 2: Send First Message**

**Objective**: Verify messages can be sent in newly created chat.

**Steps**:
1. **User A**: In the chat screen, type "Hello!"
2. **User A**: Press send button
3. **User A**: Observe the message

**Expected Results**:
- ✅ Message appears immediately in chat
- ✅ Message is on the right side (sender)
- ✅ Message has timestamp
- ✅ No error messages appear

**Verify in Firebase Console**:
```
1. Navigate to: conversations/{chatId}/messages/
2. Find the message document
3. Check fields:
   ✅ senderId: "userA_uid"
   ✅ text: "Hello!"
   ✅ timestamp: (timestamp)
   ✅ type: "text"
   ✅ read: false
```

---

### **Test 3: Receive Message (Real-time)**

**Objective**: Verify User B receives messages in real-time.

**Steps**:
1. **User B**: Sign in on a different device/emulator
2. **User B**: Navigate to Messages tab
3. **User B**: Observe the conversation list

**Expected Results**:
- ✅ Chat with User A appears in list
- ✅ Last message shows: "Hello!"
- ✅ Unread count shows: 1
- ✅ User A's name and photo display correctly

**Steps (continued)**:
4. **User B**: Tap on the conversation
5. **User B**: View the message from User A

**Expected Results**:
- ✅ Message "Hello!" is visible
- ✅ Message is on the left side (receiver)
- ✅ Timestamp is shown

---

### **Test 4: Opening Existing Chat**

**Objective**: Verify that clicking message button opens existing chat instead of creating duplicate.

**Steps**:
1. **User B**: Navigate to Live Connect tab
2. **User B**: Find User A in the list
3. **User B**: Click the chat icon (💬) on User A's card
4. **User B**: Wait for screen to load

**Expected Results**:
- ✅ Same chat screen opens
- ✅ Previous message ("Hello!") is visible
- ✅ NO duplicate chat is created
- ✅ chatId remains the same

**Verify in Firebase Console**:
```
1. Check conversations/ collection
2. Confirm ONLY ONE conversation exists between User A and B
3. chatId should still be: "userA_uid_userB_uid"
```

---

### **Test 5: Simultaneous Chat Creation (Race Condition)**

**Objective**: Verify that only one chat is created when both users click at the exact same time.

**Setup**:
1. Delete the existing conversation from Firebase Console
2. Have both devices ready with Live Connect tab open

**Steps**:
1. **User A & User B**: At the exact same time, click the message button on each other's profile
2. Wait for both screens to load

**Expected Results**:
- ✅ Both users end up in the SAME chat
- ✅ Only ONE conversation document exists in Firestore
- ✅ chatId is identical for both users
- ✅ No errors occur
- ✅ No duplicate conversations created

**This tests the transaction logic!**

---

### **Test 6: Filter by Location**

**Objective**: Verify location filter works correctly.

**Steps**:
1. **User A**: Navigate to Live Connect tab
2. **User A**: Click filter icon (hamburger menu)
3. **User A**: Enable "Filter by Exact Location" toggle
4. **User A**: Click "Apply"

**Expected Results**:
- ✅ Only users in the same city appear
- ✅ Users from other cities are hidden
- ✅ Filter icon changes color (indicates active)

**To Test Properly**:
- Ensure User B has the same city as User A
- Create a Test User C with a different city
- User C should NOT appear when filter is enabled

---

### **Test 7: Filter by Interests**

**Objective**: Verify interest filter works correctly.

**Steps**:
1. **User A**: Click filter icon
2. **User A**: Enable "Filter by Interests" toggle
3. **User A**: Click "Change" to select interests
4. **User A**: Select "Business" and "Technology"
5. **User A**: Click "Save"
6. **User A**: Click "Apply" in filter modal

**Expected Results**:
- ✅ Only users with matching interests appear
- ✅ Users without "Business" or "Technology" are hidden
- ✅ Selected interests show as chips in filter modal

**To Test Properly**:
- Ensure User B has "Business" in their interests
- Create Test User D with only "Dating" interest
- User D should NOT appear when filter is enabled

---

### **Test 8: Combined Filters**

**Objective**: Verify multiple filters work together.

**Steps**:
1. **User A**: Enable BOTH filters:
   - Filter by Exact Location: ON
   - Filter by Interests: ON (select "Friendship")
2. **User A**: Click "Apply"

**Expected Results**:
- ✅ Only users that match BOTH criteria appear:
  - Same city as User A
  - AND have "Friendship" interest
- ✅ Empty state shows if no matches found

---

### **Test 9: Error Handling - No Internet**

**Objective**: Verify app handles offline gracefully.

**Steps**:
1. **User A**: Turn off WiFi and mobile data
2. **User A**: Click message button on a user
3. **User A**: Observe behavior

**Expected Results**:
- ✅ Loading indicator appears
- ✅ After timeout, error message shows
- ✅ Error message is user-friendly (e.g., "Failed to open chat: Check your connection")
- ✅ App doesn't crash
- ✅ User can dismiss error and try again

---

### **Test 10: Performance - Quick Navigation**

**Objective**: Verify chat opens quickly.

**Steps**:
1. **User A**: Click message button
2. **Measure time**: From click to chat screen appearing

**Expected Results**:
- ✅ Chat opens in < 2 seconds
- ✅ No lag or stuttering
- ✅ Smooth animation
- ✅ Loading spinner is visible during wait

---

### **Test 11: Message History Preservation**

**Objective**: Verify chat history is preserved across sessions.

**Steps**:
1. **User A**: Send 5 messages to User B
2. **User A**: Close the app completely
3. **User A**: Reopen the app
4. **User A**: Navigate to chat with User B

**Expected Results**:
- ✅ All 5 messages are still visible
- ✅ Messages appear in correct order
- ✅ Timestamps are preserved
- ✅ No data loss occurred

---

### **Test 12: Profile View from Chat**

**Objective**: Verify user can view full profile from chat screen.

**Steps**:
1. **User A**: Open chat with User B
2. **User A**: Tap on User B's name/photo in app bar
3. **User A**: View full profile

**Expected Results**:
- ✅ Profile view screen opens
- ✅ All user details are visible (interests, location, etc.)
- ✅ Can navigate back to chat
- ✅ Chat state is preserved

---

## 🐛 TROUBLESHOOTING COMMON ISSUES

### **Issue: "Missing Index" Error**

**Symptoms**:
```
FAILED_PRECONDITION: The query requires an index.
```

**Solution**:
1. Click the link in the error message
2. Firebase Console will open with pre-filled index
3. Click "Create Index"
4. Wait 1-2 minutes for index to build
5. Retry the operation

---

### **Issue: "Permission Denied" Error**

**Symptoms**:
```
PERMISSION_DENIED: Missing or insufficient permissions
```

**Solution**:
1. Verify security rules are published in Firebase Console
2. Check user is signed in
3. Verify user's UID is in participantIds array
4. Review Firestore Rules tab for any red errors

---

### **Issue: Duplicate Chats Created**

**Symptoms**:
- Two conversation documents for same two users

**Investigation**:
1. Check both chatIds - are they different?
2. If yes, check if UIDs are being sorted correctly
3. Review ChatService.generateChatId() implementation

**Solution**:
- Delete duplicate conversations from Firebase
- Ensure generateChatId() uses .sort()
- Verify transaction logic is in place

---

### **Issue: Loading Spinner Never Closes**

**Symptoms**:
- Loading indicator stays forever
- Chat screen never opens

**Investigation**:
1. Check console for errors
2. Verify Firebase connection is active
3. Check if transaction is completing

**Solution**:
1. Add timeout to loading indicator:
```dart
Future.delayed(Duration(seconds: 10), () {
  if (mounted) Navigator.pop(context); // Close loading
});
```
2. Review error logs
3. Check network connection

---

### **Issue: Messages Not Appearing**

**Symptoms**:
- Messages sent but not visible
- No error shown

**Investigation**:
1. Check Firestore Console - is message document created?
2. Check collection path is correct
3. Verify stream listener is active

**Solution**:
1. Verify collection path: `conversations/{chatId}/messages`
2. Check if EnhancedChatScreen is using correct chatId
3. Review message sending logic

---

## 📊 SUCCESS CRITERIA

Your Live Connect feature is working correctly if:

✅ **Chat Creation**
- New chats are created successfully
- No duplicate chats appear
- Transaction prevents race conditions

✅ **Real-time Messaging**
- Messages appear instantly
- Both users see the same conversation
- Timestamps are accurate

✅ **Filters**
- Location filter shows only same-city users
- Interest filter shows only matching interests
- Combined filters work correctly

✅ **Performance**
- Chat opens in < 2 seconds
- No lag or stuttering
- Smooth animations

✅ **Error Handling**
- Offline scenarios handled gracefully
- Clear error messages shown
- App doesn't crash

✅ **Security**
- Only participants can access chat
- Messages can't be spoofed
- Rules prevent unauthorized access

---

## 📝 TESTING LOG TEMPLATE

Use this template to track your testing:

```
Date: ___________
Tester: ___________

Test 1: First-Time Chat Creation
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 2: Send First Message
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 3: Receive Message
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 4: Opening Existing Chat
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 5: Race Condition
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 6: Filter by Location
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 7: Filter by Interests
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 8: Combined Filters
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 9: Error Handling
Status: [ ] Pass [ ] Fail
Notes: _______________________

Test 10: Performance
Status: [ ] Pass [ ] Fail
Notes: _______________________

Overall Status: [ ] All Pass [ ] Some Failures
Ready for Production: [ ] Yes [ ] No
```

---

## 🎉 FINAL VERIFICATION

Before deploying to production:

1. ✅ All 10 test scenarios pass
2. ✅ No console errors during normal operation
3. ✅ Firestore rules are published
4. ✅ All required indexes are created
5. ✅ App performs well on low-end devices
6. ✅ Offline mode works correctly
7. ✅ No security vulnerabilities
8. ✅ User experience is smooth

**If all checks pass, you're ready to launch! 🚀**
