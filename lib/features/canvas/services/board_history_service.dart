import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/canvas_element.dart';

/// One locally stored board checkpoint.
class BoardHistoryEntry {
  final String id;
  final String label;
  final DateTime savedAt;
  final List<Map<String, dynamic>> elements;

  const BoardHistoryEntry({
    required this.id,
    required this.label,
    required this.savedAt,
    required this.elements,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'savedAt': savedAt.millisecondsSinceEpoch,
    'elements': elements,
  };

  static BoardHistoryEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final rawElements = json['elements'];
    if (id == null || id.isEmpty || rawElements is! List) return null;
    final elements = <Map<String, dynamic>>[];
    for (final raw in rawElements) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final elementId = entry['id']?.toString();
      final data = entry['data'];
      if (elementId == null || elementId.isEmpty || data is! Map) continue;
      elements.add({'id': elementId, 'data': Map<String, dynamic>.from(data)});
    }
    if (elements.isEmpty) return null;
    return BoardHistoryEntry(
      id: id,
      label: json['label']?.toString() ?? 'Checkpoint',
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['savedAt'] as num?)?.toInt() ?? 0,
      ),
      elements: elements,
    );
  }
}

/// Stores a bounded number of version checkpoints on this device. Snapshots
/// live beside the app support data rather than SharedPreferences because a
/// board with images can be several megabytes.
class BoardHistoryService {
  static const int maxEntries = 8;
  static const int maxBytes = 8 * 1024 * 1024;

  final Future<Directory> Function() _directoryProvider;
  final Uuid _uuid;

  BoardHistoryService({
    Future<Directory> Function()? directoryProvider,
    Uuid uuid = const Uuid(),
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory,
       _uuid = uuid;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/board_history');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _fileFor(String boardId) async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/${Uri.encodeComponent(boardId)}.json');
  }

  Future<List<BoardHistoryEntry>> load(String boardId) async {
    try {
      final file = await _fileFor(boardId);
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      final entries = <BoardHistoryEntry>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final entry = BoardHistoryEntry.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (entry != null) entries.add(entry);
      }
      entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<BoardHistoryEntry?> save(
    String boardId,
    List<CanvasElement> elements, {
    String label = 'Manual checkpoint',
  }) async {
    if (elements.isEmpty) return null;
    final snapshot = BoardHistoryEntry(
      id: _uuid.v4(),
      label: label,
      savedAt: DateTime.now(),
      elements: [
        for (final element in elements)
          {'id': element.id, 'data': element.toMap()},
      ],
    );
    final encoded = jsonEncode(snapshot.toJson());
    if (encoded.length > maxBytes) return null;
    final previous = await load(boardId);
    final next = [snapshot, ...previous].take(maxEntries).toList();
    final file = await _fileFor(boardId);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode([for (final entry in next) entry.toJson()]),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
    return snapshot;
  }

  Future<void> delete(String boardId, String entryId) async {
    final entries = await load(boardId);
    final next = entries.where((entry) => entry.id != entryId).toList();
    final file = await _fileFor(boardId);
    if (next.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode([for (final entry in next) entry.toJson()]),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
