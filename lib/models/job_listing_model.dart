// lib/models/job_listing_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Job type classification
enum JobType {
  fullTime,
  partTime,
  contract,
  temporary,
  internship,
}

/// Job category
enum JobCategory {
  kitchen,
  service,
  management,
  delivery,
  administration,
  marketing,
  other,
}

/// Application status
enum ApplicationStatus {
  pending,
  reviewing,
  interviewed,
  offered,
  accepted,
  rejected,
}

/// Job listing model - supports both internal and external postings
class JobListing {
  final String id;final String title;
  final String company;  // "Nina Verde" or external business
  final String postedBy;  // User ID
  final String? postedByName;
  
  // Job details
  final String description;
  final JobType jobType;
  final JobCategory category;
  final String location;
  final String? salaryRange;
  final List<String> requirements;
  final List<String> responsibilities;
  final List<String> benefits;
  
  // Application info
  final String applicationEmail;
  final String? applicationUrl;
  final String? contactPhone;
  
  // Status & visibility
  final bool isActive;
  final bool isFeatured;  // Promoted listing
  final bool isExternal;  // Posted by external business
  
  // Metadata
  final DateTime postedAt;
  final DateTime? expiresAt;
  final int viewCount;
  final int applicationCount;
  
  JobListing({
    required this.id,
    required this.title,
    required this.company,
    required this.postedBy,
    this.postedByName,
    required this.description,
    required this.jobType,
    required this.category,
    required this.location,
    this.salaryRange,
    this.requirements = const [],
    this.responsibilities = const [],
    this.benefits = const [],
    required this.applicationEmail,
    this.applicationUrl,
    this.contactPhone,
    this.isActive = true,
    this.isFeatured = false,
    this.isExternal = false,
    required this.postedAt,
    this.expiresAt,
    this.viewCount = 0,
    this.applicationCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'description': description,
      'jobType': jobType.name,
      'category': category.name,
      'location': location,
      'salaryRange': salaryRange,
      'requirements': requirements,
      'responsibilities': responsibilities,
      'benefits': benefits,
      'applicationEmail': applicationEmail,
      'applicationUrl': applicationUrl,
      'contactPhone': contactPhone,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'isExternal': isExternal,
      'postedAt': Timestamp.fromDate(postedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'viewCount': viewCount,
      'applicationCount': applicationCount,
    };
  }

  factory JobListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return JobListing(
      id: doc.id,
      title: data['title'] ?? '',
      company: data['company'] ?? '',
      postedBy: data['postedBy'] ?? '',
      postedByName: data['postedByName'],
      description: data['description'] ?? '',
      jobType: JobType.values.firstWhere(
        (e) => e.name == data['jobType'],
        orElse: () => JobType.fullTime,
      ),
      category: JobCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => JobCategory.other,
      ),
      location: data['location'] ?? '',
      salaryRange: data['salaryRange'],
      requirements: (data['requirements'] as List?)?.cast<String>() ?? [],
      responsibilities: (data['responsibilities'] as List?)?.cast<String>() ?? [],
      benefits: (data['benefits'] as List?)?.cast<String>() ?? [],
      applicationEmail: data['applicationEmail'] ?? '',
      applicationUrl: data['applicationUrl'],
      contactPhone: data['contactPhone'],
      isActive: data['isActive'] ?? true,
      isFeatured: data['isFeatured'] ?? false,
      isExternal: data['isExternal'] ?? false,
      postedAt: parseTimestamp(data['postedAt']) ?? DateTime.now(),
      expiresAt: parseTimestamp(data['expiresAt']),
      viewCount: data['viewCount'] ?? 0,
      applicationCount: data['applicationCount'] ?? 0,
    );
  }
}

/// Job application model
class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String applicantId;
  final String applicantName;
  final String applicantEmail;
  final String applicantPhone;
  
  // Application details
  final String coverLetter;
  final String? resumeUrl;
  final Map<String, String>? additionalInfo;
  
  // Status tracking
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final DateTime? interviewedAt;
  final String? reviewNotes;
  final String? rejectionReason;
  
  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.applicantId,
    required this.applicantName,
    required this.applicantEmail,
    required this.applicantPhone,
    required this.coverLetter,
    this.resumeUrl,
    this.additionalInfo,
    this.status = ApplicationStatus.pending,
    required this.appliedAt,
    this.reviewedAt,
    this.interviewedAt,
    this.reviewNotes,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'applicantId': applicantId,
      'applicantName': applicantName,
      'applicantEmail': applicantEmail,
      'applicantPhone': applicantPhone,
      'coverLetter': coverLetter,
      'resumeUrl': resumeUrl,
      'additionalInfo': additionalInfo,
      'status': status.name,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'interviewedAt': interviewedAt != null ? Timestamp.fromDate(interviewedAt!) : null,
      'reviewNotes': reviewNotes,
      'rejectionReason': rejectionReason,
    };
  }

  factory JobApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic ts) {
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return JobApplication(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      applicantId: data['applicantId'] ?? '',
      applicantName: data['applicantName'] ?? '',
      applicantEmail: data['applicantEmail'] ?? '',
      applicantPhone: data['applicantPhone'] ?? '',
      coverLetter: data['coverLetter'] ?? '',
      resumeUrl: data['resumeUrl'],
      additionalInfo: (data['additionalInfo'] as Map?)?.cast<String, String>(),
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ApplicationStatus.pending,
      ),
      appliedAt: parseTimestamp(data['appliedAt']) ?? DateTime.now(),
      reviewedAt: parseTimestamp(data['reviewedAt']),
      interviewedAt: parseTimestamp(data['interviewedAt']),
      reviewNotes: data['reviewNotes'],
      rejectionReason: data['rejectionReason'],
    );
  }
}
