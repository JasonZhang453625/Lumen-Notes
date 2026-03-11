import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kGroupActionWidth = 92;
const Color kOpenTransitionBackdrop = Color(0xFFF1F6FA);
const Duration kDeferredDetailDelay = Duration(milliseconds: 120);
const Duration kHomeCardExpandDuration = Duration(milliseconds: 680);
const Duration kHomeCardControlsDelay = Duration(milliseconds: 170);
const Duration kDetailRevealDuration = Duration(milliseconds: 320);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = NotesStore(preferences);
  await store.load();
  runApp(LumenApp(store: store));
}

String compactText(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String deriveNoteTitle(String content) {
  for (final line in content.split('\n')) {
    final candidate = compactText(line);
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }
  return '';
}

Future<void> popAfterKeyboardSettles(BuildContext context) async {
  FocusManager.instance.primaryFocus?.unfocus();
  for (var i = 0; i < 18; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!context.mounted) {
      return;
    }
    if (MediaQuery.viewInsetsOf(context).bottom == 0) {
      break;
    }
  }
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pop();
}

class DeferredDetailContent extends StatefulWidget {
  const DeferredDetailContent({
    super.key,
    required this.builder,
    this.delay = kDeferredDetailDelay,
  });

  final WidgetBuilder builder;
  final Duration delay;

  @override
  State<DeferredDetailContent> createState() => _DeferredDetailContentState();
}

class _DeferredDetailContentState extends State<DeferredDetailContent> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _DeferredDetailPlaceholder();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: kDetailRevealDuration,
      curve: const Cubic(0.2, 0.96, 0.3, 1.0),
      child: Builder(builder: widget.builder),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 22),
            child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
          ),
        );
      },
    );
  }
}

class _DeferredDetailPlaceholder extends StatelessWidget {
  const _DeferredDetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _CardExpandRoute<T> extends PageRouteBuilder<T> {
  _CardExpandRoute({
    required Rect startRect,
    required double startRadius,
    required Widget child,
  }) : super(
         transitionDuration: kHomeCardExpandDuration,
         reverseTransitionDuration: const Duration(milliseconds: 520),
         opaque: false,
         barrierColor: Colors.transparent,
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final progress = CurvedAnimation(
             parent: animation,
             curve: const Cubic(0.16, 0.96, 0.28, 1.0),
             reverseCurve: const Cubic(0.32, 0.0, 0.67, 0.0),
           );
           final dim = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );

           return AnimatedBuilder(
             animation: animation,
             builder: (context, _) {
               final endRect = Offset.zero & MediaQuery.sizeOf(context);
               final rect = Rect.lerp(startRect, endRect, progress.value)!;
               final radius = lerpDouble(startRadius, 28, progress.value)!;
               final showOpacity = Curves.easeOutCubic.transform(
                 ((animation.value - 0.32) / 0.68).clamp(0.0, 1.0),
               );
               final hideOpacity = ((animation.value - 0.78) / 0.22).clamp(
                 0.0,
                 1.0,
               );
               final childOpacity = animation.status == AnimationStatus.reverse
                   ? hideOpacity
                   : showOpacity;

               return Stack(
                 alignment: Alignment.topLeft,
                 children: [
                   Positioned.fill(
                     child: IgnorePointer(
                       child: ColoredBox(
                         color: Colors.black.withValues(
                           alpha: 0.18 * dim.value,
                         ),
                       ),
                     ),
                   ),
                   Positioned.fromRect(
                     rect: rect,
                     child: IgnorePointer(
                       ignoring: animation.status != AnimationStatus.completed,
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(radius),
                         child: ColoredBox(
                           color: kOpenTransitionBackdrop,
                           child: OverflowBox(
                             alignment: Alignment.topLeft,
                             minWidth: endRect.width,
                             maxWidth: endRect.width,
                             minHeight: endRect.height,
                             maxHeight: endRect.height,
                             child: SizedBox(
                               width: endRect.width,
                               height: endRect.height,
                               child: Opacity(
                                 opacity: childOpacity,
                                 child: child,
                               ),
                             ),
                           ),
                         ),
                       ),
                     ),
                   ),
                 ],
               );
             },
           );
         },
       );
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key, required this.store});

  final NotesStore store;

  @override
  Widget build(BuildContext context) {
    return GradientBackdrop(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lumen Notes',
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accent,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: HomeScreen(store: store),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final NotesStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _createCardKey = GlobalKey();
  final GlobalKey _browseCardKey = GlobalKey();
  double _homeCardsOpacity = 1;

  Rect? _cardRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _openFromCard({
    required GlobalKey cardKey,
    required WidgetBuilder pageBuilder,
    required double startRadius,
  }) async {
    final startRect = _cardRect(cardKey);
    if (startRect == null || !mounted) {
      return;
    }

    if (_homeCardsOpacity != 0) {
      setState(() {
        _homeCardsOpacity = 0;
      });
    }

    await Navigator.of(context).push(
      _CardExpandRoute<void>(
        startRect: startRect,
        startRadius: startRadius,
        child: DeferredDetailContent(
          delay: kHomeCardControlsDelay,
          builder: pageBuilder,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _homeCardsOpacity = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lumen Notes',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '把单词、句子和灵感收进一个更轻的语言学习笔记本。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: _createCardKey,
                      child: HeroActionCard(
                        indexLabel: 'A',
                        title: '新建笔记',
                        subtitle: '快速记录句子、单词、短语或任意学习内容。',
                        meta: '当前共 ${widget.store.notes.length} 条笔记',
                        icon: CupertinoIcons.plus_circle_fill,
                        gradient: const [Color(0xFFF8FDFF), Color(0xFFDFF3F9)],
                        contentOpacity: _homeCardsOpacity,
                        onTap: () => _openFromCard(
                          cardKey: _createCardKey,
                          startRadius: 36,
                          pageBuilder: (_) =>
                              CreateNoteScreen(store: widget.store),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: KeyedSubtree(
                      key: _browseCardKey,
                      child: HeroActionCard(
                        indexLabel: 'B',
                        title: '阅览笔记',
                        subtitle: '按分组与搜索快速回看之前的记录。',
                        meta:
                            '最近更新 ${AppDateFormatter.dateTime(widget.store.latestUpdatedAt)}',
                        icon: CupertinoIcons.rectangle_grid_2x2_fill,
                        gradient: const [Color(0xFFF9FCFF), Color(0xFFE7ECFF)],
                        contentOpacity: _homeCardsOpacity,
                        onTap: () => _openFromCard(
                          cardKey: _browseCardKey,
                          startRadius: 36,
                          pageBuilder: (_) =>
                              BrowseNotesScreen(store: widget.store),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key, required this.store});

  final NotesStore store;

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  late final TextEditingController _controller;
  late final FocusNode _editorFocusNode;
  String _group = NotesStore.defaultGroup;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _editorFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _safePop() {
    popAfterKeyboardSettles(context);
  }

  Future<void> _pickGroup() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickGroup(context, widget.store, initialGroup: _group);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _group = picked;
    });
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }
    await widget.store.addNote(content: content, group: _group);
    if (mounted) {
      _safePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeToAvoidBottomInset: false,
      withPageBackdrop: true,
      safeAreaBottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            DetailHeader(
              title: '新建笔记',
              subtitle: '记录日期 ${AppDateFormatter.dateOnly(DateTime.now())}',
              onBack: _safePop,
              trailing: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  return HeaderButton(
                    icon: CupertinoIcons.check_mark,
                    onTap: value.text.trim().isEmpty ? null : _save,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            RepaintBoundary(
              child: Row(
                children: [
                  Expanded(
                    child: GroupPill(label: _group, onTap: _pickGroup),
                  ),
                  const SizedBox(width: 12),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '状态',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value.text.trim().isEmpty ? '未填写' : '可保存',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: EditorTextSurface(
                controller: _controller,
                focusNode: _editorFocusNode,
                textCapitalization: TextCapitalization.sentences,
                hintText: '输入句子、单词、语法点或任意学习笔记',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrowseNotesScreen extends StatefulWidget {
  const BrowseNotesScreen({super.key, required this.store});

  final NotesStore store;

  @override
  State<BrowseNotesScreen> createState() => _BrowseNotesScreenState();
}

class _BrowseNotesScreenState extends State<BrowseNotesScreen> {
  late final TextEditingController _searchController;
  String _selectedGroup = NotesStore.allGroupsLabel;
  bool _groupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      _groupsExpanded = false;
    });
  }

  Rect? _cardRect(BuildContext cardContext) {
    final box = cardContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _openNoteFromCard(
    NoteItem note,
    BuildContext cardContext,
  ) async {
    final startRect = _cardRect(cardContext);
    if (startRect == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      _CardExpandRoute<void>(
        startRect: startRect,
        startRadius: 30,
        child: DeferredDetailContent(
          delay: kHomeCardControlsDelay,
          builder: (_) =>
              NoteEditorScreen(store: widget.store, noteId: note.id),
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    if (!widget.store.browseGroups.contains(_selectedGroup)) {
      _selectedGroup = NotesStore.allGroupsLabel;
    }
    setState(() {});
  }

  Future<void> _showCardActions(NoteItem note) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return GlassBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActionTile(
                icon: CupertinoIcons.square_pencil,
                label: '移动笔记',
                onTap: () => Navigator.of(sheetContext).pop(_CardAction.move),
              ),
              const SizedBox(height: 10),
              ActionTile(
                icon: CupertinoIcons.delete,
                label: '删除笔记',
                color: AppColors.destructive,
                onTap: () => Navigator.of(sheetContext).pop(_CardAction.delete),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _CardAction.move:
        final newGroup = await pickGroup(
          context,
          widget.store,
          initialGroup: note.group,
        );
        if (newGroup != null) {
          await widget.store.moveNote(note.id, newGroup);
          if (mounted) {
            setState(() {});
          }
        }
      case _CardAction.delete:
        final confirmed = await showDeleteDialog(context);
        if (confirmed == true) {
          await widget.store.deleteNote(note.id);
          if (mounted) {
            setState(() {});
          }
        }
    }
  }

  Future<void> _renameGroup(String group) async {
    final renamed = await showGroupNameDialog(context, currentName: group);
    if (renamed == null || renamed == group) {
      return;
    }
    await widget.store.renameGroup(group, renamed);
    if (!mounted) {
      return;
    }
    setState(() {
      if (_selectedGroup == group) {
        _selectedGroup = renamed;
      }
    });
  }

  Future<void> _deleteGroup(String group) async {
    final confirmed = await showGroupDeleteDialog(
      context,
      groupName: group,
      noteCount: widget.store.groupCount(group),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.deleteGroup(group);
    if (!mounted) {
      return;
    }
    setState(() {
      if (_selectedGroup == group) {
        _selectedGroup = NotesStore.allGroupsLabel;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.store.browseGroups.contains(_selectedGroup)) {
      _selectedGroup = NotesStore.allGroupsLabel;
    }

    final query = _searchController.text;
    final notes = widget.store.filteredNotes(
      group: _selectedGroup,
      query: query,
    );
    final groups = widget.store.browseGroups;
    final bottomSafeInset = MediaQuery.viewPaddingOf(context).bottom;

    return AppScaffold(
      resizeToAvoidBottomInset: true,
      withPageBackdrop: true,
      safeAreaBottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DetailHeader(title: '阅览笔记'),
            const SizedBox(height: 18),
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.search,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索笔记内容或分组',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      },
                      child: const Icon(
                        CupertinoIcons.clear_thick_circled,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _groupsExpanded = !_groupsExpanded;
                      });
                    },
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.square_grid_2x2,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '当前分组',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _selectedGroup,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${widget.store.groupCount(_selectedGroup)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _groupsExpanded
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 340),
                    firstCurve: Curves.easeInCubic,
                    secondCurve: Curves.easeOutCubic,
                    sizeCurve: Curves.easeOutCubic,
                    crossFadeState: _groupsExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(
                      width: double.infinity,
                      height: 0,
                    ),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: SingleChildScrollView(
                            clipBehavior: Clip.none,
                            child: Column(
                              children: groups
                                  .map(
                                    (group) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: widget.store.isCustomGroup(group)
                                          ? SwipeGroupRow(
                                              key: ValueKey(group),
                                              label: group,
                                              count: widget.store.groupCount(
                                                group,
                                              ),
                                              selected: _selectedGroup == group,
                                              onTap: () => _selectGroup(group),
                                              onRename: () =>
                                                  _renameGroup(group),
                                              onDelete: () =>
                                                  _deleteGroup(group),
                                            )
                                          : GroupRowButton(
                                              label: group,
                                              count: widget.store.groupCount(
                                                group,
                                              ),
                                              selected: _selectedGroup == group,
                                              onTap: () => _selectGroup(group),
                                            ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: notes.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(bottom: bottomSafeInset + 16),
                      child: EmptyNotesState(
                        hasQuery: query.trim().isNotEmpty,
                        group: _selectedGroup,
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.only(bottom: bottomSafeInset + 18),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.88,
                          ),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];

                        return Builder(
                          builder: (cardContext) => NoteCard(
                            note: note,
                            onTap: () => _openNoteFromCard(note, cardContext),
                            onLongPress: () => _showCardActions(note),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.store,
    required this.noteId,
  });

  final NotesStore store;
  final String noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _controller;
  late NoteItem _note;
  late String _group;

  @override
  void initState() {
    super.initState();
    final note = widget.store.noteById(widget.noteId);
    if (note == null) {
      throw ArgumentError('Unknown note id: ${widget.noteId}');
    }
    _note = note;
    _group = note.group;
    _titleController = TextEditingController(text: note.title);
    _controller = TextEditingController(text: note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _hasChangesForText(String title, String text) {
    return compactText(title) != _note.title ||
        text.trim() != _note.content.trim() ||
        _group != _note.group;
  }

  bool get _hasPendingChanges =>
      _hasChangesForText(_titleController.text, _controller.text);

  Future<void> _pickGroup() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickGroup(context, widget.store, initialGroup: _group);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _group = picked;
    });
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }
    await widget.store.updateNote(
      _note.id,
      title: _titleController.text,
      content: content,
      group: _group,
    );
    final refreshed = widget.store.noteById(_note.id);
    if (refreshed != null) {
      _note = refreshed;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDeleteDialog(context);
    if (confirmed != true) {
      return;
    }
    await widget.store.deleteNote(_note.id);
    if (mounted) {
      _safePop();
    }
  }

  void _safePop() {
    popAfterKeyboardSettles(context);
  }

  Future<bool> _onWillPop(bool changed) async {
    if (!changed || _controller.text.trim().isEmpty) {
      _safePop();
      return true;
    }
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('放弃更改？'),
          content: const Text('您有尚未保存的修改，现在返回将丢失这些内容。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('放弃'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    if (shouldDiscard == true) {
      _safePop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop(_hasPendingChanges);
      },
      child: AppScaffold(
        resizeToAvoidBottomInset: false,
        withPageBackdrop: true,
        safeAreaBottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              DetailHeader(
                subtitle: '${AppDateFormatter.dateTime(_note.updatedAt)}编辑',
                onBack: () => _onWillPop(_hasPendingChanges),
                titleWidget: TextField(
                  controller: _titleController,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '输入笔记标题',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                  ),
                ),
                trailing: AnimatedBuilder(
                  animation: Listenable.merge([_titleController, _controller]),
                  builder: (context, _) {
                    final changed = _hasChangesForText(
                      _titleController.text,
                      _controller.text,
                    );
                    final canSave =
                        changed && _controller.text.trim().isNotEmpty;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HeaderButton(
                          icon: CupertinoIcons.delete,
                          destructive: true,
                          onTap: _delete,
                        ),
                        const SizedBox(width: 10),
                        HeaderButton(
                          icon: CupertinoIcons.check_mark,
                          onTap: canSave ? _save : null,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 3),
              RepaintBoundary(
                child: Row(
                  children: [
                    Expanded(
                      child: GroupPill(label: _group, onTap: _pickGroup),
                    ),
                    const SizedBox(width: 12),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '创建于',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppDateFormatter.dateOnly(_note.createdAt),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: EditorTextSurface(
                  controller: _controller,
                  hintText: '开始编辑你的笔记',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.resizeToAvoidBottomInset = false,
    this.withPageBackdrop = false,
    this.safeAreaBottom = true,
  });

  final Widget child;
  final bool resizeToAvoidBottomInset;
  final bool withPageBackdrop;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final safeBody = SafeArea(bottom: safeAreaBottom, child: child);

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: withPageBackdrop
          ? kOpenTransitionBackdrop
          : Colors.transparent,
      body: withPageBackdrop
          ? Stack(
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(child: GradientBackdropLayer()),
                ),
                safeBody,
              ],
            )
          : safeBody,
    );
  }
}

class GradientBackdropLayer extends StatelessWidget {
  const GradientBackdropLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F7FA), Color(0xFFEFF3F7), Color(0xFFF8FAFC)],
        ),
      ),
    );
  }
}

class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        const Positioned.fill(child: GradientBackdropLayer()),
        child,
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 30,
    this.frosted = false,
    this.blurSigma = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool frosted;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: const Color(0xFFF1F5F8),
        border: Border.all(color: const Color(0xFFDCE4EA), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0A1A28),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class EditorTextSurface extends StatelessWidget {
  const EditorTextSurface({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: IgnorePointer(
            child: GlassPanel(
              padding: EdgeInsets.zero,
              child: SizedBox.expand(),
            ),
          ),
        ),
        RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: false,
              maxLines: null,
              expands: true,
              textCapitalization: textCapitalization,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 19,
                height: 1.35,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HeroActionCard extends StatelessWidget {
  const HeroActionCard({
    super.key,
    required this.indexLabel,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.contentOpacity = 1,
  });

  final String indexLabel;
  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final double contentOpacity;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: EdgeInsets.zero,
        radius: 36,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFFCCD4DC), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: AnimatedOpacity(
            opacity: contentOpacity,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Center(
                        child: Text(
                          indexLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(icon, color: AppColors.textPrimary, size: 26),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  meta,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.trailing,
    this.onBack,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HeaderButton(
          icon: CupertinoIcons.chevron_back,
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget ??
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...?(trailing == null ? null : [trailing!]),
      ],
    );
  }
}

class HeaderButton extends StatelessWidget {
  const HeaderButton({
    super.key,
    required this.icon,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? AppColors.destructive
        : AppColors.textPrimary;
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.42 : 1,
      child: Material(
        color: const Color(0xFFF1F5F8),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCE4EA), width: 1),
            ),
            child: Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

class GroupPill extends StatelessWidget {
  const GroupPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A1A28),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.panelStrong,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xB8FFFFFF)),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.collections,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GroupRowButton extends StatelessWidget {
  const GroupRowButton({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: selected ? const Color(0x130A1A28) : const Color(0x0C0A1A28),
            blurRadius: selected ? 16 : 13,
            spreadRadius: -3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: selected ? const Color(0xFFF7FCFF) : const Color(0xFFE9EFF3),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? const Color(0xFFD3EAF4)
                    : const Color(0xD6D9E2E8),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SwipeGroupRow extends StatefulWidget {
  const SwipeGroupRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<SwipeGroupRow> createState() => _SwipeGroupRowState();
}

class _SwipeGroupRowState extends State<SwipeGroupRow>
    with SingleTickerProviderStateMixin {
  static const Curve _openCurve = Cubic(0.18, 0.88, 0.2, 1.0);
  static const Curve _closeCurve = Cubic(0.16, 0.72, 0.28, 1.0);

  late final AnimationController _settleController;
  Animation<double>? _settleAnimation;
  double _offset = 0;

  double get _maxReveal => (kGroupActionWidth * 2) + 14;

  bool get _isOpen => _offset <= -_maxReveal + 1;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(vsync: this)
      ..addListener(() {
        final value = _settleAnimation?.value;
        if (value != null && mounted) {
          setState(() {
            _offset = value;
          });
        }
      });
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  double _applyDragResistance(double next) {
    if (next > 0) {
      return next * 0.22;
    }
    if (next < -_maxReveal) {
      return -_maxReveal + (next + _maxReveal) * 0.22;
    }
    return next;
  }

  void _animateTo(
    double target, {
    required Duration duration,
    required Curve curve,
  }) {
    _settleController
      ..stop()
      ..duration = duration;

    _settleAnimation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _settleController, curve: curve));

    _settleController
      ..value = 0
      ..forward();
  }

  void _close() {
    _animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: _closeCurve,
    );
  }

  void _open() {
    _animateTo(
      -_maxReveal,
      duration: const Duration(milliseconds: 280),
      curve: _openCurve,
    );
  }

  void _settle(double velocity) {
    final progress = (-_offset / _maxReveal).clamp(0.0, 1.0);
    const flingVelocity = 50.0;
    const settleVelocity = 15.0;
    const settleProgress = 0.1;
    final shouldOpen = switch (velocity) {
      <= -flingVelocity => true,
      >= flingVelocity => false,
      <= -settleVelocity when progress > settleProgress => true,
      >= settleVelocity when progress < (1 - settleProgress) => false,
      _ => progress >= 0.5,
    };

    if (shouldOpen) {
      _open();
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SwipeActionButton(
                        icon: CupertinoIcons.pencil,
                        label: '编辑',
                        gradient: const [Color(0xFFD6EFF8), Color(0xFFB5DCEC)],
                        foregroundColor: const Color(0xFF234B5A),
                        onTap: () {
                          _close();
                          widget.onRename();
                        },
                      ),
                      const SizedBox(width: 6),
                      _SwipeActionButton(
                        icon: CupertinoIcons.trash,
                        label: '删除',
                        gradient: const [Color(0xFFF9CFD1), Color(0xFFF3B3B3)],
                        foregroundColor: const Color(0xFF7B2121),
                        onTap: () {
                          _close();
                          widget.onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_offset, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _settleController.stop();
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _offset = _applyDragResistance(_offset + details.delta.dx);
                  });
                },
                onHorizontalDragEnd: (details) {
                  _settle(details.primaryVelocity ?? 0);
                },
                onHorizontalDragCancel: () {
                  _settle(0);
                },
                child: GroupRowButton(
                  label: widget.label,
                  count: widget.count,
                  selected: widget.selected,
                  onTap: () {
                    if (_isOpen) {
                      _close();
                      return;
                    }
                    widget.onTap();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.foregroundColor = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(21);

    return SizedBox(
      width: kGroupActionWidth,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: foregroundColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  final NoteItem note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelStrong,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCD4DC), width: 1),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.ellipsis,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  note.preview,
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppDateFormatter.dateTime(note.updatedAt),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyNotesState extends StatelessWidget {
  const EmptyNotesState({
    super.key,
    required this.hasQuery,
    required this.group,
  });

  final bool hasQuery;
  final String group;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFE5EEF4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                CupertinoIcons.doc_text_search,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasQuery ? '没有找到匹配结果' : '这个分组还没有笔记',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery ? '试试更短的关键词，或者切换到其他分组。' : '当前分组：$group',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panelStrong,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xBAFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160A1A28),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: child,
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0F4),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> pickGroup(
  BuildContext context,
  NotesStore store, {
  String? initialGroup,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: GlassBottomSheet(
          child: _GroupPickerSheet(
            store: store,
            initialGroup: initialGroup ?? NotesStore.defaultGroup,
          ),
        ),
      );
    },
  );
}

class _GroupPickerSheet extends StatefulWidget {
  const _GroupPickerSheet({required this.store, required this.initialGroup});

  final NotesStore store;
  final String initialGroup;

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  late final TextEditingController _controller;
  late String _selectedGroup;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.initialGroup;
    _controller = TextEditingController();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _submit() {
    final typed = compactText(_controller.text);
    final result = typed.isNotEmpty ? typed : _selectedGroup;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.availableGroups;
    final height = MediaQuery.of(context).size.height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCCD7DE),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '选择分组',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点已有分组，或输入一个新分组名。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GroupRowButton(
                        label: group,
                        count: widget.store.groupCount(group),
                        selected:
                            _selectedGroup == group &&
                            _controller.text.trim().isEmpty,
                        onTap: () {
                          setState(() {
                            _selectedGroup = group;
                            _controller.clear();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '新建分组',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '输入新分组名',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: HeaderFooterButton(
                  label: '取消',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HeaderFooterButton(
                  label: '使用这个分组',
                  primary: true,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeaderFooterButton extends StatelessWidget {
  const HeaderFooterButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.accent : const Color(0xFFEAF0F4);
    final fg = primary ? Colors.white : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> showGroupNameDialog(
  BuildContext context, {
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新的分组名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = compactText(controller.text);
              if (name.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(name);
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

Future<bool?> showGroupDeleteDialog(
  BuildContext context, {
  required String groupName,
  required int noteCount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('删除分组'),
        content: Text('删除后，该分组下的 $noteCount 条笔记会自动移到“未分组”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('删除 $groupName'),
          ),
        ],
      );
    },
  );
}

Future<bool?> showDeleteDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
}

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.group,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String group;

  String get preview => content.trim().replaceAll('\n', ' ');

  NoteItem copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? group,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'group': group,
    };
  }

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as String? ?? '';
    final title = compactText(json['title'] as String? ?? '');
    return NoteItem(
      id: json['id'] as String,
      title: title.isEmpty ? deriveNoteTitle(content) : title,
      content: content,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      group: json['group'] as String? ?? NotesStore.defaultGroup,
    );
  }
}

class NotesStore extends ChangeNotifier {
  NotesStore(this._preferences);

  static const String storageKey = 'lumen_notes';
  static const String defaultGroup = '未分组';
  static const String allGroupsLabel = '全部笔记';

  final SharedPreferences _preferences;
  List<NoteItem> _notes = <NoteItem>[];

  List<NoteItem> get notes => List<NoteItem>.unmodifiable(_notes);

  DateTime get latestUpdatedAt {
    if (_notes.isEmpty) {
      return DateTime.now();
    }
    return _notes
        .map((note) => note.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<String> get availableGroups {
    final custom =
        _notes
            .map((note) => note.group)
            .where((group) => group != defaultGroup)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>[defaultGroup, ...custom];
  }

  List<String> get browseGroups => <String>[allGroupsLabel, ...availableGroups];

  bool isCustomGroup(String group) {
    return group != defaultGroup && group != allGroupsLabel;
  }

  NoteItem? noteById(String id) {
    for (final note in _notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  int groupCount(String group) {
    if (group == allGroupsLabel) {
      return _notes.length;
    }
    return _notes.where((note) => note.group == group).length;
  }

  List<NoteItem> filteredNotes({required String group, String query = ''}) {
    final normalizedQuery = query.trim().toLowerCase();
    final items = _notes.where((note) {
      final matchesGroup = group == allGroupsLabel || note.group == group;
      if (!matchesGroup) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return note.title.toLowerCase().contains(normalizedQuery) ||
          note.content.toLowerCase().contains(normalizedQuery) ||
          note.group.toLowerCase().contains(normalizedQuery);
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> load() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _notes = <NoteItem>[];
      notifyListeners();
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      _notes = <NoteItem>[];
      notifyListeners();
      return;
    }

    _notes = decoded
        .map(
          (item) => NoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    notifyListeners();
  }

  Future<void> addNote({
    required String content,
    required String group,
    String? title,
  }) async {
    final now = DateTime.now();
    _notes.add(
      NoteItem(
        id: now.microsecondsSinceEpoch.toString(),
        title: _sanitizeTitle(
          title ?? deriveNoteTitle(content),
          content: content,
        ),
        content: content,
        createdAt: now,
        updatedAt: now,
        group: _sanitizeGroup(group),
      ),
    );
    await _persist();
  }

  Future<void> updateNote(
    String id, {
    required String title,
    required String content,
    required String group,
  }) async {
    _notes = _notes
        .map(
          (note) => note.id == id
              ? note.copyWith(
                  title: _sanitizeTitle(title, content: content),
                  content: content,
                  group: _sanitizeGroup(group),
                  updatedAt: DateTime.now(),
                )
              : note,
        )
        .toList();
    await _persist();
  }

  Future<void> moveNote(String id, String group) async {
    _notes = _notes
        .map(
          (note) => note.id == id
              ? note.copyWith(
                  group: _sanitizeGroup(group),
                  updatedAt: DateTime.now(),
                )
              : note,
        )
        .toList();
    await _persist();
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
    await _persist();
  }

  Future<void> renameGroup(String oldName, String newName) async {
    if (!isCustomGroup(oldName)) {
      return;
    }
    final sanitized = _sanitizeGroup(newName);
    if (sanitized == oldName) {
      return;
    }
    _notes = _notes
        .map(
          (note) => note.group == oldName
              ? note.copyWith(group: sanitized, updatedAt: DateTime.now())
              : note,
        )
        .toList();
    await _persist();
  }

  Future<void> deleteGroup(String group) async {
    if (!isCustomGroup(group)) {
      return;
    }
    _notes = _notes
        .map(
          (note) => note.group == group
              ? note.copyWith(group: defaultGroup, updatedAt: DateTime.now())
              : note,
        )
        .toList();
    await _persist();
  }

  String _sanitizeGroup(String raw) {
    final cleaned = compactText(raw);
    return cleaned.isEmpty ? defaultGroup : cleaned;
  }

  String _sanitizeTitle(String raw, {required String content}) {
    final cleaned = compactText(raw);
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    final fallback = deriveNoteTitle(content);
    return fallback.isNotEmpty ? fallback : '未命名笔记';
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_notes.map((note) => note.toJson()).toList());
    await _preferences.setString(storageKey, encoded);
    notifyListeners();
  }
}

class AppDateFormatter {
  static String dateOnly(DateTime value) {
    return '${value.year}.${_pad(value.month)}.${_pad(value.day)}';
  }

  static String dateTime(DateTime value) {
    return '${dateOnly(value)} ${_pad(value.hour)}:${_pad(value.minute)}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}

class AppColors {
  static const Color accent = Color(0xFF63BFD4);
  static const Color panelBase = Color(0xFFEAF1F5);
  static const Color panelStrong = Color(0xFFF9FCFF);
  static const Color textPrimary = Color(0xFF17212B);
  static const Color textSecondary = Color(0xFF667482);
  static const Color textMuted = Color(0xFF9BA8B5);
  static const Color destructive = Color(0xFFD66767);
}

enum _CardAction { move, delete }
