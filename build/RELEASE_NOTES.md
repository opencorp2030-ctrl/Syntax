Syntax OS 1.5 — redémarrage automatique après mise à jour, menu Marche/Arrêt, Réglages Syntax, nouveau logo.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Dans cette version** :
- **Redémarrage automatique après une mise à jour.** Qu'elle soit lancée depuis l'application « Mise à jour Syntax » ou par la vérification quotidienne, Syntax affiche maintenant une fenêtre (ou une notification) confirmant l'installation, puis redémarre tout seul 20 secondes après pour appliquer la mise à jour entièrement.
- **Marche/Arrêt, comme sur Windows.** Une icône dans le dock (et une entrée dans le lanceur) ouvre un vrai menu redémarrer / éteindre / se déconnecter — l'outil déjà fourni par Raspberry Pi OS, simplement rebaptisé et remis en avant au lieu d'être caché.
- **Réglages Syntax**, une fenêtre à nous (clavier, fond d'écran, comptes, mise à jour, dock, diagnostic Bluetooth, à propos) à la place du panneau générique « Raspberry Pi Configuration », toujours accessible sous son vrai nom pour les réglages avancés (overclock, caméra, GPIO…).
- **Diagnostic Bluetooth en un clic** (dans Réglages Syntax) : récupère l'état du service, les appareils appairés et les lignes liées au HID dans les journaux, copie tout dans le presse-papiers — pour nous envoyer un vrai diagnostic sans taper de commande.
- **Nouveau logo** : un monogramme « S » plus net, à la place de l'ancien symbole en chevrons. Se propage automatiquement partout (dock, écran de connexion, site) puisqu'il n'y a qu'un seul fichier source.

**Bluetooth** : toujours pas de piste confirmée pour le cas signalé malgré deux tentatives (BLE en 1.1, uHID en 1.4). Utilise le nouveau Diagnostic Bluetooth et envoie-nous le résultat — sans ce diagnostic, deviner un troisième correctif à l'aveugle risquerait de ne pas régler le vrai problème.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
