<p align="center"><img src="design/logo.svg" alt="La Carto'Poulet" width="320"></p>

App iPhone qui recense les restos spécialisés dans le poulet en France métropolitaine : une carte, des notes en pilons (1 à 5) et des commentaires.

- Carte des restos autour de soi, consultable sans compte
- Fiche resto : adresse, type, moyenne, nombre d'avis, commentaires, itinéraire dans Plans
- Connexion par code reçu par email, sans mot de passe
- Une note par resto, modifiable et supprimable
- Signaler un commentaire (masqué automatiquement à 3 signalements), bloquer un utilisateur
- Suppression du compte et de toutes ses données depuis l'app

Le cahier des charges complet est dans [SPEC.md](SPEC.md), le suivi des tâches dans [tasks/todo.md](tasks/todo.md), la modération des commentaires dans [supabase/MODERATION.md](supabase/MODERATION.md).

## Stack

- **App :** SwiftUI + MapKit, iOS 17+, iPhone uniquement. Le projet Xcode est généré par [XcodeGen](https://github.com/yonaskolb/XcodeGen) depuis `project.yml`. La seule dépendance est [supabase-swift](https://github.com/supabase/supabase-swift).
- **Backend :** [Supabase](https://supabase.com) (Postgres + PostGIS, Auth, row-level security). Les migrations sont dans `supabase/migrations/`.
- **Données :** les restos viennent d'OpenStreetMap et sont importés par `scripts/import_osm.py`.

## Lancer en local

Prérequis : Xcode, `xcodegen`, Docker et la [CLI Supabase](https://supabase.com/docs/guides/cli).

```sh
supabase start                               # Postgres + Auth locaux ; affiche les clés
cp Config.xcconfig.example Config.xcconfig   # puis colle l'URL et la clé anon (jamais la service_role)
xcodegen generate
open LaCartoPoulet.xcodeproj
```

Pour importer les restos (le script a besoin de la clé `service_role`, à ne passer qu'en variable d'environnement) :

```sh
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_KEY=... python3 scripts/import_osm.py
```

Les réponses Overpass sont gardées en cache dans `data/osm/`. `--refresh` les retélécharge. Relancer le script ne crée pas de doublons.

Les codes de connexion envoyés en local s'affichent dans Mailpit : http://127.0.0.1:54324.

## Mettre à jour les restos (chaque mois)

À lancer sur la base de production. La clé secrète se trouve dans le tableau de bord Supabase (Project Settings → API Keys). Ne la colle que dans le terminal, jamais dans un fichier :

```sh
SUPABASE_URL=https://tnkkgcyeokiuxjtrnyfr.supabase.co SUPABASE_SERVICE_KEY=... python3 scripts/import_osm.py --refresh
```

- `--refresh` est indispensable. Sans lui, le script réimporte le cache du mois précédent.
- Si une région ne se télécharge pas, le script s'arrête avant d'écrire quoi que ce soit dans la base. Relance-le plus tard.
- Le script met la base à jour, puis affiche le nombre de restos par règle et 20 exemples tirés au hasard. Le total doit rester proche de celui du mois précédent (environ 1 700).
- **Un resto supprimé d'OpenStreetMap disparaît de l'app, et ses avis avec lui.** Cette suppression a déjà eu lieu quand les nombres s'affichent. Une chute brutale signale un problème côté OSM : écris-moi avant de relancer le script.

## Tests

```sh
xcodebuild -scheme LaCartoPoulet -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test   # app
supabase test db                                                                              # base (pgTAP)
python3 scripts/import_osm.py --self-test                                                     # règle « poulet » de l'import
```

## Licence

Code : tous droits réservés, voir [LICENSE.md](LICENSE.md).
Données des restos : © les contributeurs d'[OpenStreetMap](https://www.openstreetmap.org/copyright), sous licence ODbL.
