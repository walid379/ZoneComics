import 'package:flutter_test/flutter_test.dart';
import 'package:zone_comics/comic.dart';

void main() {
  test('les statuts, la note et le volume survivent à la sauvegarde', () {
    const comic = Comic(id: '1', title: 'Fantastic Four', publisher: Publisher.marvel, status: ReadingStatus.read, issue: '257', year: '1961', rating: 4, notes: 'Très bon');
    final restored = decodeComics(encodeComics([comic])).single;
    expect(restored.title, 'Fantastic Four');
    expect(restored.issue, '257');
    expect(restored.year, '1961');
    expect(restored.status, ReadingStatus.read);
    expect(restored.rating, 4);
    expect(restored.notes, 'Très bon');
  });
  test('les sorties sont interprétées avec la date magasin', () {
    final release = Release.fromMetron({'id': 12, 'series': {'name': 'Wonder Woman'}, 'number': '8', 'store_date': '2026-10-07'}, Publisher.dc);
    expect(release.title, 'Wonder Woman');
    expect(release.date, DateTime(2026, 10, 7));
    expect(release.publisher, Publisher.dc);
  });
  test('un ancien numéro sans date reste recherchable', () {
    final issue = CatalogueIssue.fromMetron(
      {'series': {'name': 'Fantastic Four', 'year_began': 1961}, 'number': '257'},
      publisher: Publisher.marvel,
    );
    expect(issue.year, '1961');
    expect(issue.issue, '257');
  });
  test('la recherche sépare le titre et le numéro avec ou sans dièse', () {
    expect(
      parseComicSearch('Fantastic Four 394'),
      (title: 'Fantastic Four', issue: '394'),
    );
    expect(
      parseComicSearch('Fantastic Four #394'),
      (title: 'Fantastic Four', issue: '394'),
    );
    expect(
      parseComicSearch('Fantastic Four'),
      (title: 'Fantastic Four', issue: ''),
    );
  });
}
