class LockDeviceInfo {
  final String deviceId;
  final String deviceName;
  final String hardware;
  final String? ownerUid;
  final bool isOnline;
  final bool isLocked;
  final Map<String, bool> authorizedUsers;
  final String? myRequestStatus; // null, 'PENDING', 'APPROVED', 'REJECTED'

  const LockDeviceInfo({
    required this.deviceId,
    required this.deviceName,
    this.hardware = 'ESP32 DevKit V4',
    this.ownerUid,
    this.isOnline = false,
    this.isLocked = true,
    this.authorizedUsers = const {},
    this.myRequestStatus,
  });

  bool isOwner(String? uid) => uid != null && ownerUid == uid;
  bool isMember(String? uid) =>
      uid != null &&
      (authorizedUsers[uid] == true || isOwner(uid) || myRequestStatus == 'APPROVED');
  bool isPending(String? uid) => !isMember(uid) && myRequestStatus == 'PENDING';
  bool isRejected(String? uid) => !isMember(uid) && myRequestStatus == 'REJECTED';

  factory LockDeviceInfo.fromMap(String id, Map<dynamic, dynamic> map, {String? currentUid}) {
    final meta = map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : <String, dynamic>{};
    final status = map['status'] is Map ? Map<String, dynamic>.from(map['status'] as Map) : <String, dynamic>{};
    final requests = map['requests'] is Map ? Map<String, dynamic>.from(map['requests'] as Map) : <String, dynamic>{};

    final members = <String, bool>{};
    final rawAuth = meta['authorizedUsers'];
    if (rawAuth is Map) {
      rawAuth.forEach((k, v) {
        if (v == true) members[k.toString()] = true;
      });
    }

    String? reqStatus;
    if (currentUid != null && requests[currentUid] is Map) {
      final reqMap = requests[currentUid] as Map;
      reqStatus = reqMap['status']?.toString();
    }

    return LockDeviceInfo(
      deviceId: id,
      deviceName: meta['deviceName'] as String? ?? 'Smart Door Lock',
      hardware: meta['hardware'] as String? ?? 'ESP32 DevKit V4',
      ownerUid: meta['ownerUid'] as String?,
      isOnline: status['isOnline'] == true,
      isLocked: status['isLocked'] != false,
      authorizedUsers: members,
      myRequestStatus: reqStatus,
    );
  }
}
