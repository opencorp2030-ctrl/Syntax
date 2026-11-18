Syntax OS 2.2 — correctifs d'après capture d'écran réelle : icônes cassées et barre de titre classique sur le menu Démarrer.

**Installation**

1. Télécharge `syntax-os-…-arm64.img.xz`.
2. Flashe-la sur une carte microSD (16 Go minimum) avec Raspberry Pi Imager → « Utiliser une image personnalisée », ou balenaEtcher.
3. (Facultatif) Ouvre la partition `bootfs` de la carte et renseigne ton Wi-Fi dans `syntax.conf`.
4. Démarre le Pi, attends 2 à 3 minutes, puis ouvre `http://syntax.local` depuis un appareil du même réseau — ou laisse-le s'ouvrir tout seul sur l'écran du Pi.
5. Identifiant `syntax`, mot de passe `syntax` — le portail t'oblige à le remplacer à la première connexion.

**Corrigé grâce à une vraie capture d'écran** :
- **Icônes cassées** dans le menu Démarrer, Réglages Syntax et Réglages du dock : certaines ne se chargeaient pas et affichaient l'icône « image cassée » du navigateur au lieu de la lettre de secours prévue. Ce repli automatique manquait quand le chargement échouait réellement — corrigé pour toutes les icônes concernées, dans les trois fenêtres. La cause exacte de l'échec de chargement sur du vrai matériel n'est pas encore identifiée ; dis-nous si des icônes manquent encore après cette mise à jour.
- **Barre de titre classique** (titre, réduire/agrandir/fermer) sur le menu Démarrer, Réglages Syntax, Réglages du dock et Mise à jour : ces fenêtres sont de simples pages web, elles n'avaient pas vocation à ressembler à une fenêtre normale. Une règle a été ajoutée au compositeur (labwc) pour la retirer sur ces quatre fenêtres précisément. Le XML produit est vérifié valide pendant la construction de l'image — si jamais une erreur s'y était glissée, la construction aurait simplement échoué plutôt que de livrer un bureau cassé. Reste à confirmer sur du vrai matériel que ça fonctionne comme prévu.

**Toujours pas fait** : positionner ces fenêtres contre le bord de l'écran plutôt qu'au centre (ancrage façon menu Démarrer de Windows) — pas tenté cette fois, moins sûr de la syntaxe exacte nécessaire pour ça.

**Bluetooth** : toujours pas de piste confirmée. Diagnostic Bluetooth (dans Réglages Syntax) copie tout dans le presse-papiers — colle-le ici.

Tout le reste (accès par Internet avec ton domaine Cloudflare, etc.) est expliqué dans le README.
