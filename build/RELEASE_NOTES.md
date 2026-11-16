Syntax OS 1.2 — plusieurs comptes, application de mise à jour, garde-fou sur l'écran virtuel.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Onglet Comptes** dans Syntax Connect : crée d'autres comptes (administrateur ou non), change leur mot de passe, supprime-les — comme les profils utilisateurs sur un PC.
- **Application « Mise à jour Syntax »** dans le dock : vérifie et installe la dernière version sans passer par le terminal.
- **Écran virtuel forcé** : averti plus clairement qu'il ne faut l'activer que sans moniteur branché — un mauvais réglage pouvait couper l'image sur un vrai écran.

**Connu, non résolu dans cette version** : certaines souris et claviers Bluetooth se connectent mais ne fonctionnent pas. Le correctif tenté en 1.1 (profil Bluetooth Low Energy) n'a pas suffi pour tous les appareils ; un diagnostic plus précis est nécessaire avant un nouveau correctif.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
