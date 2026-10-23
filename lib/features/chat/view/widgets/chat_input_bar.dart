import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../domain/models/chat/chat_share_payload.dart';
import '../../theme/chat_theme.dart';
import 'gif_picker_tray.dart';
import 'share_selector_sheet.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final ValueChanged<String> onSendImage;
  final ValueChanged<String> onSendGif;
  final ValueChanged<ChatSharePayload> onSendSharePayload;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendGif,
    required this.onSendSharePayload,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  bool _showGifTray = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSendText(text);
    _textController.clear();
  }

  void _showAttachmentOptions(BuildContext context, ChatColors colors) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent.withOpacity(0.12),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: colors.accent, size: 20),
                  ),
                  title: Text(
                    'Camera',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text('Take a photo now', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(bottomCtx);
                    final photo = await _picker.pickImage(source: ImageSource.camera);
                    if (photo != null) widget.onSendImage(photo.path);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent, size: 20),
                  ),
                  title: Text(
                    'Photo & Video Gallery',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text('Share pictures from device', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(bottomCtx);
                    final image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) widget.onSendImage(image.path);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: Colors.amber, size: 20),
                  ),
                  title: Text(
                    'Share Board Invite',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text('Send interactive board join card', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(bottomCtx);
                    final payload = await showModalBottomSheet<ChatSharePayload>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ShareSelectorSheet(),
                    );
                    if (payload != null) widget.onSendSharePayload(payload);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.teal.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.workspaces_rounded, color: Colors.teal, size: 20),
                  ),
                  title: Text(
                    'Share Workspace Invite',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text('Send interactive workspace card', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(bottomCtx);
                    final payload = await showModalBottomSheet<ChatSharePayload>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ShareSelectorSheet(),
                    );
                    if (payload != null) widget.onSendSharePayload(payload);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showGifTray)
          GifPickerTray(
            onGifSelected: (gifUrl) {
              setState(() => _showGifTray = false);
              widget.onSendGif(gifUrl);
            },
          ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.divider.withOpacity(0.6),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(colors.isDark ? 0.25 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // iMessage style circular '+' button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showAttachmentOptions(context, colors),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.inputFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: colors.accent,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Main capsule input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: colors.inputBorder,
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 14, right: 8, top: 2, bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: 5,
                            minLines: 1,
                            style: TextStyle(
                              color: colors.inputText,
                              fontSize: 15,
                              height: 1.3,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(
                                color: colors.inputHint,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),

                        // Sleek GIF Toggle Pill
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _showGifTray = !_showGifTray);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: _showGifTray ? colors.accent : colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _showGifTray ? colors.accent : colors.divider,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'GIF',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: _showGifTray ? Colors.white : colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // iMessage style Send Button (Upward arrow with spring scale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: AnimatedScale(
                    scale: _hasText ? 1.0 : 0.88,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: _hasText ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 150),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _hasText ? _handleSend : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _hasText
                                ? LinearGradient(
                                    colors: [colors.accent, colors.accentAlt],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: _hasText ? null : colors.inputFill,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: _hasText ? Colors.white : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
