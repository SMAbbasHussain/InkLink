import 'package:flutter/material.dart';
import '../../theme/chat_theme.dart';

class GifPickerTray extends StatefulWidget {
  final ValueChanged<String> onGifSelected;

  const GifPickerTray({super.key, required this.onGifSelected});

  @override
  State<GifPickerTray> createState() => _GifPickerTrayState();
}

class _GifPickerTrayState extends State<GifPickerTray> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  static const List<Map<String, String>> _kCuratedGifs = [
    {
      'title': 'Party Dance',
      'category': 'Party',
      'url': 'https://media.giphy.com/media/blSTtZehjAZ8I/giphy.gif',
    },
    {
      'title': 'Thumbs Up',
      'category': 'Agree',
      'url': 'https://media.giphy.com/media/111ebonMs90YLu/giphy.gif',
    },
    {
      'title': 'Cat Vibing',
      'category': 'Party',
      'url': 'https://media.giphy.com/media/jpbnoe3UIa8TU8LM13/giphy.gif',
    },
    {
      'title': 'Laughing Hard',
      'category': 'Laugh',
      'url': 'https://media.giphy.com/media/l0ExayQDzrI2xOb8A/giphy.gif',
    },
    {
      'title': 'Mind Blown',
      'category': 'Wow',
      'url': 'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif',
    },
    {
      'title': 'Heart Eyes',
      'category': 'Love',
      'url': 'https://media.giphy.com/media/26FLdm964upN2AYb6/giphy.gif',
    },
    {
      'title': 'High Five',
      'category': 'Agree',
      'url': 'https://media.giphy.com/media/pHb82xtBPfqEg/giphy.gif',
    },
    {
      'title': 'Thinking Beard',
      'category': 'Think',
      'url': 'https://media.giphy.com/media/3o7bu3XilJ5BOiSGic/giphy.gif',
    },
    {
      'title': 'Confused Travolta',
      'category': 'Think',
      'url': 'https://media.giphy.com/media/g01ZnwAUvutuK8GIQn/giphy.gif',
    },
    {
      'title': 'Cute Dog Wave',
      'category': 'Hello',
      'url': 'https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif',
    },
    {
      'title': 'Popcorn Drama',
      'category': 'Party',
      'url': 'https://media.giphy.com/media/t3dLl0TGHCxTG/giphy.gif',
    },
    {
      'title': 'Happy Snoopy',
      'category': 'Party',
      'url': 'https://media.giphy.com/media/mFYTaY7Gblo87Bc35D/giphy.gif',
    },
  ];

  final List<String> _categories = ['All', 'Party', 'Agree', 'Laugh', 'Love', 'Wow', 'Think', 'Hello'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _kCuratedGifs.where((gif) {
      final matchesCategory = _selectedCategory == 'All' || gif['category'] == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          gif['title']!.toLowerCase().contains(query) ||
          gif['category']!.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Container(
      height: 320,
      color: colors.surface,
      child: Column(
        children: [
          // Header / Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ChatTheme.space12,
              ChatTheme.space12,
              ChatTheme.space12,
              ChatTheme.space8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search GIFs...',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 18),
                filled: true,
                fillColor: colors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ChatTheme.space12,
                  vertical: ChatTheme.space8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Categories Chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ChatTheme.space12),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: ChatTheme.space8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : colors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: colors.accent,
                  backgroundColor: colors.surfaceElevated,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: ChatTheme.space8),

          // GIF Grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No GIFs found',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(ChatTheme.space8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: ChatTheme.space8,
                      mainAxisSpacing: ChatTheme.space8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final url = item['url']!;
                      return GestureDetector(
                        onTap: () => widget.onGifSelected(url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: colors.background,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(Icons.broken_image, color: colors.textSecondary, size: 20),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
