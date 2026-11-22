# Réponse à App Review (2.1 Information Needed, 1.0)

Apple ne refuse pas le code : il demande des infos parce que le compte développeur est nouveau. Aucun nouveau build n'est nécessaire.

## 1. La vidéo (à faire sur ton iPhone, avec le build 1.0 de TestFlight)

Avant d'enregistrer :
- Avec une **deuxième adresse email**, crée un compte et laisse un avis avec commentaire sur un resto proche (il faut le commentaire de quelqu'un d'autre pour montrer Signaler et Bloquer).
- Désinstalle puis réinstalle l'app pour repartir de zéro (la demande de localisation s'affichera).
- Centre de contrôle → ajoute « Enregistrement de l'écran ».

Dans la vidéo, dans l'ordre :
1. Lancer l'app depuis l'écran d'accueil, autoriser la localisation.
2. Déplacer la carte, toucher un nid pour zoomer, ouvrir la fiche d'un resto (adresse, moyenne, avis, Itinéraire).
3. Mon compte → email → code reçu → pseudo (connexion).
4. Sur le resto avec l'avis de ton autre compte : noter et commenter, publier.
5. « ⋯ » sur le commentaire de l'autre compte → Signaler → choisir un motif.
6. « ⋯ » → Bloquer cet utilisateur → son avis disparaît.
7. Mon compte → Utilisateurs bloqués → Débloquer.
8. Mon compte → Supprimer mon compte → confirmer.

Vise 2 à 3 minutes. Joins la vidéo à ta réponse dans App Store Connect (Resolution Center).

## 2. Le texte à coller

À coller dans la réponse **et** dans App Review Information → Notes.

> **1. Screen recording:** attached (iPhone, latest iOS, build 1.0 (1)). It shows launch, the map, a restaurant page, sign-in, posting a rating, reporting and blocking another user's comment, unblocking, and account deletion.
>
> **2. Purpose and audience:** La Carto'Poulet is a free map of chicken-specialist restaurants (fried chicken, rotisseries, Portuguese frango, wings, tenders) in mainland France. It is for people in France looking for a good chicken place nearby. Users see the restaurants around them, their average rating and comments, and get directions in Apple Maps. Signed-in users rate restaurants from 1 to 5 drumsticks and leave a comment, which helps others choose. There are no ads, no payments and no tracking.
>
> **3. How to use it:** No demo account is needed. The map, restaurant pages and reviews work without an account. To rate, tap the person icon (top right), enter any email address you can read, and type the 6-digit code sent to it; then choose a nickname. Moderation (1.2): tap "⋯" on a comment → Signaler (report) or Bloquer cet utilisateur (block). A comment reported 3 times is hidden automatically and reviewed by the developer. Blocked users are managed in Mon compte. Account deletion (5.1.1(v)): Mon compte → Supprimer mon compte. Location is only used on the device to center the map; it is never sent to our servers. The interface is in French.
>
> **4. External services:**
> - Supabase (database and email sign-in), hosted in the EU (Ireland)
> - Resend (sends the sign-in code emails)
> - OpenStreetMap (restaurant data, imported monthly, ODbL licence)
> - Apple MapKit (map display and directions)
>
> **5. Regional differences:** The app works the same in every region. Its content covers mainland France only, so outside France the map shows no restaurants nearby until the user moves it to France. The interface is in French.
>
> **6. Regulated industry / third-party material:** Not a regulated industry. Restaurant data comes from OpenStreetMap under the Open Database Licence (ODbL), which allows this use with attribution; the attribution "© OpenStreetMap contributors" is shown on the map and in the account screen. No other third-party content is used.
