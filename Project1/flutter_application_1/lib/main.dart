import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kGroupActionWidth = 82;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = NotesStore(preferences);
  await store.load();
  runApp(LumenApp(store: store));
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key, required this.store});

  final NotesStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumen Notes',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDBF0F6),
          brightness: Brightness.light,
        ),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: HomeScreen(store: store),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final NotesStore store;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'LANGUAGE NOTEBOOK',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2.8,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Lumen',
                          style: TextStyle(
                            fontSize: 50,
                            height: 0.96,
                            letterSpacing: -2.4,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 136,
                    child: Text(
                      '像 ChatGPT 一样简洁，但专门服务你的语言学习笔记。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    flex: 11,
                    child: HeroActionCard(
                      label: 'A',
                      title: '新建笔记',
                      subtitle: '记录单词、句子、语法和灵感',
                      onTap: () async {
                        await Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => CreateNoteScreen(store: store),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 9,
                    child: HeroActionCard(
                      label: 'B',
                      title: '阅览笔记',
                      subtitle: '搜索、分组并浏览你的全部历史记录',
                      reverseGlow: true,
                      onTap: () async {
                        await Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => BrowseNotesScreen(store: store),
                          ),
                        );
                      },
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
  final TextEditingController _controller = TextEditingController();
  String _group = NotesStore.defaultGroup;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AppScaffold(
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            DetailHeader(
              eyebrow: 'NEW NOTE',
              title: '新建笔记',
              subtitle: AppDateFormatter.full(now),
              trailingIcon: CupertinoIcons.check_mark,
              onBack: () => Navigator.of(context).pop(),
              onAction: _save,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '输入你的内容',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GroupPill(
                      label: _group,
                      icon: CupertinoIcons.folder,
                      onTap: () async {
                        final group = await pickGroup(
                          context,
                          widget.store.groups,
                          selected: _group,
                          title: '选择分组',
                        );
                        if (group != null) {
                          setState(() => _group = group);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.7,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: '输入句子、单词、表达、例句或任何你想记录的内容...',
                          hintStyle: TextStyle(
                            color: AppColors.hint,
                            fontSize: 22,
                            height: 1.7,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '日期会自动记录',
                            style: TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) => Text(
                            '${value.text.trim().characters.length} 字',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }

    await widget.store.addNote(content: content, group: _group);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class BrowseNotesScreen extends StatefulWidget {
  const BrowseNotesScreen({super.key, required this.store});

  final NotesStore store;

  @override
  State<BrowseNotesScreen> createState() => _BrowseNotesScreenState();
}

class _BrowseNotesScreenState extends State<BrowseNotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGroup = NotesStore.allGroupsLabel;
  bool _groupExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, child) {
          final notes = widget.store.filteredNotes(
            query: _searchController.text,
            group: _selectedGroup,
          );
          final groups = widget.store.groups;
          final selectedCount = widget.store.groupCount(_selectedGroup);

          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              children: [
                DetailHeader(
                  eyebrow: 'ARCHIVE',
                  title: '阅览笔记',
                  subtitle: notes.isEmpty ? '没有匹配结果' : '${notes.length} 条结果',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.search,
                        color: AppColors.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: '搜索词句、单词、表达...',
                            hintStyle: TextStyle(color: AppColors.hint),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: const Icon(
                            CupertinoIcons.clear_circled_solid,
                            color: AppColors.muted,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _groupExpanded = !_groupExpanded),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.square_grid_2x2,
                              size: 18,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '当前分组',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _selectedGroup,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$selectedCount',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              _groupExpanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 16,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: SingleChildScrollView(
                              child: Column(
                                children: groups
                                    .map(
                                      (group) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: SwipeGroupRow(
                                          label: group,
                                          count: widget.store.groupCount(group),
                                          selected: group == _selectedGroup,
                                          editable: widget.store.isCustomGroup(group),
                                          onTap: () {
                                            setState(() {
                                              _selectedGroup = group;
                                              _groupExpanded = false;
                                            });
                                          },
                                          onRename: () => _renameGroup(group),
                                          onDelete: () => _deleteGroup(group),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        crossFadeState: _groupExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeOutCubic,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: notes.isEmpty
                      ? const EmptyNotesState()
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.84,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return NoteCard(
                              note: note,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  CupertinoPageRoute<void>(
                                    builder: (_) => NoteEditorScreen(
                                      store: widget.store,
                                      noteId: note.id,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () => _showCardActions(note),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCardActions(NoteItem note) async {
    final result = await showModalBottomSheet<_CardActionResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionTile(
              icon: CupertinoIcons.folder,
              title: '调整分组',
              subtitle: '当前分组：${note.group}',
              onTap: () => Navigator.of(context).pop(
                const _CardActionResult(action: _CardAction.move),
              ),
            ),
            const SizedBox(height: 8),
            ActionTile(
              icon: CupertinoIcons.delete,
              title: '删除笔记',
              subtitle: '此操作不可撤回',
              destructive: true,
              onTap: () => Navigator.of(context).pop(
                const _CardActionResult(action: _CardAction.delete),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.action == _CardAction.move) {
      final group = await pickGroup(
        context,
        widget.store.groups.where((group) => group != NotesStore.allGroupsLabel),
        selected: note.group,
        title: '调整分组',
      );
      if (group != null) {
        await widget.store.moveNote(note.id, group);
      }
      return;
    }

    final confirmed = await showDeleteDialog(context);
    if (confirmed) {
      await widget.store.deleteNote(note.id);
    }
  }

  Future<void> _renameGroup(String group) async {
    final nextName = await showGroupNameDialog(
      context,
      title: '重命名分组',
      initialValue: group,
      actionLabel: '保存',
    );
    if (nextName == null) {
      return;
    }
    await widget.store.renameGroup(group, nextName);
    if (!mounted) {
      return;
    }
    setState(() {
      if (_selectedGroup == group) {
        _selectedGroup = nextName;
      }
    });
  }

  Future<void> _deleteGroup(String group) async {
    final confirmed = await showGroupDeleteDialog(
      context,
      group,
      noteCount: widget.store.groupCount(group),
    );
    if (!confirmed) {
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
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.store, required this.noteId});

  final NotesStore store;
  final String noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _controller;
  late String _group;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final note = widget.store.noteById(widget.noteId)!;
    _controller = TextEditingController(text: note.content);
    _group = note.group;
    _controller.addListener(() {
      setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.store.noteById(widget.noteId);
    if (note == null) {
      return const SizedBox.shrink();
    }

    return AppScaffold(
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            DetailHeader(
              eyebrow: 'FULL NOTE',
              title: '阅读与编辑',
              subtitle: '编辑于 ${AppDateFormatter.full(note.updatedAt)}',
              trailingIcon: CupertinoIcons.check_mark,
              onBack: () => Navigator.of(context).pop(),
              onAction: _save,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GroupPill(
                            label: _group,
                            icon: CupertinoIcons.folder,
                            onTap: () async {
                              final group = await pickGroup(
                                context,
                                widget.store.groups.where(
                                  (g) => g != NotesStore.allGroupsLabel,
                                ),
                                selected: _group,
                                title: '调整分组',
                              );
                              if (group != null) {
                                setState(() {
                                  _group = group;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '创建于 ${AppDateFormatter.shortDate(note.createdAt)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.72,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '开始编辑你的笔记...',
                          hintStyle: TextStyle(
                            color: AppColors.hint,
                            fontSize: 22,
                            height: 1.7,
                          ),
                          counterText: '',
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dirty ? '内容已变更，点右上角保存' : '当前内容已保存',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          '${_controller.text.trim().characters.length} 字',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final note = widget.store.noteById(widget.noteId);
    if (note == null) {
      return;
    }

    final content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }

    await widget.store.updateNote(
      note.copyWith(content: content, group: _group, updatedAt: DateTime.now()),
    );

    if (!mounted) {
      return;
    }
    setState(() => _dirty = false);
  }
}
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GradientBackdrop()),
          child,
        ],
      ),
    );
  }
}

class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6FBFF), Color(0xFFDCE8EE)],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -20,
            left: -36,
            child: BlurredOrb(
              size: 250,
              colors: [Color(0xFFFFFFFF), Color(0xA5D9E9F0)],
            ),
          ),
          Positioned(
            top: 92,
            right: -8,
            child: BlurredOrb(
              size: 188,
              colors: [Color(0xC5E5F6FB), Color(0x77FFFFFF)],
            ),
          ),
          Positioned(
            bottom: -60,
            left: 72,
            child: BlurredOrb(
              size: 270,
              colors: [Color(0x88B7D2DD), Color(0x55FFFFFF)],
            ),
          ),
          Positioned(
            bottom: 140,
            right: 12,
            child: BlurredOrb(
              size: 160,
              colors: [Color(0xA7E3F4EE), Color(0x8AFFFFFF)],
            ),
          ),
        ],
      ),
    );
  }
}

class BlurredOrb extends StatelessWidget {
  const BlurredOrb({super.key, required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 32,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A1E3D4B),
                blurRadius: 40,
                offset: Offset(0, 24),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x9EFFFFFF), Color(0x48FFFFFF)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class HeroActionCard extends StatelessWidget {
  const HeroActionCard({
    super.key,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.reverseGlow = false,
  });

  final String label;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool reverseGlow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Stack(
          children: [
            Align(
              alignment: reverseGlow ? Alignment.topRight : Alignment.bottomLeft,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(180),
                  gradient: LinearGradient(
                    colors: reverseGlow
                        ? const [Color(0x80D9FAEF), Color(0x10FFFFFF)]
                        : const [Color(0x8AFFFFFF), Color(0x18FFFFFF)],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0x61FFFFFF),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.05,
                    letterSpacing: -1.1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 220,
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.onAction,
    this.trailingIcon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onAction;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HeaderButton(
          icon: CupertinoIcons.back,
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.6,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (onAction != null && trailingIcon != null)
          HeaderButton(icon: trailingIcon!, onTap: onAction!)
        else
          const SizedBox(width: 48, height: 48),
      ],
    );
  }
}

class HeaderButton extends StatelessWidget {
  const HeaderButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Icon(icon, size: 20, color: AppColors.accent),
      ),
    );
  }
}
class GroupPill extends StatelessWidget {
  const GroupPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0x3DFFFFFF),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: AppColors.muted,
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0x65FFFFFF) : const Color(0x28FFFFFF),
          border: Border.all(
            color: selected ? const Color(0xCCFFFFFF) : AppColors.line,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    required this.editable,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final String label;
  final int count;
  final bool selected;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<SwipeGroupRow> createState() => _SwipeGroupRowState();
}

class _SwipeGroupRowState extends State<SwipeGroupRow> {
  static const double _maxOffset = kGroupActionWidth * 2;
  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.editable) {
      return GroupRowButton(
        label: widget.label,
        count: widget.count,
        selected: widget.selected,
        onTap: widget.onTap,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 52,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SwipeActionButton(
                    label: '重命名',
                    color: const Color(0xFF2F6B7D),
                    onTap: () {
                      _close();
                      widget.onRename();
                    },
                  ),
                  _SwipeActionButton(
                    label: '删除',
                    color: const Color(0xFFC04D4D),
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(_offset, 0, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_offset != 0) {
                    _close();
                    return;
                  }
                  widget.onTap();
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _offset = (_offset + details.delta.dx).clamp(-_maxOffset, 0.0);
                  });
                },
                onHorizontalDragEnd: (details) {
                  final shouldOpen =
                      details.primaryVelocity == null
                          ? _offset.abs() > _maxOffset / 2
                          : details.primaryVelocity! < -120;
                  setState(() {
                    _offset = shouldOpen ? -_maxOffset : 0;
                  });
                },
                child: GroupRowButton(
                  label: widget.label,
                  count: widget.count,
                  selected: widget.selected,
                  onTap: widget.onTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _close() {
    if (mounted) {
      setState(() => _offset = 0);
    }
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kGroupActionWidth,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassPanel(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.group,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                note.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.52,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '编辑于 ${AppDateFormatter.full(note.updatedAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyNotesState extends StatelessWidget {
  const EmptyNotesState({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '空白档案',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '换个关键词试试，或先回首页创建新的语言学习笔记。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.muted,
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
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: GlassPanel(
        radius: 30,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x65FFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFC04D4D) : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0x30FFFFFF),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
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

Future<String?> pickGroup(
  BuildContext context,
  Iterable<String> groups, {
  required String selected,
  required String title,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GroupPickerSheet(
      title: title,
      selected: selected,
      groups: groups.where((group) => group != NotesStore.allGroupsLabel).toList(),
    ),
  );
}

class _GroupPickerSheet extends StatefulWidget {
  const _GroupPickerSheet({
    required this.title,
    required this.selected,
    required this.groups,
  });

  final String title;
  final String selected;
  final List<String> groups;

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedText = _controller.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: GlassBottomSheet(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.76,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '选择已有分组，或直接创建新的分组名。',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.groups.map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GroupRowButton(
                            label: group,
                            count: 0,
                            selected: group == widget.selected,
                            onTap: () => Navigator.of(context).pop(group),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0x30FFFFFF),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '新建分组，例如：口语、阅读、语法',
                            hintStyle: TextStyle(color: AppColors.hint),
                          ),
                          onSubmitted: (value) {
                            final nextGroup = value.trim();
                            if (nextGroup.isNotEmpty) {
                              Navigator.of(context).pop(nextGroup);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: trimmedText.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(trimmedText),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF153A45),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('使用这个分组'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}

Future<String?> showGroupNameDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String actionLabel,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0x30FFFFFF),
                border: Border.all(color: AppColors.line),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '输入新的分组名',
                  hintStyle: TextStyle(color: AppColors.hint),
                ),
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) {
                    Navigator.of(context).pop(trimmed);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final trimmed = controller.text.trim();
                  if (trimmed.isNotEmpty) {
                    Navigator.of(context).pop(trimmed);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF153A45),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  return result;
}
Future<bool> showGroupDeleteDialog(
  BuildContext context,
  String group, {
  required int noteCount,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text('删除分组“$group”？'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('该分组下的 $noteCount 条笔记会移动到“${NotesStore.defaultGroup}”。'),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> showDeleteDialog(BuildContext context) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('删除笔记？'),
      content: const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('删除后无法恢复。'),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class NoteItem {
  NoteItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.group,
  });

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      group: json['group'] as String? ?? NotesStore.defaultGroup,
    );
  }

  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String group;

  NoteItem copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? group,
  }) {
    return NoteItem(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'group': group,
    };
  }
}

class NotesStore extends ChangeNotifier {
  NotesStore(this.preferences);

  static const storageKey = 'lumen_notes';
  static const defaultGroup = '未分组';
  static const allGroupsLabel = '全部笔记';

  final SharedPreferences preferences;
  final List<NoteItem> _notes = [];

  List<NoteItem> get notes => List.unmodifiable(_notes);

  List<String> get groups {
    final set = <String>{allGroupsLabel, defaultGroup};
    for (final note in _notes) {
      set.add(note.group.trim().isEmpty ? defaultGroup : note.group.trim());
    }
    final list = set.toList();
    final custom = list
        .where((group) => group != allGroupsLabel && group != defaultGroup)
        .toList()
      ..sort();
    return [allGroupsLabel, defaultGroup, ...custom];
  }

  Future<void> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    _notes
      ..clear()
      ..addAll(
        decoded
            .map((item) => NoteItem.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );
    notifyListeners();
  }

  Future<void> addNote({required String content, required String group}) async {
    final now = DateTime.now();
    final note = NoteItem(
      id: '${now.microsecondsSinceEpoch}-${_notes.length}',
      content: content,
      createdAt: now,
      updatedAt: now,
      group: _sanitizeGroup(group),
    );
    _notes.insert(0, note);
    await _persist();
  }

  Future<void> updateNote(NoteItem next) async {
    final index = _notes.indexWhere((note) => note.id == next.id);
    if (index == -1) {
      return;
    }
    _notes[index] = next;
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
  }

  Future<void> moveNote(String noteId, String group) async {
    final note = noteById(noteId);
    if (note == null) {
      return;
    }
    await updateNote(
      note.copyWith(group: _sanitizeGroup(group), updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((note) => note.id == noteId);
    await _persist();
  }

  NoteItem? noteById(String noteId) {
    for (final note in _notes) {
      if (note.id == noteId) {
        return note;
      }
    }
    return null;
  }

  List<NoteItem> filteredNotes({required String query, required String group}) {
    final lowerQuery = query.trim().toLowerCase();
    return _notes.where((note) {
      final matchesGroup =
          group == allGroupsLabel ? true : note.group == _sanitizeGroup(group);
      final matchesQuery =
          lowerQuery.isEmpty || note.content.toLowerCase().contains(lowerQuery);
      return matchesGroup && matchesQuery;
    }).toList();
  }

  int groupCount(String group) {
    if (group == allGroupsLabel) {
      return _notes.length;
    }
    return _notes.where((note) => note.group == _sanitizeGroup(group)).length;
  }

  bool isCustomGroup(String group) {
    return group != allGroupsLabel && group != defaultGroup;
  }

  Future<void> renameGroup(String previousGroup, String nextGroup) async {
    if (!isCustomGroup(previousGroup)) {
      return;
    }
    final sanitized = _sanitizeGroup(nextGroup);
    if (sanitized == previousGroup) {
      return;
    }
    final now = DateTime.now();
    for (var index = 0; index < _notes.length; index++) {
      final note = _notes[index];
      if (note.group == previousGroup) {
        _notes[index] = note.copyWith(group: sanitized, updatedAt: now);
      }
    }
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
  }

  Future<void> deleteGroup(String group) async {
    if (!isCustomGroup(group)) {
      return;
    }
    final now = DateTime.now();
    for (var index = 0; index < _notes.length; index++) {
      final note = _notes[index];
      if (note.group == group) {
        _notes[index] = note.copyWith(group: defaultGroup, updatedAt: now);
      }
    }
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
  }

  Future<void> _persist() async {
    final payload = jsonEncode(_notes.map((note) => note.toJson()).toList());
    await preferences.setString(storageKey, payload);
    notifyListeners();
  }

  String _sanitizeGroup(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == allGroupsLabel) {
      return defaultGroup;
    }
    return trimmed;
  }
}

class AppDateFormatter {
  static String full(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}/$month/$day  $hour:$minute';
  }

  static String shortDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}/$month/$day';
  }
}

class AppColors {
  static const ink = Color(0xFF0E2229);
  static const muted = Color(0x99102029);
  static const hint = Color(0x66102029);
  static const accent = Color(0xFF163A46);
  static const line = Color(0x9EFFFFFF);
}

enum _CardAction { move, delete }

class _CardActionResult {
  const _CardActionResult({required this.action});

  final _CardAction action;
}
