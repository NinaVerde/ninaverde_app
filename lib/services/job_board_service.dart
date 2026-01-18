// lib/services/job_board_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/job_listing_model.dart';

/// Service for managing job listings and applications
class JobBoardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String jobsCollection = 'job_listings';
  static const String applicationsCollection = 'job_applications';

  /// Create or update job listing
  Future<String> saveJobListing(JobListing job) async {
    if (job.id.isEmpty) {
      final docRef = await _firestore.collection(jobsCollection).add(job.toMap());
      return docRef.id;
    } else {
      await _firestore.collection(jobsCollection).doc(job.id).set(job.toMap(), SetOptions(merge: true));
      return job.id;
    }
  }

  /// Get active job listings stream
  Stream<List<JobListing>> getActiveJobsStream({JobCategory? category, bool? isFeatured}) {
    var query = _firestore.collection(jobsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('postedAt', descending: true);
    
    if (category != null) {
      query = query.where('category', isEqualTo: category.name) as Query<Map<String, dynamic>>;
    }
    
    if (isFeatured != null) {
      query = query.where('isFeatured', isEqualTo: isFeatured) as Query<Map<String, dynamic>>;
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => JobListing.fromFirestore(doc)).toList();
    });
  }

  /// Get jobs posted by specific user
  Stream<List<JobListing>> getMyJobsStream(String userId) {
    return _firestore
        .collection(jobsCollection)
        .where('postedBy', isEqualTo: userId)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => JobListing.fromFirestore(doc)).toList();
    });
  }

  /// Increment view count
  Future<void> incrementViewCount(String jobId) async {
    await _firestore.collection(jobsCollection).doc(jobId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Submit job application
  Future<String> submitApplication(JobApplication application) async {
    // Add application
    final docRef = await _firestore
        .collection(applicationsCollection)
        .add(application.toMap());
    
    // Increment application count on job listing
    await _firestore.collection(jobsCollection).doc(application.jobId).update({
      'applicationCount': FieldValue.increment(1),
    });
    
    // Send notification to job poster
    await _sendNotification(
      'New Application Received',
      '${application.applicantName} applied for ${application.jobTitle}',
    );
    
    return docRef.id;
  }

  /// Get applications for a job
  Stream<List<JobApplication>> getJobApplicationsStream(String jobId) {
    return _firestore
        .collection(applicationsCollection)
        .where('jobId', isEqualTo: jobId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => JobApplication.fromFirestore(doc)).toList();
    });
  }

  /// Get my applications
  Stream<List<JobApplication>> getMyApplicationsStream(String userId) {
    return _firestore
        .collection(applicationsCollection)
        .where('applicantId', isEqualTo: userId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => JobApplication.fromFirestore(doc)).toList();
    });
  }

  /// Update application status
  Future<void> updateApplicationStatus(String applicationId, ApplicationStatus status, {String? notes}) async {
    final updateData = <String, dynamic>{
      'status': status.name,
    };
    
    if (status == ApplicationStatus.reviewing) {
      updateData['reviewedAt'] = FieldValue.serverTimestamp();
    }
    if (status == ApplicationStatus.interviewed) {
      updateData['interviewedAt'] = FieldValue.serverTimestamp();
    }
    if (notes != null) {
      updateData[status == ApplicationStatus.rejected ? 'rejectionReason' : 'reviewNotes'] = notes;
    }
    
    await _firestore.collection(applicationsCollection).doc(applicationId).update(updateData);
    
    // Notify applicant
    await _sendNotification(
      'Application Update',
      'Your application status has been updated to: ${status.name}',
    );
  }

  /// Delete job listing
  Future<void> deleteJobListing(String jobId) async {
    await _firestore.collection(jobsCollection).doc(jobId).delete();
    
    // Optionally delete associated applications
    final applicationsSnapshot = await _firestore
        .collection(applicationsCollection)
        .where('jobId', isEqualTo: jobId)
        .get();
    
    for (final doc in applicationsSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Search jobs
  Future<List<JobListing>> searchJobs(String query) async {
    // Note: This is a simple implementation. For production, use Algolia or similar
    final snapshot = await _firestore
        .collection(jobsCollection)
        .where('isActive', isEqualTo: true)
        .get();
    
    return snapshot.docs
        .map((doc) => JobListing.fromFirestore(doc))
        .where((job) =>
            job.title.toLowerCase().contains(query.toLowerCase()) ||
            job.description.toLowerCase().contains(query.toLowerCase()) ||
            job.company.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Get job statistics
  Future<Map<String, int>> getJobStats({String? userId}) async {
    Query<Map<String, dynamic>> query = _firestore.collection(jobsCollection);
    
    if (userId != null) {
      query = query.where('postedBy', isEqualTo: userId);
    }
    
    final snapshot = await query.get();
    final jobs = snapshot.docs.map((doc) => JobListing.fromFirestore(doc)).toList();
    
    return {
      'total': jobs.length,
      'active': jobs.where((j) => j.isActive).length,
      'inactive': jobs.where((j) => !j.isActive).length,
      'featured': jobs.where((j) => j.isFeatured).length,
      'totalApplications': jobs.fold(0, (total, j) => total + j.applicationCount),
      'totalViews': jobs.fold(0, (total, j) => total + j.viewCount),
    };
  }

  /// Send notification
  Future<void> _sendNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'job_board',
      'Job Board',
      channelDescription: 'Job posting and application notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
