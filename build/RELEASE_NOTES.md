Syntax OS 1.7 — vrai menu Démarrer en grille d'icônes, Réglages Syntax refaits entièrement, fond d'écran facile à changer.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Le menu Démarrer est entièrement refait.** Fini la liste texte de la 1.6 : c'est maintenant une vraie grille d'icônes — recherche, récents, épinglés, toutes les applications, compte et Marche/Arrêt — dans le même langage visuel que Syntax Connect (même typographie, mêmes couleurs, mêmes cartes). Techniquement, c'est une page web locale affichée dans sa propre fenêtre, jamais exposée au réseau.
- **Réglages Syntax refaits pareil** : clavier, fond d'écran (avec aperçus cliquables — plus besoin de chercher un sélecteur de fichier), comptes, mise à jour, dock, diagnostic Bluetooth, à propos.
- **Limite honnête sur la position des fenêtres** : rien ne garantit encore qu'elles s'ancrent proprement au bord de l'écran sur un vrai Pi — on n'a pas pu le vérifier sans matériel réel. Dis-nous où elles s'ouvrent.
- **Pas encore refaits** : « Réglages du dock » et « Mise à jour Syntax » utilisent encore l'ancien style de fenêtre (zenity) — prochaine étape.

**Bluetooth** : toujours pas de piste confirmée. Diagnostic Bluetooth (dans Réglages Syntax) copie tout dans le presse-papiers — colle-le ici.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
