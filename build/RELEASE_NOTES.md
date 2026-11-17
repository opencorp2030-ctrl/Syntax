Syntax OS 1.4 — écran de connexion avec plusieurs comptes, actions du dock sans mot de passe répété, deuxième piste pour le Bluetooth.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Écran de connexion Syntax, avec plusieurs comptes.** Dès qu'un vrai moniteur est branché, tu tombes sur l'écran de connexion (comptes avec photo, un clic, mot de passe) au lieu d'ouvrir directement une session — comme sur Windows. Choisis n'importe lequel des comptes créés depuis l'onglet *Comptes* du portail. « Changer d'utilisateur » (menu du bureau, ou icône du dock) y ramène à tout moment sans redémarrer.
  Sans moniteur branché, la connexion reste automatique : indispensable pour qu'un Pi sans écran ni clavier reste joignable par Syntax Connect dès le premier démarrage.
- **Changer la taille du dock, ajouter/retirer une application, lancer la mise à jour : plus de mot de passe répété** pour un compte administrateur. Avant, pkexec le redemandait à chaque fois, même pour des actions sans risque ; c'est maintenant limité à ces deux actions précises, pas à pkexec en général.
- **Bluetooth, deuxième piste.** `UserspaceHID=true` force BlueZ à traiter le clavier/la souris en espace utilisateur (uHID) plutôt que par le pilote HID du noyau — une cause connue et documentée de « connecté mais ne répond pas » pour certains périphériques Bluetooth classiques (non-BLE), distincte de la piste BLE déjà tentée en 1.1.
- Petit correctif de fiabilité : l'onglet *Écran* du portail retente la connexion pendant quelques secondes au lieu d'échouer immédiatement si la session graphique vient juste de démarrer.

**Connu, encore possiblement non résolu** : si la souris/le clavier Bluetooth ne fonctionne toujours pas après cette mise à jour, il reste une piste non testée (désactiver `hidp`, forcer le module `uhid`) qui demande de vérifier en premier, directement sur le Pi : `journalctl -u bluetooth | grep -i hid` et `bluetoothctl info <adresse>`. Envoie ce résultat pour un correctif ciblé plutôt que deviné.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
