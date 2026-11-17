Syntax OS 1.8 — thème clair forcé pour le menu Démarrer et Réglages Syntax, vraies icônes dessinées pour nos applications.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Menu Démarrer et Réglages Syntax, toujours clairs.** Ils suivaient le thème sombre du système ; ils restent maintenant en clair quoi qu'il arrive — c'était trop sombre.
- **Vraies icônes pour nos applications**, dessinées façon macOS (carré arrondi, couleur propre à chaque appli, dégradé doux) : Syntax Connect, Mise à jour, Réglages Syntax, Réglages du dock, Marche/Arrêt, Changer d'utilisateur, SatisCode, SatisDocs, SatisReader. Avant, ces applications tombaient sur une simple lettre faute d'icône dédiée — les autres applications (VS Code, Docker, Firefox…) avaient déjà de vraies icônes via le thème Papirus, inchangées.
- Portée de ce changement : seuls le menu Démarrer et Réglages Syntax sont concernés par le thème clair forcé — le reste du système (bureau, terminal, fenêtres) garde son thème sombre habituel, pas demandé de le changer partout pour l'instant.

**Toujours pas refaits** : « Réglages du dock » et « Mise à jour Syntax » utilisent encore l'ancien style de fenêtre (zenity).

**Bluetooth** : toujours pas de piste confirmée. Diagnostic Bluetooth (dans Réglages Syntax) copie tout dans le presse-papiers — colle-le ici.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
