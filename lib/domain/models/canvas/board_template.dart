import 'package:flutter/material.dart';

import 'canvas_element.dart';

/// A curated starting layout.
///
/// Element maps use the same schema as [CanvasElement.toMap], plus an `id`
/// placeholder that `CanvasImportElements` remaps so connectors between
/// template elements stay attached after import.
class BoardTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<Map<String, dynamic>> elements;

  const BoardTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.category = 'General',
    this.elements = const [],
  });

  bool get isEmpty => elements.isEmpty;

  Offset get center {
    var sum = Offset.zero;
    var count = 0;
    for (final element in elements) {
      final x = (element['cx'] as num?)?.toDouble();
      final y = (element['cy'] as num?)?.toDouble();
      if (x == null || y == null) continue;
      sum += Offset(x, y);
      count++;
    }
    return count == 0 ? Offset.zero : sum / count.toDouble();
  }

  /// Validates a template file. Unknown element types throw [ArgumentError]
  /// instead of producing a half-imported board.
  factory BoardTemplate.fromJson(Map<String, dynamic> json) {
    final rawElements = json['elements'];
    if (rawElements is! List) {
      throw ArgumentError('Template elements must be a list');
    }
    final elements = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (var i = 0; i < rawElements.length; i++) {
      final raw = rawElements[i];
      if (raw is! Map) {
        throw ArgumentError('Template element $i is not an object');
      }
      final map = Map<String, dynamic>.from(raw);
      final placeholder = (map['id'] as String?) ?? 'element_$i';
      if (!ids.add(placeholder)) {
        throw ArgumentError('Duplicate template element id: $placeholder');
      }
      final payload = Map<String, dynamic>.from(map)..remove('id');
      CanvasElement.fromMap(placeholder, payload);
      elements.add(map);
    }
    return BoardTemplate(
      id: json['id'] as String? ?? 'template',
      name: json['name'] as String? ?? 'Template',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      elements: elements,
    );
  }
}

Map<String, dynamic> _frame(
  String id, {
  double cx = 0,
  double cy = 0,
  double width = 1180,
  double height = 720,
  int color = 0xFF64748B,
}) => {
  'id': id,
  'type': 'frame',
  'z': 0,
  'cx': cx,
  'cy': cy,
  'width': width,
  'height': height,
  'title': '',
  'color': color,
  'cornerRadius': 20,
};

Map<String, dynamic> _sticky(
  String id,
  double cx,
  double cy,
  String text, {
  int color = 0xFFFFF3B0,
  double width = 210,
  double height = 148,
  double rotation = 0,
  double fontSize = 15,
}) => {
  'id': id,
  'type': 'sticky_note',
  'z': 4,
  'cx': cx,
  'cy': cy,
  'width': width,
  'height': height,
  'text': text,
  'color': color,
  'rotation': rotation,
  'fontSize': fontSize,
  'fontWeight': 500,
  'textColor': 0xFF1E293B,
  'textAlign': 'left',
  'autoSize': false,
};

Map<String, dynamic> _text(
  String id,
  double cx,
  double cy,
  String text, {
  double fontSize = 18,
  int color = 0xFF0F172A,
  int fontWeight = 600,
  double width = 360,
  int maxLines = 3,
}) => {
  'id': id,
  'type': 'text',
  'z': 5,
  'cx': cx,
  'cy': cy,
  'text': text,
  'color': color,
  'fontSize': fontSize,
  'fontWeight': fontWeight,
  'textAlign': 'left',
  'width': width,
  'maxLines': maxLines,
};

Map<String, dynamic> _heading(
  String id,
  double cx,
  double cy,
  String text, {
  double width = 520,
  int color = 0xFF0F172A,
}) => _text(
  id,
  cx,
  cy,
  text,
  fontSize: 34,
  fontWeight: 800,
  width: width,
  maxLines: 1,
  color: color,
);

Map<String, dynamic> _box(
  String id,
  double cx,
  double cy,
  String label, {
  double width = 220,
  double height = 96,
  int color = 0xFF2563EB,
  bool filled = false,
  int? fillColor,
  int labelColor = 0xFF0F172A,
  double fontSize = 16,
  double borderRadius = 16,
  double strokeWidth = 2,
  int z = 3,
}) => {
  'id': id,
  'type': 'shape',
  'z': z,
  'shapeType': 'rectangle',
  'cx': cx,
  'cy': cy,
  'size': width > height ? width : height,
  'width': width,
  'height': height,
  'color': color,
  'strokeWidth': strokeWidth,
  'isFilled': filled,
  'fillMode': filled ? 'solid' : 'none',
  if (filled) 'fillColor': fillColor ?? color,
  'rotation': 0,
  'borderRadius': borderRadius,
  'label': label,
  'labelColor': labelColor,
  'labelFontSize': fontSize,
  'labelFontWeight': 700,
  'labelTextAlign': 'center',
};

Map<String, dynamic> _connector(
  String id,
  String startId,
  String endId,
  Offset start,
  Offset end, {
  int color = 0xFF64748B,
  String lineStyle = 'curved',
}) => {
  'id': id,
  'type': 'connector',
  'z': 6,
  'sx': start.dx,
  'sy': start.dy,
  'ex': end.dx,
  'ey': end.dy,
  'startElementId': startId,
  'startAnchor': 'right',
  'endElementId': endId,
  'endAnchor': 'left',
  'lineStyle': lineStyle,
  'color': color,
  'strokeWidth': 2.5,
  'hasArrowhead': true,
};

const _muted = 0xFF64748B;
const _blue = 0xFF2563EB;
const _green = 0xFF16A34A;
const _amber = 0xFFD97706;
const _rose = 0xFFE11D48;
const _violet = 0xFF7C3AED;
const _sky = 0xFF0EA5E9;

final List<BoardTemplate> canvasTemplates = [
  BoardTemplate(
    id: 'blank',
    name: 'Blank board',
    description: 'An empty canvas. Start anywhere.',
    category: 'General',
  ),
  BoardTemplate(
    id: 'brainstorm',
    name: 'Brainstorm',
    description: 'A guided idea grid with prompts, not just empty notes.',
    category: 'Ideas',
    elements: [
      _frame('frame', width: 1220, height: 760, color: _blue),
      _heading('title', -250, -285, 'Brainstorm'),
      _text(
        'subtitle',
        -250,
        -235,
        'Frame the problem first, then widen the options.',
        fontSize: 15,
        color: _muted,
        width: 520,
        maxLines: 2,
      ),
      _sticky(
        'n1',
        -310,
        -60,
        'Problem\nWhat pain are we solving, and for whom?',
        color: 0xFFFFE4E6,
      ),
      _sticky(
        'n2',
        0,
        -60,
        'Audience\nWho feels this most often?',
        color: 0xFFDBEAFE,
      ),
      _sticky(
        'n3',
        310,
        -60,
        'Alternatives\nWhat do people use today?',
        color: 0xFFDCFCE7,
      ),
      _sticky(
        'n4',
        -310,
        150,
        'Wild idea\nWhat would we try with no constraints?',
        color: 0xFFFEF3C7,
      ),
      _sticky(
        'n5',
        0,
        150,
        'Cheapest test\nHow can we learn this week?',
        color: 0xFFF3E8FF,
      ),
      _sticky(
        'n6',
        310,
        150,
        'Signal\nWhat evidence makes us continue?',
        color: 0xFFE0F2FE,
      ),
    ],
  ),
  BoardTemplate(
    id: 'flow',
    name: 'Flow chart',
    description: 'A clear three-step path with room to add decisions.',
    category: 'Diagram',
    elements: [
      _frame('frame', width: 1100, height: 560, color: _sky),
      _heading('title', -330, -185, 'How it works', width: 420),
      _text(
        'subtitle',
        -330,
        -138,
        'Keep each step to one verb. Add branches as the flow grows.',
        fontSize: 14,
        color: _muted,
        width: 560,
        maxLines: 2,
      ),
      _box(
        'start',
        -340,
        20,
        '1  Capture',
        color: _blue,
        filled: true,
        fillColor: 0xFFDBEAFE,
        width: 240,
        height: 110,
      ),
      _box(
        'middle',
        0,
        20,
        '2  Shape',
        color: _violet,
        filled: true,
        fillColor: 0xFFF3E8FF,
        width: 240,
        height: 110,
      ),
      _box(
        'end',
        340,
        20,
        '3  Ship',
        color: _green,
        filled: true,
        fillColor: 0xFFDCFCE7,
        width: 240,
        height: 110,
      ),
      _connector(
        'c1',
        'start',
        'middle',
        const Offset(-220, 20),
        const Offset(-120, 20),
      ),
      _connector(
        'c2',
        'middle',
        'end',
        const Offset(120, 20),
        const Offset(220, 20),
      ),
      _text(
        'hint',
        -330,
        175,
        'Tip: double-tap a step to select and edit it.',
        fontSize: 13,
        color: _muted,
        width: 420,
        maxLines: 1,
      ),
    ],
  ),
  BoardTemplate(
    id: 'retro',
    name: 'Retrospective',
    description: 'Three balanced columns with an action lane.',
    category: 'Workshop',
    elements: [
      _frame('frame', width: 1260, height: 780, color: _violet),
      _heading('title', -420, -310, 'Sprint retro'),
      _text(
        'subtitle',
        -420,
        -262,
        'Be specific, assume good intent, leave with one owner per action.',
        fontSize: 14,
        color: _muted,
        width: 640,
      ),
      _box(
        'h1',
        -380,
        -175,
        'Went well',
        width: 340,
        height: 64,
        color: _green,
        filled: true,
        fillColor: 0xFFDCFCE7,
        fontSize: 18,
      ),
      _box(
        'h2',
        0,
        -175,
        'To improve',
        width: 340,
        height: 64,
        color: _amber,
        filled: true,
        fillColor: 0xFFFEF3C7,
        fontSize: 18,
      ),
      _box(
        'h3',
        380,
        -175,
        'Actions',
        width: 340,
        height: 64,
        color: _blue,
        filled: true,
        fillColor: 0xFFDBEAFE,
        fontSize: 18,
      ),
      for (var i = 0; i < 2; i++) ...[
        _sticky(
          'w$i',
          -380,
          -30.0 + i * 165,
          i == 0 ? 'What gave us energy?' : 'What should we repeat?',
          color: 0xFFDCFCE7,
          width: 320,
          height: 130,
        ),
        _sticky(
          'i$i',
          0,
          -30.0 + i * 165,
          i == 0 ? 'Where did we lose time?' : 'What was unclear?',
          color: 0xFFFEF3C7,
          width: 320,
          height: 130,
        ),
        _sticky(
          'a$i',
          380,
          -30.0 + i * 165,
          i == 0 ? 'Action + owner + date' : 'One experiment for next sprint',
          color: 0xFFDBEAFE,
          width: 320,
          height: 130,
        ),
      ],
    ],
  ),
  BoardTemplate(
    id: 'week',
    name: 'Weekly planner',
    description: 'Five day lanes with a focus row and priorities.',
    category: 'Planning',
    elements: [
      _frame('frame', width: 1320, height: 780, color: _blue),
      _heading('title', -480, -315, 'This week'),
      _text(
        'subtitle',
        -480,
        -268,
        'One outcome per day beats a long list of maybes.',
        fontSize: 14,
        color: _muted,
        width: 520,
      ),
      for (var i = 0; i < 5; i++)
        _box(
          'day$i',
          -440.0 + i * 220,
          -120,
          const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'][i],
          width: 190,
          height: 420,
          color: i.isEven ? _blue : _sky,
          filled: true,
          fillColor: i.isEven ? 0xFFEFF6FF : 0xFFE0F2FE,
          fontSize: 17,
          borderRadius: 18,
        ),
      for (var i = 0; i < 5; i++)
        _sticky(
          'focus$i',
          -440.0 + i * 220,
          -45,
          const [
            'Main outcome\n\n',
            'Deep work\n\n',
            'Review + unblock\n\n',
            'Build + test\n\n',
            'Ship + reflect\n\n',
          ][i],
          color: 0xFFFFFDF5,
          width: 154,
          height: 210,
          fontSize: 14,
        ),
    ],
  ),
  BoardTemplate(
    id: 'kanban',
    name: 'Kanban board',
    description: 'A calm four-column board for work in progress.',
    category: 'Planning',
    elements: [
      _frame('frame', width: 1320, height: 760, color: _green),
      _heading('title', -450, -300, 'Delivery board'),
      _text(
        'subtitle',
        -450,
        -252,
        'Limit work in progress. Move a card only when it is ready.',
        fontSize: 14,
        color: _muted,
        width: 620,
      ),
      for (var i = 0; i < 4; i++)
        _box(
          'col$i',
          -450.0 + i * 300,
          -20,
          const ['Backlog', 'Next', 'In progress', 'Done'][i],
          width: 270,
          height: 470,
          color: const [_muted, _blue, _amber, _green][i],
          filled: true,
          fillColor: const [0xFFF1F5F9, 0xFFEFF6FF, 0xFFFFFBEB, 0xFFF0FDF4][i],
          fontSize: 17,
          borderRadius: 18,
        ),
      _sticky(
        'k1',
        -450,
        -120,
        'Research: onboarding friction',
        color: 0xFFFFFFFF,
        width: 220,
        height: 86,
        fontSize: 13,
      ),
      _sticky(
        'k2',
        -450,
        -20,
        'Draft empty-state copy',
        color: 0xFFFFFFFF,
        width: 220,
        height: 86,
        fontSize: 13,
      ),
      _sticky(
        'k3',
        -150,
        -120,
        'Design review notes',
        color: 0xFFEFF6FF,
        width: 220,
        height: 86,
        fontSize: 13,
      ),
      _sticky(
        'k4',
        -150,
        -20,
        'Prototype the new flow',
        color: 0xFFEFF6FF,
        width: 220,
        height: 86,
        fontSize: 13,
      ),
      _sticky(
        'k5',
        150,
        -120,
        'Build canvas toolbar',
        color: 0xFFFFFBEB,
        width: 220,
        height: 86,
        fontSize: 13,
      ),
      _sticky(
        'k6',
        450,
        -120,
        'Shared boards shipped',
        color: 0xFFF0FDF4,
        width: 220,
        height: 86,
        fontSize: 13,
      ),
    ],
  ),
  BoardTemplate(
    id: 'mind-map',
    name: 'Mind map',
    description: 'A central idea with five connected branches.',
    category: 'Ideas',
    elements: [
      _frame('frame', width: 1180, height: 800, color: _violet),
      _heading('title', -380, -330, 'Explore the idea'),
      _text(
        'subtitle',
        -380,
        -282,
        'Start with the centre, then ask “what else?” five times.',
        fontSize: 14,
        color: _muted,
        width: 620,
      ),
      _box(
        'center',
        0,
        20,
        'Core idea',
        width: 240,
        height: 120,
        color: _violet,
        filled: true,
        fillColor: 0xFFEDE9FE,
        fontSize: 20,
        borderRadius: 60,
      ),
      _box(
        'b1',
        -380,
        -150,
        'Why now?',
        width: 220,
        height: 88,
        color: _blue,
        filled: true,
        fillColor: 0xFFDBEAFE,
      ),
      _box(
        'b2',
        380,
        -150,
        'Who cares?',
        width: 220,
        height: 88,
        color: _green,
        filled: true,
        fillColor: 0xFFDCFCE7,
      ),
      _box(
        'b3',
        -410,
        160,
        'What could block us?',
        width: 240,
        height: 92,
        color: _rose,
        filled: true,
        fillColor: 0xFFFFE4E6,
        fontSize: 14,
      ),
      _box(
        'b4',
        410,
        160,
        'How do we test it?',
        width: 240,
        height: 92,
        color: _amber,
        filled: true,
        fillColor: 0xFFFEF3C7,
        fontSize: 14,
      ),
      _box(
        'b5',
        0,
        270,
        'What is the smallest first step?',
        width: 360,
        height: 90,
        color: _sky,
        filled: true,
        fillColor: 0xFFE0F2FE,
        fontSize: 14,
      ),
      _connector(
        'm1',
        'center',
        'b1',
        const Offset(-120, -10),
        const Offset(-270, -150),
        lineStyle: 'straight',
      ),
      _connector(
        'm2',
        'center',
        'b2',
        const Offset(120, -10),
        const Offset(270, -150),
        lineStyle: 'straight',
      ),
      _connector(
        'm3',
        'center',
        'b3',
        const Offset(-100, 70),
        const Offset(-290, 145),
        lineStyle: 'straight',
      ),
      _connector(
        'm4',
        'center',
        'b4',
        const Offset(100, 70),
        const Offset(290, 145),
        lineStyle: 'straight',
      ),
      _connector(
        'm5',
        'center',
        'b5',
        const Offset(0, 80),
        const Offset(0, 225),
        lineStyle: 'straight',
      ),
    ],
  ),
  BoardTemplate(
    id: 'launch',
    name: 'Product launch',
    description: 'A phase-by-phase launch plan with owners and risks.',
    category: 'Planning',
    elements: [
      _frame('frame', width: 1300, height: 800, color: _rose),
      _heading('title', -460, -330, 'Launch plan'),
      _text(
        'subtitle',
        -460,
        -282,
        'Work backwards from the launch date. Name one owner per workstream.',
        fontSize: 14,
        color: _muted,
        width: 720,
      ),
      _box(
        'phase1',
        -450,
        -90,
        '1  Position\nAudience + promise',
        width: 250,
        height: 130,
        color: _blue,
        filled: true,
        fillColor: 0xFFDBEAFE,
      ),
      _box(
        'phase2',
        -150,
        -90,
        '2  Prepare\nAssets + enablement',
        width: 250,
        height: 130,
        color: _violet,
        filled: true,
        fillColor: 0xFFEDE9FE,
      ),
      _box(
        'phase3',
        150,
        -90,
        '3  Release\nChannels + checklist',
        width: 250,
        height: 130,
        color: _amber,
        filled: true,
        fillColor: 0xFFFEF3C7,
      ),
      _box(
        'phase4',
        450,
        -90,
        '4  Learn\nMetrics + follow-up',
        width: 250,
        height: 130,
        color: _green,
        filled: true,
        fillColor: 0xFFDCFCE7,
      ),
      _connector(
        'p1',
        'phase1',
        'phase2',
        const Offset(-325, -90),
        const Offset(-275, -90),
        lineStyle: 'straight',
      ),
      _connector(
        'p2',
        'phase2',
        'phase3',
        const Offset(-25, -90),
        const Offset(25, -90),
        lineStyle: 'straight',
      ),
      _connector(
        'p3',
        'phase3',
        'phase4',
        const Offset(275, -90),
        const Offset(325, -90),
        lineStyle: 'straight',
      ),
      _sticky(
        'risk1',
        -450,
        150,
        'Risk\nWhat would make this launch slip?',
        color: 0xFFFFE4E6,
        width: 300,
        height: 130,
      ),
      _sticky(
        'metric',
        -90,
        150,
        'Success metric\nWhat number moves if this works?',
        color: 0xFFDBEAFE,
        width: 300,
        height: 130,
      ),
      _sticky(
        'owner',
        270,
        150,
        'Owner + date\nWho is accountable, and by when?',
        color: 0xFFFEF3C7,
        width: 300,
        height: 130,
      ),
    ],
  ),
  BoardTemplate(
    id: 'journey',
    name: 'User journey',
    description: 'Map what users do, think and feel at every stage.',
    category: 'Workshop',
    elements: [
      _frame('frame', width: 1300, height: 800, color: _sky),
      _heading('title', -470, -330, 'User journey'),
      _text(
        'subtitle',
        -470,
        -282,
        'Follow one real person through one real task.',
        fontSize: 14,
        color: _muted,
        width: 620,
      ),
      for (var i = 0; i < 5; i++)
        _box(
          'stage$i',
          -460.0 + i * 230,
          -170,
          const ['Discover', 'Start', 'Use', 'Return', 'Recommend'][i],
          width: 200,
          height: 64,
          color: i.isEven ? _sky : _violet,
          filled: true,
          fillColor: i.isEven ? 0xFFE0F2FE : 0xFFEDE9FE,
          fontSize: 15,
        ),
      for (var i = 0; i < 5; i++) ...[
        _sticky(
          'do$i',
          -460.0 + i * 230,
          -30,
          'Does\nWhat action do they take?',
          color: 0xFFFFFFFF,
          width: 200,
          height: 112,
          fontSize: 13,
        ),
        _sticky(
          'think$i',
          -460.0 + i * 230,
          115,
          'Thinks / feels\nWhat is uncertain or frustrating?',
          color: 0xFFFEF3C7,
          width: 200,
          height: 128,
          fontSize: 13,
        ),
      ],
      _text(
        'opportunity',
        -300,
        260,
        'Opportunity: pick the sharpest drop-off and design one fix.',
        fontSize: 15,
        width: 700,
        maxLines: 1,
      ),
    ],
  ),
];
