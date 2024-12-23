import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

enum ActivityType {
  study,
  assignment,
  exam,
  task,
  lesson,
}

class Activity {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final ActivityType type;
  final DateTime? completedAt;

  Activity({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.scheduledTime,
    required this.type,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'type': 'ActivityType.${type.name}',
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      description: json['description'],
      scheduledTime: (json['scheduledTime'] as Timestamp).toDate(),
      type: ActivityType.values.firstWhere(
        (e) => 'ActivityType.${e.name}' == json['type'],
      ),
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory Activity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      userId: data['userId'],
      title: data['title'],
      description: data['description'],
      scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
      type: ActivityType.values.firstWhere(
        (e) => 'ActivityType.${e.name}' == data['type'],
      ),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Activity copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? scheduledTime,
    ActivityType? type,
    DateTime? completedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Activity>> streamUserActivities(String userId) {
    try {
      developer.log('Attempting to stream activities for user: $userId');

      final query = _firestore
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .orderBy('scheduledTime', descending: false);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                Activity activity = Activity.fromFirestore(doc);

                // Check if activity is completed and should be deleted
                if (activity.completedAt != null) {
                  final deleteAfter =
                      activity.completedAt!.add(Duration(hours: 1));
                  if (DateTime.now().isAfter(deleteAfter)) {
                    // Delete the activity
                    deleteActivity(activity.id);
                    return null;
                  }
                }

                // Check if activity is finished but not marked as completed
                if (DateTime.now().isAfter(activity.scheduledTime) &&
                    activity.completedAt == null) {
                  // Mark activity as completed
                  markActivityAsCompleted(activity.id);
                }

                return activity;
              } catch (e) {
                developer.log('Error parsing activity document: ${doc.id}',
                    error: e);
                rethrow;
              }
            })
            .where((activity) => activity != null)
            .cast<Activity>()
            .toList();
      }).handleError((error) {
        developer.log('Error in activities stream', error: error);
        throw error;
      });
    } catch (e) {
      developer.log('Error setting up activities stream', error: e);
      rethrow;
    }
  }

  Future<void> markActivityAsCompleted(String activityId) async {
    try {
      await _firestore.collection('activities').doc(activityId).update({
        'completedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      developer.log('Error marking activity as completed', error: e);
      rethrow;
    }
  }

  Future<void> deleteActivity(String activityId) async {
    try {
      await _firestore.collection('activities').doc(activityId).delete();
      developer.log('Activity deleted successfully: $activityId');
    } catch (e) {
      developer.log('Error deleting activity', error: e);
      rethrow;
    }
  }

  Future<void> addActivity(Activity activity) async {
    try {
      developer.log('Adding new activity: ${activity.title}');
      await _firestore
          .collection('activities')
          .doc(activity.id)
          .set(activity.toJson());
    } catch (e) {
      developer.log('Error adding activity', error: e);
      rethrow;
    }
  }

  Future<void> updateActivity(Activity activity) async {
    try {
      await _firestore
          .collection('activities')
          .doc(activity.id)
          .update(activity.toJson());
    } catch (e) {
      developer.log('Error updating activity', error: e);
      rethrow;
    }
  }
}
