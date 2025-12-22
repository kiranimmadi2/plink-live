import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user projects (organized groups of chats/tasks)
class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ==================== PROJECTS ====================

  /// Get all projects for the current user
  Future<List<ProjectItem>> getProjects() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ProjectItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting projects: $e');
      return [];
    }
  }

  /// Get a single project by ID
  Future<ProjectItem?> getProject(String projectId) async {
    if (_userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .get();

      if (doc.exists) {
        return ProjectItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting project: $e');
      return null;
    }
  }

  /// Create a new project
  Future<String?> createProject({
    required String name,
    String? description,
    required String iconName,
    required String colorHex,
  }) async {
    if (_userId == null) return null;

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .add({
        'name': name,
        'description': description ?? '',
        'iconName': iconName,
        'colorHex': colorHex,
        'chatCount': 0,
        'taskCount': 0,
        'completedTasks': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating project: $e');
      return null;
    }
  }

  /// Update a project
  Future<bool> updateProject({
    required String projectId,
    String? name,
    String? description,
    String? iconName,
    String? colorHex,
  }) async {
    if (_userId == null) return false;

    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (iconName != null) updateData['iconName'] = iconName;
      if (colorHex != null) updateData['colorHex'] = colorHex;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error updating project: $e');
      return false;
    }
  }

  /// Delete a project
  Future<bool> deleteProject(String projectId) async {
    if (_userId == null) return false;

    try {
      // Delete all tasks in the project first
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .get();

      for (final doc in tasksSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all chats linked to the project
      final chatsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('chats')
          .get();

      for (final doc in chatsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the project itself
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .delete();

      return true;
    } catch (e) {
      debugPrint('Error deleting project: $e');
      return false;
    }
  }

  // ==================== PROJECT TASKS ====================

  /// Get all tasks for a project
  Future<List<ProjectTask>> getProjectTasks(String projectId) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ProjectTask.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting project tasks: $e');
      return [];
    }
  }

  /// Add a task to a project
  Future<String?> addTask({
    required String projectId,
    required String title,
    String? description,
    String? priority, // 'low', 'medium', 'high'
    DateTime? dueDate,
  }) async {
    if (_userId == null) return null;

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .add({
        'title': title,
        'description': description ?? '',
        'priority': priority ?? 'medium',
        'isCompleted': false,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update task count
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .update({
        'taskCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding task: $e');
      return null;
    }
  }

  /// Toggle task completion
  Future<bool> toggleTaskCompletion(String projectId, String taskId, bool isCompleted) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(taskId)
          .update({'isCompleted': isCompleted});

      // Update completed count
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .update({
        'completedTasks': FieldValue.increment(isCompleted ? 1 : -1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error toggling task: $e');
      return false;
    }
  }

  /// Delete a task
  Future<bool> deleteTask(String projectId, String taskId) async {
    if (_userId == null) return false;

    try {
      // Check if task was completed
      final taskDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(taskId)
          .get();

      final wasCompleted = taskDoc.data()?['isCompleted'] == true;

      // Delete the task
      await taskDoc.reference.delete();

      // Update counts
      final updates = <String, dynamic>{
        'taskCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (wasCompleted) {
        updates['completedTasks'] = FieldValue.increment(-1);
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .update(updates);

      return true;
    } catch (e) {
      debugPrint('Error deleting task: $e');
      return false;
    }
  }

  // ==================== PROJECT CHATS ====================

  /// Get all chats linked to a project
  Future<List<ProjectChat>> getProjectChats(String projectId) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('chats')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ProjectChat.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting project chats: $e');
      return [];
    }
  }

  /// Link a chat to a project
  Future<bool> linkChatToProject({
    required String projectId,
    required String conversationId,
    required String chatTitle,
    String? otherUserName,
    String? otherUserPhoto,
  }) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('chats')
          .doc(conversationId)
          .set({
        'conversationId': conversationId,
        'chatTitle': chatTitle,
        'otherUserName': otherUserName,
        'otherUserPhoto': otherUserPhoto,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Update chat count
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .update({
        'chatCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error linking chat to project: $e');
      return false;
    }
  }

  /// Unlink a chat from a project
  Future<bool> unlinkChatFromProject(String projectId, String conversationId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .collection('chats')
          .doc(conversationId)
          .delete();

      // Update chat count
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .doc(projectId)
          .update({
        'chatCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error unlinking chat from project: $e');
      return false;
    }
  }

  // ==================== DEFAULT PROJECTS ====================

  /// Create default projects for new users
  Future<void> createDefaultProjects() async {
    if (_userId == null) return;

    try {
      // Check if user already has projects
      final existing = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('projects')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return;

      // Create default projects
      final defaults = [
        {'name': 'Shopping Assistant', 'description': 'Track products & deals', 'iconName': 'shopping_bag', 'colorHex': '#E91E63'},
        {'name': 'Job Search', 'description': 'Find opportunities', 'iconName': 'work', 'colorHex': '#2196F3'},
        {'name': 'Home Renovation', 'description': 'Ideas & contractors', 'iconName': 'home_repair_service', 'colorHex': '#FF9800'},
        {'name': 'Travel Planning', 'description': 'Destinations & bookings', 'iconName': 'flight', 'colorHex': '#009688'},
      ];

      for (final project in defaults) {
        await createProject(
          name: project['name']!,
          description: project['description'],
          iconName: project['iconName']!,
          colorHex: project['colorHex']!,
        );
      }
    } catch (e) {
      debugPrint('Error creating default projects: $e');
    }
  }
}

// ==================== DATA MODELS ====================

class ProjectItem {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String colorHex;
  final int chatCount;
  final int taskCount;
  final int completedTasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectItem({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.colorHex,
    required this.chatCount,
    required this.taskCount,
    required this.completedTasks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectItem(
      id: doc.id,
      name: data['name'] ?? 'Untitled Project',
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'folder',
      colorHex: data['colorHex'] ?? '#9E9E9E',
      chatCount: data['chatCount'] ?? 0,
      taskCount: data['taskCount'] ?? 0,
      completedTasks: data['completedTasks'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get progress => taskCount > 0 ? completedTasks / taskCount : 0;
}

class ProjectTask {
  final String id;
  final String title;
  final String description;
  final String priority;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;

  ProjectTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.isCompleted,
    this.dueDate,
    required this.createdAt,
  });

  factory ProjectTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectTask(
      id: doc.id,
      title: data['title'] ?? 'Untitled Task',
      description: data['description'] ?? '',
      priority: data['priority'] ?? 'medium',
      isCompleted: data['isCompleted'] ?? false,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ProjectChat {
  final String id;
  final String conversationId;
  final String chatTitle;
  final String? otherUserName;
  final String? otherUserPhoto;
  final DateTime addedAt;

  ProjectChat({
    required this.id,
    required this.conversationId,
    required this.chatTitle,
    this.otherUserName,
    this.otherUserPhoto,
    required this.addedAt,
  });

  factory ProjectChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectChat(
      id: doc.id,
      conversationId: data['conversationId'] ?? doc.id,
      chatTitle: data['chatTitle'] ?? 'Untitled Chat',
      otherUserName: data['otherUserName'],
      otherUserPhoto: data['otherUserPhoto'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
