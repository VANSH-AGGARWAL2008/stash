import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../database/database_helper.dart';
import '../models/item.dart';
import '../share_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';
import '../widgets/pressable.dart';
import 'create_edit_screen.dart';
import 'detail_screen.dart';
import 'data_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Item> _allItems = [];
  bool _loading = true;
  String _query = '';
  String _typeFilter = 'all';
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    sharedItemsChanged.addListener(_loadItems);
  }

  @override
  void dispose() {
    sharedItemsChanged.removeListener(_loadItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await _db.getAllItems();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _loading = false;
    });
  }

  List<Item> get _filteredItems {
    return _allItems.where((item) {
      if (item.archived != _showArchived) return false;
      if (_typeFilter != 'all' && item.type != _typeFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final haystack = [
          item.title,
          item.content ?? '',
          item.url ?? '',
          ...item.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, CupertinoPageRoute(builder: (_) => page));
    _loadItems(); // always refresh when coming back
  }

  Future<void> _toggleArchive(Item item) async {
    HapticFeedback.lightImpact();
    await _db.updateItem(
      item.copyWith(archived: !item.archived, updatedAt: DateTime.now()),
    );
    _loadItems();
  }

  Future<void> _confirmDelete(Item item) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    await _db.deleteItem(item.id);
    _loadItems();
  }

  void _showItemActions(Item item) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _open(DetailScreen(itemId: item.id));
            },
            child: const Text('Open'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleArchive(item);
            },
            child: Text(item.archived ? 'Restore' : 'Archive'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(item);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showMenu() {
    final current = themeNotifier.value;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        Widget option(String label, ThemeMode mode, IconData icon) =>
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                HapticFeedback.selectionClick();
                setThemeMode(mode);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                  if (current == mode) ...[
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.checkmark_alt, size: 18),
                  ],
                ],
              ),
            );

        return CupertinoActionSheet(
          title: const Text('Appearance'),
                    actions: [
            option('System', ThemeMode.system, CupertinoIcons.device_phone_portrait),
            option('Light', ThemeMode.light, CupertinoIcons.sun_max),
            option('Dark', ThemeMode.dark, CupertinoIcons.moon),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _open(const DataScreen());
              },
              child: const Text('Your Data'),
            ),
          ],

          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset('assets/icon-black.png', width: 32, height: 32),
    ),
    const SizedBox(width: 10),
    Text(_showArchived ? 'Archive' : 'Stash'),
  ],
),

                backgroundColor: p.bg.withValues(alpha: 0.85),
                border: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _navIcon(
                      _showArchived
                          ? CupertinoIcons.tray_full
                          : CupertinoIcons.archivebox,
                      () => setState(() => _showArchived = !_showArchived),
                      p,
                    ),
                    _navIcon(CupertinoIcons.ellipsis_circle, _showMenu, p),
                  ],
                ),
              ),
              CupertinoSliverRefreshControl(onRefresh: _loadItems),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search notes, links, tags',
                    backgroundColor: p.fill,
                    borderRadius: BorderRadius.circular(12),
                    style: TextStyle(color: p.text, fontSize: 16),
                    placeholderStyle:
                        TextStyle(color: p.secondary, fontSize: 16),
                    itemColor: p.secondary,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _typeFilter,
                      backgroundColor: p.fill,
                      thumbColor: p.thumb,
                      children: {
                        'all': _segment('All', p),
                        'note': _segment('Notes', p),
                        'link': _segment('Links', p),
                        'image': _segment('Images', p),
                      },
                      onValueChanged: (v) {
                        if (v == null) return;
                        HapticFeedback.selectionClick();
                        setState(() => _typeFilter = v);
                      },
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(p),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return ItemCard(
                        item: item,
                        onTap: () => _open(DetailScreen(itemId: item.id)),
                        onLongPress: () => _showItemActions(item),
                      );
                    },
                  ),
                ),
            ],
          ),

          // Floating "Add new note" pill
          if (!_showArchived)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Pressable(
                      scale: 0.94,
                      onTap: () => _open(const CreateEditScreen()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 15),
                        decoration: BoxDecoration(
                          color: p.text,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: p.isDark ? 0.5 : 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.add, color: p.bg, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Add new note',
                              style: TextStyle(
                                color: p.bg,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, VoidCallback onTap, Palette p) => Pressable(
        scale: 0.85,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Icon(icon, size: 25, color: p.text),
        ),
      );

  Widget _segment(String label, Palette p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
      );

  Widget _emptyState(Palette p) {
    final searching = _query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
            child: Icon(
              searching
                  ? CupertinoIcons.search
                  : _showArchived
                      ? CupertinoIcons.archivebox
                      : CupertinoIcons.tray,
              size: 32,
              color: p.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searching
                ? 'No results'
                : _showArchived
                    ? 'Archive is empty'
                    : 'Nothing saved yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            searching
                ? 'Try a different word or tag.'
                : 'Tap “Add new note” or share\nsomething into Stash.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.secondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
