Syntax OS 1.1 — mise à jour automatique, souris Bluetooth, nouveaux fonds d'écran.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi, c'est la phase de configuration initiale.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Mise à jour automatique** : Syntax OS vérifie chaque jour la dernière version publiée sur GitHub et s'applique tout seul, sans réinstaller l'image. `syntax self-update` pour forcer une vérification immédiate.
- **Première connexion** : le navigateur s'ouvre tout seul sur Syntax Connect au premier démarrage du bureau, directement sur l'écran du Pi.
- **Bluetooth** : correctif pour les souris et claviers Bluetooth Low Energy (BLE) qui s'appairaient sans que le curseur ne bouge.
- **Nouveaux fonds d'écran** disponibles dans le dossier d'images du bureau.

Les versions précédentes avaient déjà apporté l'interface Syntax, l'accélération GPU des applications Electron, le swap compressé en RAM, `log2ram`, et les applications SatisCode/SatisDocs/SatisReader/poly.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
