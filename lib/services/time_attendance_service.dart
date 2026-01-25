import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/time_log_model.dart';

class TimeAttendanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Nina Verde Coordinates (Replace with exact location)
  // Example: Managua, Nicaragua
  static const double _targetLat = 12.13282; 
  static const double _targetLng = -86.2504;
  static const double _maxRangeMeters = 200.0; // 200 meters radius

  /// Get the current active time log for a user (if they are clocked in)
  static Stream<TimeLogModel?> getCurrentActiveLog(String userId) {
    return _db
        .collection('time_logs')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TimeLogStatus.active.name)
        .limit(1)
        .snapshots()
        .map((snapshot) {
            if (snapshot.docs.isEmpty) return null;
            return TimeLogModel.fromFirestore(snapshot.docs.first);
        });
  }
  
  /// Check if user is within range
  static Future<bool> isWithinRange() async {
      final hasPermission = await _handlePermission();
      if (!hasPermission) return false;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      final distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, _targetLat, _targetLng);
          
      // Debug print
      // print('Distance to Nina Verde: $distance meters');
      
      return distance <= _maxRangeMeters;
  }
  
  static Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }
  
  /// Clock In
  static Future<void> clockIn(String userId, {String? shiftId}) async {
      // Get real location for record
      final position = await Geolocator.getCurrentPosition();
      final location = GeoPoint(position.latitude, position.longitude);
      
      final doc = _db.collection('time_logs').doc();
      final log = TimeLogModel(
          id: doc.id,
          userId: userId,
          shiftId: shiftId,
          clockInTime: DateTime.now(),
          clockInLocation: location,
          status: TimeLogStatus.active,
          systemNotes: 'Verifed Geofence Check'
      );
      
      await doc.set(log.toMap());
  }
  
  /// Clock Out
  static Future<void> clockOut(String logId) async {
      // Get real location for record
      final position = await Geolocator.getCurrentPosition();
      final location = GeoPoint(position.latitude, position.longitude);
      
      final now = DateTime.now();
      
      final docRef = _db.collection('time_logs').doc(logId);
      final doc = await docRef.get();
      if (!doc.exists) return;
      
      final start = (doc.data()?['clockInTime'] as Timestamp).toDate();
      final hours = now.difference(start).inMinutes / 60.0;
      
      await docRef.update({
          'clockOutTime': Timestamp.fromDate(now),
          'clockOutLocation': location,
          'status': TimeLogStatus.completed.name,
          'hoursWorked': hours,
      });
  }
}
