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

  /// Clears the in-memory cache (useful for tests / hot reload).
  void invalidate() => _cache = null;
}
