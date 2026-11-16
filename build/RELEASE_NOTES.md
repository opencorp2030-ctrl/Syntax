Image Syntax OS pour Raspberry Pi 5 (compatible aussi Pi 4, Pi 400 et Zero 2 W), 64 bits.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Nouveau dans cette version** : la priorité est la rapidité. Les applications Electron (VS Code, SatisCode, SatisDocs) utilisent désormais le GPU sous Wayland au lieu d'un rendu logiciel, un swap compressé en RAM (zram) évite les ralentissements quand la mémoire sature, quelques services d'arrière-plan superflus sont désactivés, et les ombres des fenêtres sont plus discrètes pour une interface plus nette.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
