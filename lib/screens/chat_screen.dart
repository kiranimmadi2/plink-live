// THIS FILE IS DEPRECATED - DO NOT USE
// Use enhanced_chat_screen.dart instead
// This file is kept only to prevent import errors during migration

import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/post_model.dart';

@deprecated
class ChatScreen extends StatelessWidget {
  final UserProfile otherUser;
  final PostModel? postContext;
  
  const ChatScreen({
    Key? key,
    required this.otherUser,
    this.postContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deprecated Screen'),
      ),
      body: const Center(
        child: Text(
          'This screen is deprecated.\nUse EnhancedChatScreen instead.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      ),
    );
  }
}