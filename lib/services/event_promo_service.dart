import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_promo_model.dart';

class EventPromoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<EventPromo>> activePromos() {
    return _db
        .collection('events_promotions')
        .where('active', isEqualTo: true)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => EventPromo.fromFirestore(doc)).toList());
  }
}
