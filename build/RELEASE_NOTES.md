Image Syntax OS pour Raspberry Pi 5 (compatible aussi Pi 4, Pi 400 et Zero 2 W), 64 bits.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Nouveau dans cette version** : identité visuelle propre à Syntax — nouveau fond d'écran topographique, palette ambre/sarcelle, police Space Grotesk pour les titres, curseur Bibata, dossiers recolorés — et trois applications SatisCorp préinstallées (SatisCode, SatisDocs, SatisReader) ainsi que le gestionnaire de paquets `poly`.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
