Syntax OS 1.0 — première version stable, complète et prête à l'emploi.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** : interface Syntax (dock vertical, lanceur, thème ambre/sarcelle, police Space Grotesk, curseur Bibata), les applications Electron utilisent le GPU sous Wayland au lieu d'un rendu logiciel, un swap compressé en RAM (zram) évite les ralentissements, `log2ram` et le journal système en RAM protègent la carte SD de l'usure, et l'écran de verrouillage reprend l'identité Syntax. Applications préinstallées : VS Code, Docker, Node/Git, poly, Claude Code, SatisCode, SatisDocs, SatisReader.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
