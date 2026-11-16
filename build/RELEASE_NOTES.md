Syntax OS 1.3 — dock personnalisable, écran virtuel forcé retiré (il cassait un vrai moniteur).

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Écran virtuel forcé retiré.** Ce réglage (1.1/1.2) pouvait couper l'image sur un vrai moniteur branché. Sans moniteur, une sortie de secours intégrée à labwc prend le relais automatiquement — jamais un deuxième écran en plus d'un vrai.
- **Dock personnalisable** : taille des icônes, ajout/retrait d'applications, réorganisation — clic droit sur une icône du dock, ou lance « Réglages du dock » depuis le lanceur. Limite technique honnête : pas de nom affiché en permanence sous chaque icône (waybar ne le permet pas) — le survol affiche le nom à la place.

**Connu, non résolu** : certaines souris et claviers Bluetooth se connectent mais ne répondent pas. En attente d'un diagnostic (`bluetoothctl info`, `systemctl status bluetooth`) avant un nouveau correctif.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
