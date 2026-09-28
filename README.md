# Zone Comics

**Zone Comics** est une application Android permettant de gérer une bibliothèque personnelle de comics Marvel et DC : suivi de lecture, notes, recherche de numéros et calendrier des prochaines sorties.

## Télécharger l'application

[![Télécharger Zone Comics pour Android](https://img.shields.io/badge/T%C3%A9l%C3%A9charger-l%27APK-1976D2?style=for-the-badge&logo=android&logoColor=white)](https://github.com/walid379/ZoneComics/releases/latest)

La dernière version est disponible sur la page **Releases** :

1. Ouvre [la dernière version de Zone Comics](https://github.com/walid379/ZoneComics/releases/latest).
2. Descends jusqu'à la section **Assets**.
3. Télécharge le fichier se terminant par `.apk`.
4. Ouvre le fichier téléchargé sur ton téléphone.
5. Si Android le demande, autorise temporairement l'installation depuis cette source.
6. Appuie sur **Installer**.

> Zone Comics nécessite Android 6.0 ou une version plus récente.

## Mettre l'application à jour

Télécharge la nouvelle APK depuis la même page, puis installe-la directement par-dessus la version déjà présente.

**Ne désinstalle pas l'ancienne version** avant la mise à jour : la bibliothèque est stockée localement sur le téléphone. La mise à jour doit également être signée avec la même clé Android pour conserver les données.

## Fonctionnalités

- Bibliothèque personnelle Marvel et DC.
- Ajout, modification et suppression de comics.
- Recherche Metron ou création manuelle lorsqu'un numéro est absent.
- Statuts de lecture et notation sur 5 pour les comics lus.
- Recherche et filtres par éditeur ou statut.
- Calendrier mensuel des prochaines sorties.
- Fonctionnement hors ligne pour toute la bibliothèque.
- Compte Metron facultatif pour enrichir la recherche et actualiser les sorties.
- Stockage local SQLite et identifiants Metron protégés.

## Données et confidentialité

La bibliothèque reste enregistrée dans l'espace privé de l'application sur le téléphone. Zone Comics n'envoie pas la collection vers un serveur. La désinstallation ou l'effacement des données Android supprime la bibliothèque locale.

## Développement

Le projet utilise Flutter. Après avoir installé Flutter et Android Studio :

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

Pour générer l'APK release :

```powershell
flutter build apk --release
```

Le fichier généré se trouve dans :

```text
build\app\outputs\flutter-apk\app-release.apk
```

## BaxterVerse

Zone Comics est lié à l'univers [BaxterVerse](https://comicsverse.tail46e980.ts.net/).
