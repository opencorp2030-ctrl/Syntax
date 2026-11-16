# Syntax OS

Un système d'exploitation stable et complet pour Raspberry Pi, basé sur Raspberry Pi OS 64 bits
(Debian 13 « trixie »), orienté développement et IA, avec **Syntax Connect** : l'écran et le
terminal du Pi dans ton navigateur, sur ton réseau local ou depuis Internet via ton propre domaine
Cloudflare.

- **Compatible** : Raspberry Pi 5 (cible principale), Pi 4, Pi 400, Zero 2 W — noyau, firmware et
  pilotes officiels Raspberry Pi.
- **Interface Syntax** : dock vertical à droite de l'écran, lanceur d'applications (touche Super
  ou logo du dock), thème sombre et identité propre (palette ambre/sarcelle, police Space Grotesk
  pour les titres, curseur Bibata, dossiers recolorés), terminal assorti ; en français, clavier
  AZERTY, fuseau Europe/Paris.
- **Outils préinstallés** : Git, Python (venv, pip, pipx), Node.js + npm, Docker, VS Code,
  GitHub CLI, Claude Code (`claude`), cloudflared, [poly](https://github.com/opencorp2030-ctrl/poly)
  (`poly install <paquet>`, un seul gestionnaire pour pip/npm/brew/binaires).
- **Applications SatisCorp préinstallées** : [SatisCode](https://github.com/gtref/satiscode)
  (éditeur C/C++/Python/JSON/XML), [SatisDocs](https://github.com/gtref/satisdocs) (visionneuse de
  documentation Markdown) et [SatisReader](https://github.com/SatisCorprperation/satisreader)
  (lecteur de flux RSS/Atom, servi en local sur `http://localhost:8092`).
  Deux autres projets SatisCorp demandés ne sont pas des applications de bureau : SatisPalette est
  un composant JavaScript à intégrer à un site web (pas un programme à installer), et SatisTimer
  est une application Android — aucun des deux ne peut tourner comme application du bureau Syntax.
- **Sans écran ni clavier** : flashe, branche, ouvre `http://syntax.local`.
- **Pensé pour durer** : swap compressé en RAM, `log2ram` et journal système en RAM pour épargner
  la carte SD de l'usure dans la durée.
- **Mise à jour automatique** : Syntax OS vérifie chaque jour la dernière version publiée sur
  GitHub et s'applique tout seul (fichiers du système Syntax + paquets), sans jamais réinstaller
  l'image ni toucher à tes données.
- **Application de mise à jour** : icône « Mise à jour Syntax » dans le dock, pour lancer la
  vérification et l'installation sans passer par le terminal.
- **Plusieurs comptes** : crée d'autres comptes (administrateur ou non) depuis l'onglet Comptes
  du portail, chacun avec son mot de passe, comme les profils utilisateurs sur un PC.
- **Dock personnalisable** : change la taille des icônes, ajoute ou retire des applications,
  change leur ordre — clic droit sur une icône du dock, ou lance « Réglages du dock ».

## Le dock

Clic droit sur n'importe quelle icône du dock (ou lance l'application « Réglages du dock »,
disponible dans le lanceur) pour :

- changer la **taille des icônes** (quatre tailles, appliquée tout de suite) ;
- **ajouter** une application installée (tout ce qui a une icône dans le menu peut être épinglé) ;
- **retirer** une icône du dock ;
- **réorganiser** l'ordre des icônes.

Techniquement, le dock de Syntax OS (waybar) ne peut pas afficher un nom en permanence sous
chaque icône comme le Dock de macOS — survole une icône pour voir son nom à la place. Le reste
(taille, contenu, ordre) fonctionne comme décrit.

## Installer

1. Télécharge `syntax-os-<version>-arm64.img.xz` depuis les
   [releases](../../releases) (ou l'artefact du dernier build dans l'onglet Actions).
2. Flashe l'image sur une microSD de 16 Go ou plus avec **Raspberry Pi Imager**
   (« Choisir l'OS » → « Utiliser une image personnalisée ») ou balenaEtcher.
3. Wi-Fi : rouvre la carte sur ton ordinateur, partition `bootfs`, fichier **`syntax.conf`**, et
   renseigne `WIFI_SSID` / `WIFI_PASSWORD`. En Ethernet, rien à faire.
4. Mets la carte dans le Pi et allume-le. Le premier démarrage prend 2 à 3 minutes
   (agrandissement de la partition, création du compte, redémarrage).
5. Depuis un appareil du même réseau, ouvre **`http://syntax.local`**
   (ou `http://<adresse-IP-du-Pi>`).
6. Connecte-toi avec `syntax` / `syntax`. Le portail t'oblige à choisir un nouveau mot de passe
   avant d'ouvrir la session ; c'est aussi le mot de passe du compte Linux.

> Si tu définis un utilisateur dans les réglages de Raspberry Pi Imager, c'est ce compte qui est
> créé à la place du compte d'usine `syntax`.

## Syntax Connect

| Onglet | Rôle |
| --- | --- |
| Aperçu | Charge, température, mémoire, stockage, adresses, redémarrage / extinction, mot de passe |
| Écran | Le bureau du Pi dans le navigateur (clavier, souris, presse-papiers, plein écran) |
| Terminal | Un shell complet sous ton compte |
| Comptes | Créer d'autres comptes, changer leur mot de passe, en supprimer |
| Accès Internet | Mise en place du tunnel Cloudflare |

### Accès depuis Internet avec ton domaine Cloudflare (gratuit)

Le Pi ouvre une connexion **sortante** vers Cloudflare : aucun port à ouvrir sur ta box, HTTPS
automatique, et rien à payer en plus de ton domaine (les tunnels Cloudflare sont gratuits).

**Méthode automatique** — onglet *Accès Internet* du portail :

1. « Obtenir le lien d'autorisation », ouvre-le, connecte-toi à Cloudflare, choisis ton domaine.
2. Saisis l'adresse voulue, par exemple `syntax.mondomaine.fr`, puis « Activer ».

Syntax crée le tunnel et l'enregistrement DNS. En ligne de commande :
`syntax connect login syntax.mondomaine.fr`.

**Méthode par jeton** — utile pour un Pi sans accès local :

1. Tableau de bord Cloudflare → Zero Trust → Réseaux → Tunnels → créer un tunnel *Cloudflared*.
2. Ajoute un nom d'hôte public (ex. `syntax.mondomaine.fr`) vers le service `http://localhost:80`.
3. Colle le jeton dans le portail, ou dans `syntax.conf` (`CF_TUNNEL_TOKEN=`) avant le premier
   démarrage.

### Sécurité

- Le tunnel **refuse de démarrer** tant qu'un compte a encore le mot de passe d'usine.
- Connexion par le compte Linux (PAM), limitation des tentatives, cookies `HttpOnly` /
  `SameSite=Strict`, vérification de l'origine des requêtes.
- Le partage d'écran passe par une socket Unix privée : aucun port VNC n'est ouvert.
- SSH est désactivé par défaut (`ENABLE_SSH=1` dans `syntax.conf` pour l'activer).
- Sur le réseau local, le portail est en HTTP : à réserver à un réseau de confiance. Par Internet,
  tout passe en HTTPS via Cloudflare.
- Recommandé : ajoute une règle **Cloudflare Access** (gratuit jusqu'à 50 utilisateurs) devant
  l'adresse du Pi pour n'autoriser que ton adresse e-mail.

## Commande `syntax`

```bash
syntax                      # état du système et adresses du portail
syntax connect status       # état de l'accès Internet
syntax connect login <hôte> # tunnel + DNS automatiques sur ton domaine
syntax connect token <jeton>
syntax connect off | on | reset
syntax ai                   # installe Ollama (modèles d'IA locaux)
syntax update               # met à jour le système
syntax self-update           # applique la dernière version de Syntax OS (automatique chaque jour)
```

## Utilisation sans moniteur

Sans moniteur branché, le bureau démarre sur une sortie de secours fournie par labwc et
reste visible dans l'onglet *Écran* — automatiquement, sans aucun réglage à faire. Cette
sortie de secours ne s'active que lorsqu'il n'y a vraiment aucun écran ; dès qu'un vrai
moniteur est branché, c'est lui qui est utilisé.

Les versions 1.1 et 1.2 proposaient un réglage « écran virtuel forcé » qui imposait un
mode vidéo fixe sur le port HDMI 0. Il a été retiré en 1.3 : ce mode restait actif même
une fois un vrai moniteur branché sur ce port, et si ce mode ne lui convenait pas l'image
disparaissait complètement, écran du Pi compris. L'onglet *Écran* de Syntax Connect
reflète toujours exactement ce qu'affiche le Pi, jamais un deuxième écran en plus.

## Construire l'image

L'image est construite par GitHub Actions (`.github/workflows/build.yml`) sur un runner ARM64 :
téléchargement de l'image officielle Raspberry Pi OS Desktop arm64, personnalisation dans un
chroot, réduction, compression. Un message de commit contenant `[release]` publie le résultat
dans une release.

En local, sur une machine Linux arm64 (ou x86_64 avec `qemu-user-static`) :

```bash
sudo apt-get install -y xz-utils parted e2fsprogs librsvg2-bin fonts-inter file curl
```

```bash
sudo build/build-image.sh
```

L'image est écrite dans `out/`.

## Organisation du dépôt

| Chemin | Contenu |
| --- | --- |
| `system/portal/` | Syntax Connect : serveur (Python / aiohttp) et interface web |
| `system/syntaxlib.py`, `system/cli.py` | Bibliothèque commune et commande `syntax` |
| `system/libexec/` | Partage d'écran, lancement du tunnel, choix du compte au premier démarrage |
| `rootfs/` | Fichiers copiés tels quels dans l'image (services systemd, PAM, lanceurs) |
| `boot/syntax.conf` | Modèle de configuration déposé sur la partition de démarrage |
| `desktop/` | Interface : dock, lanceur, thème des fenêtres, terminal, notifications |
| `branding/` | Fond d'écran et écran de démarrage |
| `ci/` | Capture du bureau de l'image dans un compositeur sans écran |
| `build/` | Scripts de construction de l'image, dont `fetch-apps.sh` (récupération des applications tierces) |

## Licences

Syntax OS assemble Raspberry Pi OS et Debian (licences respectives de chaque paquet).
L'interface embarque [noVNC](https://github.com/novnc/noVNC) (MPL-2.0) et
[xterm.js](https://github.com/xtermjs/xterm.js) (MIT). Raspberry Pi est une marque de
Raspberry Pi Ltd ; Syntax OS n'est ni affilié ni approuvé par Raspberry Pi Ltd.
