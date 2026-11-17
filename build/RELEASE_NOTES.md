Syntax OS 2.1 — « Mise à jour Syntax » refaite dans le même style que le reste.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **« Mise à jour Syntax » refaite**, dernière fenêtre encore en zenity : même page web locale que le menu Démarrer, Réglages Syntax et Réglages du dock — confirmation, journal en direct, puis état final (réussi ou échoué), redémarrage automatique inclus comme avant.
- Avec cette version, les quatre applications de bureau propres à Syntax OS (menu Démarrer, Réglages Syntax, Réglages du dock, Mise à jour) partagent maintenant exactement le même langage visuel.

**Bluetooth** : toujours pas de piste confirmée. Diagnostic Bluetooth (dans Réglages Syntax) copie tout dans le presse-papiers — colle-le ici, c'est la seule façon d'avancer dessus.

**Rappel important (1.9)** : si tu étais sur une version antérieure à 1.9, un `syntax self-update` seul ne suffisait pas à tout récupérer. Un reflash est nécessaire une fois pour repartir sur une base saine ; les mises à jour suivantes fonctionnent normalement depuis.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
