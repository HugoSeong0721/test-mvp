import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/research_corpus_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/practitioner_shell.dart';

/// Practitioner-only view onto the accumulated TCM research corpus
/// (`research/papers.json`, refreshed daily by a scheduled GitHub Action).
///
/// This surfaces the literature behind the adaptive-inquiry direction as
/// decision support — it is not a source of automated patient diagnosis.
class ResearchLibraryScreen extends StatefulWidget {
  const ResearchLibraryScreen({super.key});

  static const routeName = '/research-library';

  @override
  State<ResearchLibraryScreen> createState() => _ResearchLibraryScreenState();
}

class _ResearchLibraryScreenState extends State<ResearchLibraryScreen> {
  final _searchController = TextEditingController();
  late Future<List<ResearchPaper>> _future;
  String _query = '';
  bool _seededFromRoute = false;

  @override
  void initState() {
    super.initState();
    _future = ResearchCorpusService.instance.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A pattern-direction chip on the dashboard can open this screen with a
    // pre-filled evidence query passed as route arguments.
    if (!_seededFromRoute) {
      _seededFromRoute = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.trim().isNotEmpty) {
        _searchController.text = args;
        _query = args;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return PractitionerShell(
      currentItem: PractitionerNavItem.insights,
      title: lang.tr('Research Library', '연구 자료실'),
      actions: const [LanguageMenuButton()],
      body: FutureBuilder<List<ResearchPaper>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? const <ResearchPaper>[];
          // Rank by token relevance so multi-word clinical queries (e.g. from
          // a pattern-direction chip) surface the best-matching papers first;
          // substring matching keeps author/source search working.
          final query = _query.trim();
          late final List<ResearchPaper> filtered;
          if (query.isEmpty) {
            filtered = all;
          } else {
            final scored = <(int, ResearchPaper)>[];
            for (final p in all) {
              final score = p.relevanceScore(query);
              if (score > 0 || p.matches(query)) scored.add((score, p));
            }
            scored.sort((a, b) => b.$1.compareTo(a.$1));
            filtered = scored.map((e) => e.$2).toList(growable: false);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(
                        'Auto-collected papers on TCM syndrome differentiation '
                        'and adaptive inquiry. Decision support for a licensed '
                        'practitioner — not automated diagnosis.',
                        '변증 및 적응형 문진 관련 자동 수집 논문입니다. 자동 진단이 아닌, '
                        '면허 한의사를 위한 의사결정 보조 자료입니다.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: lang.tr(
                          'Search title, abstract, author…',
                          '제목·초록·저자 검색…',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang.tr(
                        '${filtered.length} of ${all.length} papers',
                        '논문 ${all.length}건 중 ${filtered.length}건',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? _EmptyState(lang: lang)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _PaperCard(paper: filtered[index], lang: lang),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang});

  final AppLanguageController lang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              lang.tr(
                'No papers yet',
                '아직 수집된 논문이 없습니다',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              lang.tr(
                'The daily collector will populate this library on its next run. '
                'You can also trigger it manually from the repository\'s Actions tab.',
                '매일 실행되는 수집기가 다음 실행 때 이 자료실을 채웁니다. '
                '저장소의 Actions 탭에서 수동으로 실행할 수도 있습니다.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.paper, required this.lang});

  final ResearchPaper paper;
  final AppLanguageController lang;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (paper.year.isNotEmpty) paper.year,
      if (paper.source.isNotEmpty) paper.source,
      if (paper.authorLine.isNotEmpty) paper.authorLine,
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paper.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meta,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (paper.abstract.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                paper.abstract,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
            if (paper.url.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      paper.url,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: lang.tr('Copy link', '링크 복사'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: paper.url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text(lang.tr('Link copied', '링크를 복사했습니다')),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
