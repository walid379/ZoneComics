import 'dart:convert';
import 'package:http/http.dart' as http;
import 'comic.dart';

class MetronException implements Exception {
  const MetronException(this.message);
  final String message;
  @override String toString() => message;
}

class MetronApi {
  MetronApi(this.username, this.password, {http.Client? client}) : _client = client ?? http.Client();
  final String username;
  final String password;
  final http.Client _client;
  Map<String, String> get _headers => {'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}', 'Accept': 'application/json'};
  void close() => _client.close();

  Future<Map<String, dynamic>> _get(Uri uri) async {
    late http.Response response;
    try { response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 16)); } catch (_) { throw const MetronException('Connexion impossible. Vérifie Internet puis réessaie.'); }
    if (response.statusCode == 401) throw const MetronException('Identifiants Metron incorrects. Ouvre les réglages.');
    if (response.statusCode == 429) throw const MetronException('Limite Metron atteinte. Réessaie plus tard.');
    if (response.statusCode != 200) throw MetronException('Metron a répondu avec le code ${response.statusCode}.');
    try { return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>; } catch (_) { throw const MetronException('Réponse Metron illisible.'); }
  }

  Future<List<Release>> upcoming({DateTime? today}) async {
    final now = today ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 60));
    String date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final releases = <Release>[];
    for (final publisher in Publisher.values) {
      final name = publisher == Publisher.marvel ? 'Marvel' : 'DC Comics';
      Uri? next = Uri.https('metron.cloud', '/api/issue/', {'publisher_name': name, 'store_date_range_after': date(start), 'store_date_range_before': date(end)});
      for (var page = 0; next != null && page < 2; page++) {
        final data = await _get(next);
        for (final raw in (data['results'] as List? ?? [])) {
          try { final release = Release.fromMetron(raw as Map<String, dynamic>, publisher); if (!release.date.isBefore(start) && !release.date.isAfter(end)) releases.add(release); } catch (_) { /* Incomplete issue metadata is skipped. */ }
        }
        final nextValue = data['next'] as String?;
        final candidate = nextValue == null ? null : Uri.tryParse(nextValue);
        next = candidate?.scheme == 'https' && candidate?.host == 'metron.cloud' ? candidate : null;
      }
    }
    releases.sort((a, b) => a.date.compareTo(b.date));
    return releases;
  }

  Future<List<CatalogueIssue>> search(String query) async {
    final parsed = parseComicSearch(query);
    final seriesName = parsed.title;
    final issueNumber = parsed.issue.isEmpty ? null : parsed.issue;
    if (seriesName.isEmpty) return [];
    final results = <CatalogueIssue>[];
    final seen = <String>{};
    for (final publisher in Publisher.values) {
      final publisherName = publisher == Publisher.marvel ? 'Marvel' : 'DC Comics';
      Uri? next = Uri.https(
        'metron.cloud',
        '/api/issue/',
        {
          'series_name': seriesName,
          'publisher_name': publisherName,
          if (issueNumber != null) 'number': issueNumber,
        },
      );
      for (var page = 0; next != null && page < 10; page++) {
        final data = await _get(next);
        for (final raw in (data['results'] as List? ?? [])) {
          try {
            final issue = CatalogueIssue.fromMetron(
              raw as Map<String, dynamic>,
              publisher: publisher,
            );
            final key = '${issue.publisher.name}|${issue.title}|${issue.issue}|${issue.year}';
            if (seen.add(key)) results.add(issue);
          } catch (_) {
            // Incomplete catalogue records are skipped.
          }
        }
        final nextValue = data['next'] as String?;
        final candidate = nextValue == null ? null : Uri.tryParse(nextValue);
        next = candidate?.scheme == 'https' && candidate?.host == 'metron.cloud'
            ? candidate
            : null;
      }
    }
    results.sort((a, b) {
      final titleComparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (titleComparison != 0) return titleComparison;
      return a.issue.compareTo(b.issue);
    });
    return results;
  }
}
