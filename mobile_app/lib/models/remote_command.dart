enum RemoteAction {
  lock,
  unlock,
  clearAlarm,
  ping,
}

enum RemoteCommandStatus {
  pending,
  processing,
  executed,
  rejected,
  failed,
}

class RemoteCommand {
  final String commandId;
  final RemoteAction action;
  final String requestedBy;
  final DateTime requestedAt;
  final RemoteCommandStatus status;
  final DateTime? executedAt;
  final String? failureReason;

  const RemoteCommand({
    required this.commandId,
    required this.action,
    required this.requestedBy,
    required this.requestedAt,
    this.status = RemoteCommandStatus.pending,
    this.executedAt,
    this.failureReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'action': action.name.toUpperCase(),
      'requestedBy': requestedBy,
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'status': status.name.toUpperCase(),
      'executedAt': executedAt?.millisecondsSinceEpoch,
      'failureReason': failureReason,
    };
  }

  factory RemoteCommand.fromJson(Map<String, dynamic> json) {
    RemoteAction parseAction(String? val) {
      switch (val?.toUpperCase()) {
        case 'LOCK':
          return RemoteAction.lock;
        case 'UNLOCK':
          return RemoteAction.unlock;
        case 'CLEAR_ALARM':
          return RemoteAction.clearAlarm;
        default:
          return RemoteAction.ping;
      }
    }

    RemoteCommandStatus parseStatus(String? val) {
      switch (val?.toUpperCase()) {
        case 'PROCESSING':
          return RemoteCommandStatus.processing;
        case 'EXECUTED':
          return RemoteCommandStatus.executed;
        case 'REJECTED':
          return RemoteCommandStatus.rejected;
        case 'FAILED':
          return RemoteCommandStatus.failed;
        default:
          return RemoteCommandStatus.pending;
      }
    }

    return RemoteCommand(
      commandId: json['commandId'] as String? ?? '',
      action: parseAction(json['action'] as String?),
      requestedBy: json['requestedBy'] as String? ?? '',
      requestedAt: DateTime.fromMillisecondsSinceEpoch(json['requestedAt'] as int? ?? 0),
      status: parseStatus(json['status'] as String?),
      executedAt: json['executedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['executedAt'] as int)
          : null,
      failureReason: json['failureReason'] as String?,
    );
  }
}
