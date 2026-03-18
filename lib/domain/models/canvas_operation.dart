class CanvasOperation {
  final String opId;
  final String boardId;
  final String objectId;
  final String type;
  final String action;
  final String data;
  final String timestamp; // HLC as ISO8601 string or specific HLC string format
  final String clientId;

  CanvasOperation({
    required this.opId,
    required this.boardId,
    required this.objectId,
    required this.type,
    required this.action,
    required this.data,
    required this.timestamp,
    required this.clientId,
  });

  factory CanvasOperation.fromMap(Map<String, dynamic> map, String id) {
    return CanvasOperation(
      opId: id,
      boardId: map['boardId'] ?? '',
      objectId: map['objectId'] ?? '',
      type: map['type'] ?? '',
      action: map['action'] ?? '',
      data: map['data'] ?? '',
      timestamp: map['timestamp'] ?? '',
      clientId: map['clientId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardId': boardId,
      'objectId': objectId,
      'type': type,
      'action': action,
      'data': data,
      'timestamp': timestamp,
      'clientId': clientId,
    };
  }
}
