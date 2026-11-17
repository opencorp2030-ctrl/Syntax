Syntax OS 1.6 — menu Démarrer façon Windows (récents + Marche/Arrêt dans la même fenêtre), icônes de bureau activées.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Le logo ouvre désormais un vrai menu Démarrer** : les applications récemment lancées en haut, « Marche/Arrêt » et « Changer d'utilisateur » juste en dessous, puis toutes les applications — une seule fenêtre, plus besoin de passer par le dock pour éteindre ou redémarrer. Limite honnête : c'est une liste texte filtrable (le moteur, fuzzel), pas une grille d'icônes avec aperçus comme Windows ; et quelques entrées système de Raspberry Pi OS que nous n'avons pas encore identifiées avec certitude restent visibles dans la liste.
- **Icônes de bureau activées.** Raspberry Pi OS les désactive par défaut sous labwc (aucune icône, même en glissant un fichier) ; c'est maintenant corrigé — glisse un fichier sur le bureau, ou clic droit → Créer un nouveau, pour y poser une icône.

**Dock, limite technique honnête** : le dock (waybar) ne prend pas en charge le glisser-déposer d'icônes — c'est une barre d'outils, pas un vrai dock comme celui de macOS, et rien ne peut changer ça sans le remplacer entièrement. Réglages du dock (clic droit sur une icône, ou dans Réglages Syntax) fait exactement la même chose — ajouter, retirer, réorganiser — mais par menu plutôt que par glisser-déposer.

**Bluetooth** : toujours pas de piste confirmée pour le cas signalé, malgré trois tentatives. Utilise « Diagnostic Bluetooth » dans Réglages Syntax (copie tout dans le presse-papiers) et envoie le résultat — sans ce diagnostic, un nouveau correctif resterait une supposition.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
