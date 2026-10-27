/// Data model representing a pending or processed access request to link to the smart lock.
class AccessRequest {
  final String uid;
  final String email;
  final DateTime requestedAt;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'

  const AccessRequest({
    required this.uid,
    required this.email,
    required this.requestedAt,
    required this.status,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED' || status == 'REVOKED';
  bool get isRevoked => status == 'REVOKED';

  factory AccessRequest.fromJson(Map<String, dynamic> json, {required String uid}) {
    DateTime parseTime(Object? v) {
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      return DateTime.now();
    }

    return AccessRequest(
      uid: json['uid'] is String ? json['uid'] as String : uid,
      email: json['email'] is String ? json['email'] as String : 'Anonymous',
      requestedAt: parseTime(json['requestedAt']),
      status: json['status'] is String ? json['status'] as String : 'PENDING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'status': status,
    };
  }
}
