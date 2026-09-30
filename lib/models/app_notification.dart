enum NotificationType {
  agentAssigned,
  agentAccepted,
  etaUpdated,
  serviceStarted,
  serviceCompleted,
  requestCancelled,
  newOffer,
  requestAssigned,
  newRequest,
  general;

  static NotificationType fromString(String? typeStr) {
    switch (typeStr?.trim().toLowerCase()) {
      case 'agent_assigned':
        return NotificationType.agentAssigned;
      case 'agent_accepted':
        return NotificationType.agentAccepted;
      case 'eta_updated':
        return NotificationType.etaUpdated;
      case 'service_started':
        return NotificationType.serviceStarted;
      case 'service_completed':
        return NotificationType.serviceCompleted;
      case 'request_cancelled':
        return NotificationType.requestCancelled;
      case 'new_offer':
        return NotificationType.newOffer;
      case 'request_assigned':
        return NotificationType.requestAssigned;
      case 'new_request':
        return NotificationType.newRequest;
      default:
        return NotificationType.general;
    }
  }

  String toDbString() {
    switch (this) {
      case NotificationType.agentAssigned:
        return 'agent_assigned';
      case NotificationType.agentAccepted:
        return 'agent_accepted';
      case NotificationType.etaUpdated:
        return 'eta_updated';
      case NotificationType.serviceStarted:
        return 'service_started';
      case NotificationType.serviceCompleted:
        return 'service_completed';
      case NotificationType.requestCancelled:
        return 'request_cancelled';
      case NotificationType.newOffer:
        return 'new_offer';
      case NotificationType.requestAssigned:
        return 'request_assigned';
      case NotificationType.newRequest:
        return 'new_request';
      case NotificationType.general:
        return 'general';
    }
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String? requestId;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    this.requestId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      requestId: map['request_id']?.toString(),
      type: NotificationType.fromString(map['type']?.toString()),
      title: map['title']?.toString() ?? 'Notification',
      body: map['body']?.toString() ?? map['message']?.toString() ?? '',
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      if (requestId != null) 'request_id': requestId,
      'type': type.toDbString(),
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? requestId,
    NotificationType? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      requestId: requestId ?? this.requestId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ isRead.hashCode;
}
