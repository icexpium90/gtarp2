# pt-multijob : plusieurs métiers par personnage

Un personnage peut cumuler jusqu'à **3 métiers** (réglable : `Config.MaxJobs` dans `config.lua`) et choisir lequel est
actif. Le gang est à part (QBCore sépare métier et gang) : « agent immobilier + mécano + mafia » = 2 métiers + 1 gang.

## Pour les joueurs

- `/metiers` ou menu radial (F1) > Citizen > **Mes métiers** : liste des métiers avec grade et salaire.
- **Prendre ce métier** : il devient le métier actif (salaire, service, accès aux menus et véhicules du métier).
  Délai de 60 s entre deux changements ; impossible à terre ou menotté.
- **Démissionner** : retire le métier de la liste.

## Comment les métiers s'ajoutent

Tout ce qui donne un métier l'ajoute à la liste : embauche par un patron (qb-management), mairie, `/setjob`.
Si la liste est pleine, le nouveau métier remplace le métier actif précédent (comme sans multi-métiers).
Les métiers incompatibles (`Config.Incompatibles`, par défaut police / ambulance) ne se cumulent pas.

## Pour les patrons (qb-management)

- La liste des employés montre aussi ceux pour qui c'est un 2e métier (mention « 2e métier »).
- Promouvoir un employé dont ce n'est pas le métier actif change seulement son grade enregistré.
- Licencier retire uniquement ce métier : l'employé garde ses autres métiers.

## Admins

- `/addjob [id] [métier] [grade]` : ajoute un métier secondaire sans le rendre actif.
- `/removejob [id] [métier]` : retire un métier.

## Notes

- Seul le métier actif est payé (salaire QBCore) et compte pour les scripts (police en service, etc.).
- Table créée automatiquement : `pt_multijob`. Les métiers actuels des joueurs y sont ajoutés à leur connexion.
- Exports serveur pour d'autres scripts : `AddJob(cid, job, grade)`, `RemoveJob(cid, job)`, `SetGrade(cid, job, grade)`,
  `GetJobs(cid)`, `HasJob(cid, job)`, `GetEmployees(job)`.
