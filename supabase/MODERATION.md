# Modération

Un commentaire signalé par 3 personnes est masqué automatiquement : il n'apparaît plus dans l'app et ne compte plus dans la moyenne. C'est ensuite à toi de trancher : **le supprimer** ou **le réafficher**.

Les requêtes se lancent dans le tableau de bord Supabase : projet La Carto'Poulet → **SQL Editor** → New query. Elles s'exécutent avec les droits administrateur, sans passer par les règles de l'app. Lance-les une par une.

À faire une fois par semaine, ou quand tu reçois un email sur `contact@`.

## 1. Voir les avis masqués

```sql
select r.id, p.nickname, r.stars, r.comment, r.updated_at > r.created_at as modifie,
       re.name as resto, re.city,
       (select string_agg(reason, ', ') from public.reports where rating_id = r.id) as motifs
from public.ratings r
join public.profiles p using (user_id)
join public.restaurants re on re.id = r.restaurant_id
where r.hidden
order by r.updated_at desc;
```

La colonne `modifie` vaut `true` si l'auteur a changé son avis après le masquage : l'app l'y invite. Relis alors la nouvelle version.

## 2. Voir les avis signalés mais encore visibles (1 ou 2 signalements)

À consulter de temps en temps, pour supprimer ce qui est clairement inacceptable sans attendre le 3e signalement.

```sql
select r.id, p.nickname, r.comment, count(*) as signalements, string_agg(rp.reason, ', ') as motifs
from public.reports rp
join public.ratings r on r.id = rp.rating_id
join public.profiles p using (user_id)
where not r.hidden
group by r.id, p.nickname, r.comment
order by signalements desc;
```

## 3. Trancher

Remplace `123` par l'`id` de l'avis.

**Le supprimer** (insultant, spam, hors sujet) :

```sql
delete from public.ratings where id = 123;
```

Ses signalements partent avec lui. L'auteur peut publier un nouvel avis sur ce resto.

**Le réafficher** (signalements abusifs) :

```sql
begin;
delete from public.reports where rating_id = 123;
update public.ratings set hidden = false where id = 123;
commit;
```

Il faut effacer ses signalements : sinon, le prochain signalement le masquerait aussitôt, puisqu'il en aurait déjà 3 ou plus.

## 4. Bannir un utilisateur (cas graves ou répétés)

Repère d'abord ses avis :

```sql
select p.user_id, p.nickname, count(r.id) as avis, count(r.id) filter (where r.hidden) as masques
from public.profiles p left join public.ratings r using (user_id)
where p.nickname = 'Pseudo'
group by p.user_id, p.nickname;
```

Puis supprime son compte (remplace l'identifiant) :

```sql
delete from auth.users where id = '00000000-0000-0000-0000-000000000000';
```

Ça efface tout ce qui lui appartient, comme « Supprimer mon compte » dans l'app. Il pourra en recréer un avec la même adresse email. Si c'est un problème, ajoute aussi son adresse dans **Authentication → Users** pour la bloquer. Ce point n'est pas automatisé en v1.

## Pour une demande RGPD

Si quelqu'un écrit à `contact@` pour récupérer ses données, cherche son compte par email :

```sql
select u.id, u.email, u.created_at, p.nickname,
       (select json_agg(json_build_object('resto', re.name, 'note', r.stars, 'commentaire', r.comment, 'date', r.created_at))
        from public.ratings r join public.restaurants re on re.id = r.restaurant_id where r.user_id = u.id) as avis
from auth.users u left join public.profiles p on p.user_id = u.id
where u.email = 'adresse@exemple.fr';
```

Renvoie-lui le résultat. Pour une demande de suppression, applique l'étape 4, ou dis-lui d'utiliser « Supprimer mon compte » dans l'app.
