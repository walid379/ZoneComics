import 'dart:convert';

enum ReadingStatus { toRead, reading, read, paused, dropped }

extension ReadingStatusLabel on ReadingStatus {
  String get label => switch (this) {
        ReadingStatus.toRead => 'À lire',
        ReadingStatus.reading => 'En cours',
        ReadingStatus.read => 'Lu',
        ReadingStatus.paused => 'En pause',
        ReadingStatus.dropped => 'Abandonné',
      };
}

enum Publisher { marvel, dc }

extension PublisherLabel on Publisher {
  String get label => this == Publisher.marvel ? 'Marvel' : 'DC';
}

class Comic {
  const Comic({required this.id, required this.title, required this.publisher, required this.status, this.issue = '', this.year = '', this.rating = 0, this.notes = ''});
  final String id;
  final String title;
  final Publisher publisher;
  final ReadingStatus status;
  final String issue;
  final String year;
  final int rating;
  final String notes;

  Comic copyWith({String? title, Publisher? publisher, ReadingStatus? status, String? issue, String? year, int? rating, String? notes}) => Comic(id: id, title: title ?? this.title, publisher: publisher ?? this.publisher, status: status ?? this.status, issue: issue ?? this.issue, year: year ?? this.year, rating: rating ?? this.rating, notes: notes ?? this.notes);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'publisher': publisher.name, 'status': status.name, 'issue': issue, 'year': year, 'rating': rating, 'notes': notes};
  factory Comic.fromJson(Map<String, dynamic> json) => Comic(id: json['id'] as String, title: json['title'] as String, publisher: Publisher.values.firstWhere((e) => e.name == json['publisher'], orElse: () => Publisher.marvel), status: ReadingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => ReadingStatus.toRead), issue: json['issue'] as String? ?? '', year: json['year'] as String? ?? '', rating: (json['rating'] as num?)?.toInt() ?? 0, notes: json['notes'] as String? ?? '');
}

class Release {
  const Release({required this.id, required this.title, required this.publisher, required this.date, this.issue = '', this.image = ''});
  final int id;
  final String title;
  final Publisher publisher;
  final DateTime date;
  final String issue;
  final String image;

  factory Release.fromMetron(Map<String, dynamic> json, Publisher publisher) {
    final series = json['series'];
    final name = series is Map ? (series['name'] ?? series['title'])?.toString() : series?.toString();
    final image = json['image'];
    return Release(id: (json['id'] as num).toInt(), title: name?.trim().isNotEmpty == true ? name!.trim() : (json['name'] ?? json['title'] ?? 'Titre inconnu').toString(), publisher: publisher, date: DateTime.parse(json['store_date'] as String), issue: (json['number'] ?? '').toString(), image: image is String ? image : '');
  }
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'publisher': publisher.name, 'date': date.toIso8601String(), 'issue': issue, 'image': image};
  factory Release.fromJson(Map<String, dynamic> json) => Release(id: (json['id'] as num).toInt(), title: json['title'] as String, publisher: Publisher.values.byName(json['publisher'] as String), date: DateTime.parse(json['date'] as String), issue: json['issue'] as String? ?? '', image: json['image'] as String? ?? '');
}

class CatalogueIssue {
  const CatalogueIssue({required this.title, required this.publisher, this.issue = '', this.year = ''});
  final String title;
  final Publisher publisher;
  final String issue;
  final String year;

  factory CatalogueIssue.fromMetron(
    Map<String, dynamic> json, {
    Publisher? publisher,
  }) {
    final series = json['series'];
    final seriesMap = series is Map ? series : <String, dynamic>{};
    final rawPublisher = json['publisher'] ?? seriesMap['publisher'];
    final publisherName = (rawPublisher is Map ? rawPublisher['name'] : rawPublisher)?.toString().toLowerCase() ?? '';
    final detectedPublisher = publisher ??
        (publisherName.contains('marvel')
            ? Publisher.marvel
            : publisherName.contains('dc')
                ? Publisher.dc
                : null);
    if (detectedPublisher == null) {
      throw const FormatException('Unknown publisher');
    }
    final title = (seriesMap['name'] ?? json['series_name'] ?? json['name'] ?? json['title'] ?? '').toString().trim();
    if (title.isEmpty) throw const FormatException('Missing title');
    final date = DateTime.tryParse((json['store_date'] ?? json['cover_date'] ?? '').toString());
    return CatalogueIssue(title: title, publisher: detectedPublisher, issue: (json['number'] ?? '').toString(), year: (seriesMap['year_began'] ?? date?.year ?? '').toString());
  }
}

String encodeComics(List<Comic> comics) => jsonEncode(comics.map((e) => e.toJson()).toList());
List<Comic> decodeComics(String value) => (jsonDecode(value) as List).map((e) => Comic.fromJson(e as Map<String, dynamic>)).toList();

({String title, String issue}) parseComicSearch(String value) {
  final query = value.trim();
  final match = RegExp(r'(?:#\s*|\s+)([0-9][^\s#]*)\s*$').firstMatch(query);
  if (match == null) return (title: query, issue: '');
  return (
    title: query.substring(0, match.start).trim(),
    issue: match.group(1) ?? '',
  );
}
