Syntax OS 2.0 — icônes SatisCorp conformes à la marque, set d'icônes Syntax simplifié, 3 nouveaux fonds d'écran, Réglages du dock refait avec glisser-déposer.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Icônes SatisCode, SatisDocs et SatisReader refaites** à partir de la vraie identité SatisCorp (github.com/SatisCorprperation/Branding) : le S de la marque, sur la couleur officielle de chaque application (orange, bleu, vert). livepreview.usecartouche.com n'a pas pu être consulté depuis cet environnement de build (hors de son réseau autorisé) ; tout vient du dépôt GitHub.
- **Icônes Syntax simplifiées** : Réglages, Marche/Arrêt, Mise à jour, Changer d'utilisateur, Réglages du dock, Syntax Connect — couleur pleine plutôt que dégradé, plus sobres.
- **3 nouveaux fonds d'écran** (Aurora, Dotgrid, Peaks), en plus des deux déjà présents — tous choisissables depuis Réglages Syntax → Fond d'écran.
- **Réglages du dock entièrement refait** : même fenêtre que Réglages Syntax et le menu Démarrer (recherche de style, pas de zenity), et surtout un vrai glisser-déposer pour réorganiser les icônes épinglées — on fait glisser une icône au-dessus d'une autre pour échanger leur position, ça s'applique tout de suite.
- **Limite technique honnête, qui ne changera pas sans remplacer le dock** : le dock réel (waybar, une barre d'outils) ne peut toujours pas recevoir une icône glissée directement dessus depuis une autre fenêtre — ce n'est pas un choix, waybar n'a simplement pas cette capacité, et rien côté Syntax OS ne peut changer ça sans le remplacer entièrement par un autre programme. Réglages du dock (lui, glissable) reste le moyen de réorganiser.

**Toujours pas refait** : « Mise à jour Syntax » utilise encore l'ancien style de fenêtre (zenity).

**Bluetooth** : toujours pas de piste confirmée. Diagnostic Bluetooth (dans Réglages Syntax) copie tout dans le presse-papiers — colle-le ici.

**Rappel important (1.9)** : si tu étais sur une version antérieure à 1.9, un `syntax self-update` seul ne suffisait pas à tout récupérer. Un reflash est nécessaire une fois pour repartir sur une base saine ; les mises à jour suivantes fonctionnent normalement depuis.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
