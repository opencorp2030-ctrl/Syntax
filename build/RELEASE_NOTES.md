Syntax OS 1.9 — correctif important : la mise à jour automatique n'embarquait pas tout.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Correctif important** : le paquet de mise à jour (`syntax self-update`, ou l'application « Mise à jour Syntax ») n'embarquait qu'une liste figée de fichiers, jamais mise à jour en même temps que le reste. Résultat concret : le service de connexion automatique (1.4), les règles polkit pour le dock et la mise à jour sans mot de passe (1.4), les deux pistes Bluetooth (1.1 et 1.4), les icônes de bureau (1.6) et les nouvelles icônes d'applications (1.8) n'atteignaient **jamais** une installation mise à jour — seul un nouveau flash les apportait. C'est corrigé : la liste est maintenant large et inclut aussi les fichiers système modifiés sur place (clavier, Bluetooth, labwc, écran de connexion, bureau), pas seulement les nouveaux fichiers.

**Si tu es sur une version antérieure à 1.9** : un `syntax self-update` ne suffira pas à tout récupérer, puisque c'est justement lui qui était incomplet. **Reflashe une fois avec cette image** — après ça, les mises à jour suivantes embarqueront vraiment tout.

**Dans les versions précédentes (1.4 à 1.8), pour rappel** :
- Écran de connexion avec plusieurs comptes, dock personnalisable, menu Démarrer en grille d'icônes et Réglages Syntax refaits, icônes dessinées pour nos applications, thème clair forcé pour ces deux fenêtres, redémarrage automatique après mise à jour.

**Toujours pas refaits** : « Réglages du dock » et « Mise à jour Syntax » utilisent encore l'ancien style de fenêtre (zenity).

**Bluetooth** : toujours pas de piste confirmée. Diagnostic Bluetooth (dans Réglages Syntax) copie tout dans le presse-papiers — colle-le ici.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
