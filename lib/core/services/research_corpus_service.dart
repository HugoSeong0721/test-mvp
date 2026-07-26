import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A single research paper collected by `tools/fetch_tcm_papers.py` and bundled
/// with the app as the `research/papers.json` asset.
class ResearchPaper {
  const ResearchPaper({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.source,
    required this.url,
    required this.abstract,
    required this.matchedQueries,
    required this.firstSeen,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String year;
  final String source;
  final String url;
  final String abstract;
  final List<String> matchedQueries;
  final String firstSeen;

  factory ResearchPaper.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return ResearchPaper(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      authors: asStringList(json['authors']),
      year: (json['year'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      abstract: (json['abstract'] ?? '').toString(),
      matchedQueries: asStringList(json['matched_queries']),
      firstSeen: (json['first_seen'] ?? '').toString(),
    );
  }

  /// A compact author line, e.g. "A Li, B Wang, C Chen et al.".
  String get authorLine {
    if (authors.isEmpty) return '';
    if (authors.length <= 3) return authors.join(', ');
    return '${authors.take(3).join(', ')} et al.';
  }

  /// True if [query] appears in the title, abstract, source, or authors.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (abstract.toLowerCase().contains(q)) return true;
    if (source.toLowerCase().contains(q)) return true;
    return authors.any((a) => a.toLowerCase().contains(q));
  }

  /// Token-based relevance score for [query]: each query word found in the
  /// title counts 3, in the abstract counts 1. Zero means no overlap. This is
  /// what lets a clinical phrase like "spleen qi damp digestion" surface the
  /// right papers even when no single substring matches.
  int relevanceScore(String query) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 2)
        .toSet();
    if (terms.isEmpty) return 0;
    final titleLower = title.toLowerCase();
    final abstractLower = abstract.toLowerCase();
    var score = 0;
    for (final term in terms) {
      if (titleLower.contains(term)) score += 3;
      if (abstractLower.contains(term)) score += 1;
    }
    return score;
  }
}

/// Loads the bundled TCM research corpus.
///
/// The corpus is refreshed daily in the repository by a scheduled GitHub Action
/// and ships with the app as a build-time asset, so each release carries the
/// latest accumulated literature. This is decision support for a licensed
/// practitioner, not a source of automated patient diagnosis.
class ResearchCorpusService {
  ResearchCorpusService._();

  static final ResearchCorpusService instance = ResearchCorpusService._();

  static const _assetPath = 'research/papers.json';

  List<ResearchPaper>? _cache;

  /// Loads and caches the corpus. Returns an empty list if the asset is
  /// missing or malformed, so the UI can degrade gracefully.
  Future<List<ResearchPaper>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _cache = const [];
        return _cache!;
      }
      final papers = decoded
          .whereType<Map<String, dynamic>>()
          .map(ResearchPaper.fromJson)
          .toList();
      // Newest first, then by title for stable ordering.
      papers.sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        if (byYear != 0) return byYear;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      _cache = papers;
      return papers;
    } catch (_) {
      _cache = const [];
      return _cache!;
    }
  }

  /// Returns the corpus papers most relevant to [query], ranked by
  /// [ResearchPaper.relevanceScore], best first. Papers with no term overlap
  /// are excluded, so an off-topic query returns an empty list rather than
  /// arbitrary papers.
  Future<List<ResearchPaper>> topMatches(String query, {int limit = 5}) async {
    final papers = await load();
    final scored = <(int, ResearchPaper)>[];
    for (final paper in papers) {
      final score = paper.relevanceScore(query);
      if (score > 0) scored.add((score, paper));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.take(limit).map((e) => e.$2).toList();
  }

  /// Clears the in-memory cache (useful for tests / hot reload).
  void invalidate() => _cache = null;
}
