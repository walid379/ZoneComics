# Zone Comics — application Flutter Android

## Démarrer dans Android Studio (Windows)

1. Installe Flutter et Android Studio (plugins Flutter et Dart), puis vérifie `flutter doctor` dans PowerShell.
2. Décompresse le ZIP. Depuis PowerShell, dans le dossier `ZoneComics`, lance `powershell -ExecutionPolicy Bypass -File .\setup_android.ps1`. Cette commande crée le module Android standard avec le SDK Flutter présent sur ton PC.
3. Dans Android Studio, **File > Open**, sélectionne le dossier **ZoneComics** (racine du projet). Branche ton téléphone avec le débogage USB activé et lance `lib/main.dart` avec ▶. `flutter run` fonctionne aussi.
4. Pour générer un APK installable, lance `powershell -ExecutionPolicy Bypass -File .\build_apk.ps1`. Copie `build\app\outputs\flutter-apk\app-debug.apk` sur ton téléphone. Cet APK debug est signé automatiquement par Flutter pour l'essai personnel ; pour diffuser une version release, configure ta propre signature Android.

Le projet cible Android 6.0 (API 23) minimum pour protéger les identifiants Metron.

Le dossier `android/` est généré sur ton PC par `flutter create`, pour garder une plateforme Android compatible avec ta version locale de Flutter/Gradle. Les fichiers de l'application sont sous `lib/` et restent modifiables dans Android Studio. La bibliothèque et le cache des sorties sont enregistrés dans une base SQLite privée sur le téléphone. Les anciennes données JSON sont migrées automatiquement au premier démarrage. La suppression de l'application efface les données locales.

## Fonctionnalités

- Bibliothèque SQLite : ajout, modification, suppression, recherche et filtres par éditeur ou statut.
- Ajout unifié : recherche Metron et création manuelle depuis le même écran ; si aucun résultat n'existe, le formulaire manuel est prérempli.
- Lecture : la note sur 5 est proposée uniquement lorsque le statut est **Lu**.
- Sorties : calendrier mensuel Marvel/DC, sélection par journée, cache SQLite et actualisation manuelle.
- Mode invité : aucun compte Metron n'est nécessaire pour gérer la bibliothèque. La connexion Metron reste facultative pour la recherche distante et l'actualisation des sorties.
- Réglages : les identifiants Metron sont enregistrés dans le stockage sécurisé du téléphone, jamais dans SQLite.
- Identité Android : nom affiché **Zone Comics** et logo personnalisé généré depuis `assets/icon/app_icon.png`.

Pour réappliquer le nom et le logo sur un projet Android déjà initialisé, lance `powershell -ExecutionPolicy Bypass -File .\apply_branding.ps1` à la racine du projet.

Metron est une base communautaire : les annonces peuvent être incomplètes ou changer. Les sorties interrogent au maximum deux pages par éditeur et par rafraîchissement ; l'écran peut donc omettre des titres si le volume de résultats est élevé. Les couvertures et images ne sont pas nécessaires à l'utilisation.

## Structure

- `lib/comic.dart` : modèles et états de lecture.
- `lib/repository.dart` : sauvegarde locale et identifiants sécurisés.
- `lib/metron_api.dart` : requêtes Metron.
- `lib/main.dart` : interface Flutter.
