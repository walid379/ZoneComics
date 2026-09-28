import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'comic.dart';
import 'metron_api.dart';
import 'repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZoneComicsApp());
}

const ink = Color(0xFF121725);
const canvas = Color(0xFFF5F6FA);
const accent = Color(0xFFD92D45);
const violet = Color(0xFF6558BE);
final baxterVerseUri = Uri.parse('https://comicsverse.tail46e980.ts.net/');

class ZoneComicsApp extends StatelessWidget {
  const ZoneComicsApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Zone Comics', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: canvas, colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent, surface: Colors.white), textTheme: const TextTheme(headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.2, color: ink), titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink), titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink)), inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)), cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repo = ComicRepository();
  final searchController = TextEditingController();
  List<Comic> comics = [];
  List<Release> releases = [];
  int tab = 0;
  ReadingStatus? statusFilter;
  Publisher? publisherFilter;
  bool loading = true;
  bool loadingReleases = false;
  String? releaseError;
  DateTime? refreshed;
  String username = '';
  String password = '';
  late DateTime calendarMonth;
  late DateTime selectedReleaseDate;

  bool get hasMetronAccount => username.isNotEmpty && password.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    calendarMonth = DateTime(now.year, now.month);
    selectedReleaseDate = DateTime(now.year, now.month, now.day);
    _load();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    unawaited(repo.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await repo.initialize();
      final loaded = await repo.loadComics();
      final cache = await repo.cachedReleases();
      final date = await repo.lastRefresh();
      final credentials = await repo.credentials();
      if (!mounted) return;
      setState(() { comics = loaded; releases = cache; refreshed = date; username = credentials.username; password = credentials.password; loading = false; });
      if (username.isNotEmpty && password.isNotEmpty && (date == null || DateTime.now().difference(date).inHours >= 6)) unawaited(_refreshReleases());
    } catch (_) { if (mounted) setState(() { loading = false; releaseError = 'Les données locales sont indisponibles.'; }); }
  }
  Future<void> _save(Comic comic) async {
    final old = List<Comic>.from(comics);
    setState(() { comics = [...comics.where((e) => e.id != comic.id), comic]; });
    try { await repo.upsertComic(comic); } catch (_) { if (mounted) { setState(() => comics = old); _toast('Enregistrement impossible.'); } }
  }
  Future<void> _delete(Comic comic) async {
    final old = List<Comic>.from(comics);
    setState(() => comics = comics.where((e) => e.id != comic.id).toList());
    try { await repo.deleteComic(comic.id); if (mounted) _toast('Comics supprimé.'); } catch (_) { if (mounted) { setState(() => comics = old); _toast('Suppression impossible.'); } }
  }
  Future<void> _refreshReleases() async {
    if (loadingReleases) return;
    if (!hasMetronAccount) { setState(() => releaseError = 'La connexion Metron est facultative, mais nécessaire pour actualiser les sorties.'); return; }
    setState(() { loadingReleases = true; releaseError = null; });
    final api = MetronApi(username, password);
    try {
      final fresh = await api.upcoming();
      await repo.cacheReleases(fresh);
      if (mounted) setState(() { releases = fresh; refreshed = DateTime.now(); });
    } on MetronException catch (e) { if (mounted) setState(() => releaseError = e.message); }
    catch (_) { if (mounted) setState(() => releaseError = 'Impossible de charger les sorties pour le moment.'); }
    finally { api.close(); if (mounted) setState(() => loadingReleases = false); }
  }
  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  Future<void> _openBaxterVerse() async {
    try {
      final opened = await launchUrl(
        baxterVerseUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _toast('Impossible d\'ouvrir BaxterVerse.');
    } catch (_) {
      if (mounted) _toast('Impossible d\'ouvrir BaxterVerse.');
    }
  }
  Future<void> _openEditor([Comic? comic]) async {
    final result = await showModalBottomSheet<Comic>(context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: Colors.white, builder: (_) => ComicEditor(comic: comic));
    if (result != null) await _save(result);
  }
  Future<void> _confirmDelete(Comic comic) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Supprimer ce comics ?'), content: Text(comic.title), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))]));
    if (yes == true) await _delete(comic);
  }
  Future<void> _settings() async {
    final user = TextEditingController(text: username);
    final pass = TextEditingController(text: password);
    final saved = await showModalBottomSheet<({String username, String password})>(context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: Colors.white, builder: (sheetContext) => Padding(padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.viewInsetsOf(sheetContext).bottom + 30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Connexion Metron', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Facultatif : Metron enrichit la recherche et le calendrier. La bibliothèque et l’ajout manuel fonctionnent sans compte.'), const SizedBox(height: 20), TextField(controller: user, decoration: const InputDecoration(labelText: 'Identifiant Metron')), const SizedBox(height: 12), TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe')), const SizedBox(height: 22), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, (username: user.text.trim(), password: pass.text.trim())), child: const Text('Enregistrer'))), if (hasMetronAccount) ...[const SizedBox(height: 8), SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(sheetContext, (username: '', password: '')), child: const Text('Continuer sans compte Metron')))]])));
    user.dispose();
    pass.dispose();
    if (saved == null) return;
    final completeCredentials = saved.username.isNotEmpty && saved.password.isNotEmpty;
    final savedUsername = completeCredentials ? saved.username : '';
    final savedPassword = completeCredentials ? saved.password : '';
    try { await repo.saveCredentials(savedUsername, savedPassword); if (mounted) { setState(() { username = savedUsername; password = savedPassword; releaseError = null; }); _toast(completeCredentials ? 'Compte Metron enregistré.' : 'Mode sans compte Metron activé.'); if (completeCredentials) unawaited(_refreshReleases()); } } catch (_) { if (mounted) _toast('Impossible de sauvegarder les identifiants.'); }
  }
  Future<void> _openAddComic() async {
    final selected = await showModalBottomSheet<CatalogueIssue>(context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: Colors.white, builder: (_) => AddComicSheet(username: username, password: password));
    if (selected != null && mounted) _openEditor(Comic(id: DateTime.now().microsecondsSinceEpoch.toString(), title: selected.title, publisher: selected.publisher, status: ReadingStatus.toRead, issue: selected.issue, year: selected.year));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: canvas,
        elevation: 0,
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories_rounded, color: accent),
              const SizedBox(width: 10),
              const Text(
                'ZONE COMICS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: ink,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _openBaxterVerse,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: ink,
                ),
                child: const Text(
                  'by BaxterVerse',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Réglages Metron',
            onPressed: _settings,
            icon: const Icon(Icons.tune_rounded, color: ink),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : IndexedStack(index: tab, children: [_library(), _upcoming(), _overview()]),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(onPressed: _openAddComic, icon: const Icon(Icons.add), label: const Text('Ajouter'), backgroundColor: accent, foregroundColor: Colors.white) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (index) { setState(() => tab = index); if (index == 1 && releases.isEmpty && refreshed == null && !loadingReleases && hasMetronAccount) unawaited(_refreshReleases()); }, destinations: const [NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), selectedIcon: Icon(Icons.collections_bookmark), label: 'Bibliothèque'), NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Sorties'), NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Bilan')]),
    );
  }
  Widget _library() {
    final query = searchController.text.toLowerCase().trim();
    final filtered = comics.where((comic) => (publisherFilter == null || comic.publisher == publisherFilter) && (statusFilter == null || comic.status == statusFilter) && (query.isEmpty || '${comic.title} ${comic.issue} ${comic.year}'.toLowerCase().contains(query))).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      _hero('Ta collection', '${comics.length} comics répertoriés', Icons.menu_book_rounded),
      const SizedBox(height: 22),
      Row(children: [const Expanded(child: Text('Ma bibliothèque', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink))), TextButton.icon(onPressed: _openAddComic, icon: const Icon(Icons.add_circle_outline, size: 19), label: const Text('Ajouter'))]),
      const SizedBox(height: 10),
      TextField(controller: searchController, decoration: InputDecoration(hintText: 'Chercher un titre, numéro, année', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [ChoiceChip(label: const Text('Tous'), selected: publisherFilter == null, onSelected: (_) => setState(() => publisherFilter = null)), const SizedBox(width: 8), ...Publisher.values.map((p) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(p.label), selected: publisherFilter == p, onSelected: (_) => setState(() => publisherFilter = p)))), const SizedBox(width: 5), PopupMenuButton<ReadingStatus?>(tooltip: 'Filtrer par statut', onSelected: (value) => setState(() => statusFilter = value), itemBuilder: (_) => [const PopupMenuItem<ReadingStatus?>(value: null, child: Text('Tous les statuts')), ...ReadingStatus.values.map((s) => PopupMenuItem<ReadingStatus?>(value: s, child: Text(s.label)))], child: Chip(avatar: const Icon(Icons.filter_list, size: 18), label: Text(statusFilter?.label ?? 'Statut')))])),
      const SizedBox(height: 18),
      if (filtered.isEmpty) _empty(comics.isEmpty ? 'Ta bibliothèque est vide' : 'Aucun comics trouvé', comics.isEmpty ? 'Ajoute ton premier comics avec le bouton ci-dessous.' : 'Modifie la recherche ou les filtres.', Icons.library_books_outlined, comics.isEmpty ? _openAddComic : null) else ...filtered.map((comic) => _comicCard(comic)),
    ]);
  }
  Widget _comicCard(Comic comic) => Card(margin: const EdgeInsets.only(bottom: 10), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => _openEditor(comic), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 50, height: 66, decoration: BoxDecoration(color: comic.publisher == Publisher.marvel ? const Color(0xFFFDECEF) : const Color(0xFFEAF1FF), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.auto_stories, color: comic.publisher == Publisher.marvel ? accent : const Color(0xFF2867CE))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(comic.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)), const SizedBox(height: 3), Text('${comic.publisher.label}${comic.issue.isEmpty ? '' : ' · #${comic.issue}'}${comic.year.isEmpty ? '' : ' · ${comic.year}'}', style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 8), Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [StatusPill(status: comic.status), if (comic.status == ReadingStatus.read && comic.rating > 0) Text('★ ${comic.rating}/5', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE19A1B)))])])), PopupMenuButton<String>(tooltip: 'Options', onSelected: (value) { if (value == 'edit') _openEditor(comic); if (value == 'delete') _confirmDelete(comic); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Modifier')), PopupMenuItem(value: 'delete', child: Text('Supprimer'))])]))));
  Widget _upcoming() {
    final selectedReleases = releases
        .where((release) => _sameDay(release.date, selectedReleaseDate))
        .toList();
    return RefreshIndicator(
      onRefresh: _refreshReleases,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _hero(
            'Prochainement',
            'Marvel & DC · 60 prochains jours',
            Icons.event_available_rounded,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Calendrier des sorties',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: loadingReleases ? null : _refreshReleases,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (refreshed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Mise à jour : ${_date(refreshed!)} à '
                '${refreshed!.hour.toString().padLeft(2, '0')}:'
                '${refreshed!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          if (loadingReleases) const LinearProgressIndicator(),
          if (releaseError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Card(
                color: const Color(0xFFFFE8E9),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Text(releaseError!),
                ),
              ),
            ),
          if (releases.isEmpty && !loadingReleases)
            _empty(
              refreshed == null
                  ? 'Calendrier à configurer'
                  : 'Aucune sortie disponible',
              refreshed == null
                  ? 'Metron est facultatif pour la bibliothèque, mais nécessaire pour charger automatiquement les sorties.'
                  : 'Actualise pour rechercher de nouvelles annonces.',
              Icons.calendar_today_outlined,
              refreshed == null ? _settings : _refreshReleases,
            )
          else ...[
            const SizedBox(height: 8),
            _releaseCalendar(),
            const SizedBox(height: 20),
            Text(
              'Sorties du ${_date(selectedReleaseDate)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            if (selectedReleases.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Aucune sortie annoncée pour cette journée.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ...selectedReleases.map(_releaseCard),
          ],
        ],
      ),
    );
  }

  Widget _releaseCalendar() {
    final firstDay = DateTime(calendarMonth.year, calendarMonth.month, 1);
    final dayCount = DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;
    final leadingEmptyDays = firstDay.weekday - DateTime.monday;
    const weekDays = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  onPressed: () => _changeCalendarMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_monthName(calendarMonth.month)} ${calendarMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  onPressed: () => _changeCalendarMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.25,
              children: weekDays
                  .map(
                    (day) => Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .92,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leadingEmptyDays + dayCount,
              itemBuilder: (_, index) {
                if (index < leadingEmptyDays) return const SizedBox.shrink();
                final day = index - leadingEmptyDays + 1;
                final date = DateTime(calendarMonth.year, calendarMonth.month, day);
                final events = releases.where((release) => _sameDay(release.date, date)).toList();
                final selected = _sameDay(date, selectedReleaseDate);
                final today = _sameDay(date, DateTime.now());
                final hasMarvel = events.any((event) => event.publisher == Publisher.marvel);
                final hasDc = events.any((event) => event.publisher == Publisher.dc);
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => selectedReleaseDate = date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: selected ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: today && !selected
                            ? Border.all(color: accent)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasMarvel)
                                _calendarDot(selected ? Colors.white : accent),
                              if (hasMarvel && hasDc) const SizedBox(width: 3),
                              if (hasDc)
                                _calendarDot(
                                  selected ? Colors.white70 : const Color(0xFF2867CE),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarDot(Color color) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  void _changeCalendarMonth(int offset) {
    final next = DateTime(calendarMonth.year, calendarMonth.month + offset);
    setState(() {
      calendarMonth = next;
      selectedReleaseDate = DateTime(next.year, next.month, 1);
    });
  }

  Widget _releaseCard(Release release) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          leading: Container(
            width: 47,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: release.publisher == Publisher.marvel
                  ? const Color(0xFFFDECEF)
                  : const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              release.publisher.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: release.publisher == Publisher.marvel
                    ? accent
                    : const Color(0xFF2867CE),
              ),
            ),
          ),
          title: Text(
            '${release.title}${release.issue.isEmpty ? '' : ' #${release.issue}'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${release.publisher.label} · ${_date(release.date)}'),
          trailing: IconButton(
            tooltip: 'Ajouter à ma bibliothèque',
            icon: const Icon(Icons.add_circle_outline, color: accent),
            onPressed: () => _openEditor(
              Comic(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: release.title,
                publisher: release.publisher,
                status: ReadingStatus.toRead,
                issue: release.issue,
                year: release.date.year.toString(),
              ),
            ),
          ),
        ),
      );
  Widget _overview() {
    final rated = comics.where((e) => e.status == ReadingStatus.read && e.rating > 0).toList();
    final average = rated.isEmpty ? '—' : (rated.fold<int>(0, (sum, e) => sum + e.rating) / rated.length).toStringAsFixed(1);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
      _hero('Ton parcours', 'Toutes tes lectures au même endroit', Icons.insights_rounded),
      const SizedBox(height: 24), const Text('Vue d’ensemble', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)), const SizedBox(height: 14),
      Row(children: [Expanded(child: _stat('${comics.length}', 'Comics ajoutés', Icons.collections_bookmark, accent)), const SizedBox(width: 10), Expanded(child: _stat(average, 'Note moyenne', Icons.star, const Color(0xFFE5A327)))]), const SizedBox(height: 12),
      Row(children: [Expanded(child: _stat('${comics.where((e) => e.publisher == Publisher.marvel).length}', 'Marvel', Icons.bolt, accent)), const SizedBox(width: 10), Expanded(child: _stat('${comics.where((e) => e.publisher == Publisher.dc).length}', 'DC', Icons.flash_on, const Color(0xFF2867CE)))]),
      const SizedBox(height: 26), const Text('Progression', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)), const SizedBox(height: 12),
      ...ReadingStatus.values.map((s) {
        final count = comics.where((e) => e.status == s).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: comics.isEmpty ? 0 : count / comics.length,
                minHeight: 9,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFFE5E6ED),
                color: s == ReadingStatus.read ? accent : violet,
              ),
            ],
          ),
        );
      }),
    ]);
  }
  Widget _stat(String value, String label, IconData icon, Color color) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 13), Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))])));
  Widget _hero(String title, String subtitle, IconData icon) => Container(height: 150, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF202638), Color(0xFF393044)]), borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.all(22), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.7)), const SizedBox(height: 8), Text(subtitle, style: const TextStyle(color: Color(0xFFCFD2DF), fontSize: 13))])), Icon(icon, size: 55, color: const Color(0xFFED6475))]));
  Widget _empty(String title, String description, IconData icon, VoidCallback? action) => Padding(padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24), child: Center(child: Column(children: [Icon(icon, size: 58, color: const Color(0xFFADB2C1)), const SizedBox(height: 15), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)), if (action != null) ...[const SizedBox(height: 17), FilledButton(onPressed: action, child: const Text('Commencer'))]])));
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final ReadingStatus status;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: status == ReadingStatus.read ? const Color(0xFFE4F6EC) : const Color(0xFFF0EEFB), borderRadius: BorderRadius.circular(10)), child: Text(status.label, style: TextStyle(color: status == ReadingStatus.read ? const Color(0xFF23804D) : violet, fontSize: 11, fontWeight: FontWeight.w800)));
}

class ComicEditor extends StatefulWidget {
  const ComicEditor({super.key, this.comic});
  final Comic? comic;
  @override State<ComicEditor> createState() => _ComicEditorState();
}
class _ComicEditorState extends State<ComicEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title = TextEditingController(text: widget.comic?.title ?? '');
  late final TextEditingController issue = TextEditingController(text: widget.comic?.issue ?? '');
  late final TextEditingController year = TextEditingController(text: widget.comic?.year ?? '');
  late final TextEditingController notes = TextEditingController(text: widget.comic?.notes ?? '');
  late Publisher publisher = widget.comic?.publisher ?? Publisher.marvel;
  late ReadingStatus status = widget.comic?.status ?? ReadingStatus.toRead;
  late int rating = widget.comic?.rating ?? 0;
  @override void dispose() { title.dispose(); issue.dispose(); year.dispose(); notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.comic == null
                      ? 'Ajouter un comics'
                      : 'Modifier le comics',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: title,
                  autofocus: widget.comic == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Renseigne un titre.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: issue,
                        decoration: const InputDecoration(
                          labelText: 'Numéro (ex. 257)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Année / volume',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Publisher>(
                  initialValue: publisher,
                  decoration: const InputDecoration(labelText: 'Éditeur'),
                  items: Publisher.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => publisher = value ?? publisher),
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<ReadingStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: ReadingStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => status = value ?? status),
                ),
                if (status == ReadingStatus.read) ...[
                  const SizedBox(height: 19),
                  const Text(
                    'Ma note',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => IconButton(
                          tooltip: '${index + 1} étoiles',
                          onPressed: () => setState(
                            () => rating = rating == index + 1 ? 0 : index + 1,
                          ),
                          icon: Icon(
                            index < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFE4A224),
                            size: 33,
                          ),
                        ),
                      ),
                      Text(rating == 0 ? 'Non noté' : '$rating / 5'),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes personnelles',
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      Navigator.pop(
                        context,
                        Comic(
                          id: widget.comic?.id ??
                              DateTime.now()
                                  .microsecondsSinceEpoch
                                  .toString(),
                          title: title.text.trim(),
                          publisher: publisher,
                          status: status,
                          issue: issue.text.trim(),
                          year: year.text.trim(),
                          rating: rating,
                          notes: notes.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Enregistrer'),
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

class AddComicSheet extends StatefulWidget {
  const AddComicSheet({super.key, required this.username, required this.password});
  final String username;
  final String password;
  @override State<AddComicSheet> createState() => _AddComicSheetState();
}
class _AddComicSheetState extends State<AddComicSheet> {
  final controller = TextEditingController();
  List<CatalogueIssue> results = [];
  bool busy = false;
  bool hasSearched = false;
  String? error;
  bool get hasMetron => widget.username.isNotEmpty && widget.password.isNotEmpty;

  @override void dispose() { controller.dispose(); super.dispose(); }

  Future<void> search() async {
    if (!hasMetron) {
      _createManually();
      return;
    }
    if (controller.text.trim().isEmpty) return;
    setState(() { busy = true; hasSearched = true; error = null; results = []; });
    final api = MetronApi(widget.username, widget.password);
    try { final found = await api.search(controller.text); if (mounted) setState(() => results = found); }
    on MetronException catch (e) { if (mounted) setState(() => error = e.message); }
    catch (_) { if (mounted) setState(() => error = 'Recherche indisponible.'); }
    finally { api.close(); if (mounted) setState(() => busy = false); }
  }

  void _createManually() {
    final parsed = parseComicSearch(controller.text);
    Navigator.pop(
      context,
      CatalogueIssue(
        title: parsed.title,
        publisher: Publisher.marvel,
        issue: parsed.issue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      3,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajouter un comics',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            hasMetron
                ? 'Recherche Metron ou création manuelle au même endroit.'
                : 'Mode sans compte Metron : l’ajout manuel reste entièrement disponible.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (hasMetron) {
                unawaited(search());
              } else {
                _createManually();
              }
            },
            decoration: InputDecoration(
              labelText: 'Série ou numéro, ex. Fantastic Four 394',
              suffixIcon: hasMetron
                  ? IconButton(
                      tooltip: 'Rechercher sur Metron',
                      icon: const Icon(Icons.search),
                      onPressed: search,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          if (hasMetron)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : search,
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Rechercher'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createManually,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Créer manuellement'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _createManually,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Continuer en ajout manuel'),
              ),
            ),
          const SizedBox(height: 10),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: accent)),
            ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      busy
                          ? 'Recherche en cours…'
                          : hasSearched && error == null
                              ? 'Aucun résultat Metron. Utilise « Créer manuellement » pour poursuivre.'
                              : hasMetron
                                  ? 'Saisis une série ou un numéro précis, puis sélectionne un résultat.'
                                  : 'Renseigne ce que tu connais : le formulaire suivant permettra de compléter les informations.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final result = results[index];
                      return ListTile(
                        title: Text(
                          '${result.title}${result.issue.isEmpty ? '' : ' #${result.issue}'}',
                        ),
                        subtitle: Text(
                          '${result.publisher.label}${result.year.isEmpty ? '' : ' · ${result.year}'}',
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, result),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

String _monthName(int month) => const ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'][month - 1];
bool _sameDay(DateTime first, DateTime second) => first.year == second.year && first.month == second.month && first.day == second.day;
String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
