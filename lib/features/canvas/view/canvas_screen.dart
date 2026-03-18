import 'package:flutter/material.dart';
import './widgets/sliding_tray.dart';
import '../../../core/constants/app_colors.dart';

class CanvasScreen extends StatefulWidget {
  final String boardId;
  const CanvasScreen({super.key, required this.boardId});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  // State to track which tray is open
  String? activeTray;

  // Standard method to handle opening/closing trays
  void _openTray(String tray) {
    setState(() {
      activeTray = (activeTray == tray) ? null : tray;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. MAIN CANVAS AREA (Background)
          GestureDetector(
            onTap: () => setState(() => activeTray = null),
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
              child: const Center(
                child: Text(
                  "InkLink Drawing Surface\n(Tap to close trays)",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),

          // 2. THE FUNCTIONAL TRAYS (Visuals)
          _buildAllTrays(),

          // 3. EDGE TRIGGER HOTSPOTS (Gestures)
          // We put these last in the stack so they are on top
          _buildEdgeTriggers(),
        ],
      ),
    );
  }

  // --- CONTENT BUILDERS ---

  Widget _buildMembersContent() {
    return Column(
      children: [
        const ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: Text("Abbas (You)"),
          trailing: Icon(Icons.mic, color: Colors.green, size: 20),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text("Invite"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrushContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.line_weight, size: 18, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: 5,
                  min: 1,
                  max: 20,
                  activeColor: AppColors.primary,
                  onChanged: (v) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                [
                      Colors.black,
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                      Colors.purple,
                    ]
                    .map(
                      (c) => InkWell(
                        onTap: () {},
                        child: CircleAvatar(backgroundColor: c, radius: 14),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAIContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Describe an object...",
              hintStyle: const TextStyle(fontSize: 13),
              suffixIcon: const Icon(
                Icons.auto_awesome,
                color: Colors.purple,
                size: 20,
              ),
              fillColor: Colors.black.withOpacity(0.05),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "AI will generate a vector object for your canvas",
            style: TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShapesContent() {
    final List<IconData> shapes = [
      Icons.square_outlined,
      Icons.circle_outlined,
      Icons.change_history,
      Icons.star_border,
      Icons.pentagon_outlined,
      Icons.horizontal_rule,
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemCount: shapes.length,
      itemBuilder: (context, i) =>
          Icon(shapes[i], color: AppColors.primary, size: 30),
    );
  }

  Widget _buildToolsContent() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.undo, color: Colors.blue),
          title: const Text("Undo", style: TextStyle(fontSize: 14)),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.redo, color: Colors.blue),
          title: const Text("Redo", style: TextStyle(fontSize: 14)),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text("Clear All", style: TextStyle(fontSize: 14)),
          onTap: () {},
        ),
      ],
    );
  }

  // --- TRAYS & GESTURES ---

  Widget _buildAllTrays() {
    return Stack(
      children: [
        SlidingTray(
          isOpen: activeTray == 'members',
          direction: TrayDirection.left,
          title: "Members & Calls",
          child: _buildMembersContent(),
        ),
        SlidingTray(
          isOpen: activeTray == 'ai',
          direction: TrayDirection.right,
          title: "AI Generation",
          child: _buildAIContent(),
        ),
        SlidingTray(
          isOpen: activeTray == 'tools',
          direction: TrayDirection.left,
          title: "Editing Tools",
          height: 230,
          width: 200,
          bottomOffset: 60,
          child: _buildToolsContent(),
        ),
        SlidingTray(
          isOpen: activeTray == 'shapes',
          direction: TrayDirection.right,
          title: "Shapes",
          height: 220,
          width: 200,
          bottomOffset: 60,
          child: _buildShapesContent(),
        ),
        SlidingTray(
          isOpen: activeTray == 'brushes',
          direction: TrayDirection.bottom,
          title: "Brush & Color",
          height: 180,
          child: _buildBrushContent(),
        ),
      ],
    );
  }

  Widget _buildEdgeTriggers() {
    return Stack(
      children: [
        // BOTTOM: Swipe Up for Brushes
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity! < -100) _openTray('brushes');
            },
            child: Container(
              height: 50,
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),
        // TOP LEFT: Swipe Right for Members
        Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! > 100) _openTray('members');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(top: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // BOTTOM LEFT: Swipe Right for Tools
        Align(
          alignment: Alignment.bottomLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! > 100) _openTray('tools');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // TOP RIGHT: Swipe Left for AI
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! < -100) _openTray('ai');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(top: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // BOTTOM RIGHT: Swipe Left for Shapes
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! < -100) _openTray('shapes');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}
