# CyberAutomatic — Spec de design

- Date : 2026-10-28
- Statut : en attente de revue
- Auteur : session Claude Code, avec marcarna90

## 1. Contexte et objectif

CyberAutomatic est un **nouveau projet, indépendant**, inspiré par les *fonctionnalités* de Sn1per
(orchestration de recon/pentest, système de modes, workspaces) mais sans reprendre une ligne de son
code, de sa structure de fichiers ni de son nom/branding — contraint par les clauses (2), (3) et (4)
de l'EULA de Sn1per Community Edition, qui interdisent le renommage, la création d'un produit dérivé
et la relicence de son code.

Objectif : une plateforme Bash légère, combinant automatisation **offensive** (reconnaissance,
scan de vulnérabilités) et **défensive** (audit d'hôte, conformité légère), gratuite, complète, et
destinée exclusivement à des usages autorisés (pentest sous mandat, labs, audit de ses propres
systèmes).

## 2. Principes

- Code 100% original, licence **MIT**.
- Binaire principal : `cyberauto`.
- **Autorisation intégrée à l'architecture**, pas seulement à la documentation : toute action
  offensive exige `--i-am-authorized` **et** que la cible soit couverte par
  `CYBERAUTO_ALLOWED_TARGETS` (plages privées par défaut dans `conf/cyberauto.conf`).
- Aucun outil tiers n'est bundlé dans le dépôt : CyberAutomatic orchestre des outils externes déjà
  installés (chacun sous sa propre licence open source) et parse leur sortie.
- Dépôt et dépendances séparés de ceux de Sn1per — aucune réutilisation de code, wordlists ou
  templates.

## 3. Architecture

Un CLI Bash unique (`cyberauto`) qui dispatch vers des scripts de mode indépendants, partageant une
lib commune.

```
cyberauto                     # point d'entrée : parse args, scope guard, dispatch
lib/
  scope.sh                    # vérifie autorisation + allow-list cibles
  workspace.sh                # create / list / delete / export / reimport
  findings.sh                 # lecture/écriture du format commun de résultats (JSON lines)
  report.sh                   # génère les rapports depuis templates/
  deps.sh                     # vérifie la dispo des outils externes par mode
modes/
  recon.sh  stealth.sh  discover.sh  port.sh  fullport.sh
  web.sh  osint.sh  vulnscan.sh  bruteforce.sh
  airstrike.sh  massport.sh  massweb.sh  massvuln.sh  full.sh
  hostaudit.sh  compliance-lite.sh        # modules défensifs
conf/
  cyberauto.conf               # scope, chemins outils, options de rapport
templates/                     # modèles de rapport (HTML / Markdown)
workspaces/<alias>/
  loot/  logs/  reports/  workspace.meta
scripts/
  install.sh  uninstall.sh  schedule.sh
tests/                          # tests bats
.github/workflows/ci.yml        # shellcheck + bats
```

### Contrat d'un module de mode

Chaque script `modes/<name>.sh` reçoit : cible, chemin du workspace, options. Il :
1. écrit sa sortie brute dans `workspaces/<ws>/loot/<mode>/` ;
2. ajoute des findings structurés (une ligne JSON par finding : id, cible, sévérité,
   description, recommandation) dans `workspaces/<ws>/findings.jsonl` ;
3. ne fait jamais planter l'orchestrateur sur une erreur locale — il logge en `WARN`/`ERROR` dans
   `workspaces/<ws>/logs/<mode>.log` et retourne un code de sortie non bloquant pour les modes
   `mass*`/`airstrike`.

Cette interface découple proprement les modes du moteur de rapport.

## 4. Inventaire des modes (correspondance fonctionnelle, pas de code repris)

| Sn1per (inspiration fonctionnelle) | CyberAutomatic | Changement |
|---|---|---|
| normal / stealth / discover / port / fullportscan / fullportonly | `recon`, `stealth`, `discover`, `port`, `fullport` | repris, implémentation propre |
| web / webscan / webporthttp / webporthttps | `web` | consolidé en un seul mode paramétrable |
| osint / osint_stage_2 | `osint` | consolidé, flag `--deep` au lieu de 2 scripts séparés |
| bruteforce | `bruteforce` | **off par défaut**, backend Ncrack (+NetExec en option), cf. §6 |
| airstrike / nuke / mass* | `airstrike`, `full`, `massport`, `massweb`, `massvuln` | repris, noms clarifiés |
| flyover, javascript-analysis, sc0pe* | — | hors v1, ajoutables plus tard si besoin réel |
| *(absent côté défensif)* | **`hostaudit`, `compliance-lite`** | nouveau, conçu indépendamment |

### Modules défensifs

- `hostaudit.sh` : lecture directe de la configuration système local ou distant autorisé
  (sshd_config, règles de pare-feu, sudoers, comptes, politique de mots de passe, auditd).
  Option : déléguer à **lynis** (outil externe) et parser sa sortie plutôt que réécrire les
  contrôles à la main.
- `compliance-lite.sh` : mappe un sous-ensemble des findings de `hostaudit` sur quelques contrôles
  CIS Controls v8, pour un score indicatif (pas un moteur de conformité complet type CyberShield).

## 5. Outils externes par mode

Aucun n'est bundlé ; `deps.sh` vérifie leur présence et **saute l'étape avec un `WARN`** si un
outil manque (jamais de blocage total du scan).

| Catégorie | Modes | Outils | Rôle |
|---|---|---|---|
| Ports/services | recon, port, fullport, discover, massport | nmap (requis), masscan (optionnel) | découverte hôtes/services |
| Recon web | web, massweb | whatweb, httpx, wafw00f | fingerprint / détection WAF |
| Scan web | web, massweb | nikto, ffuf ou gobuster | vulns web connues, fuzzing |
| Captures écran | web | gowitness | preuve visuelle |
| Vulnérabilités | vulnscan, massvuln | nmap --script vuln, nuclei | détection CVE/misconfig |
| TLS/SSL | web, vulnscan | testssl.sh ou sslscan | ciphers/protocoles faibles |
| OSINT | osint | amass ou subfinder, theHarvester, crt.sh (curl) | reconnaissance passive |
| Bruteforce (opt-in) | bruteforce | **Ncrack** (défaut), **NetExec** (option AD) | test d'identifiants, strictement autorisé |
| Audit hôte | hostaudit | aucun requis ; lynis en option | durcissement système |
| Rapport | tous | pandoc (optionnel, export PDF) | génération de rapports |

## 6. Garde-fous — module `bruteforce`

Le plus sensible fonctionnellement, donc le plus contraint :

- Désactivé par défaut ; nécessite `--allow-bruteforce` **en plus** de `--i-am-authorized`.
- Backend par défaut **Ncrack** : policies de timing (T0–T5) et détection de lockout intégrées,
  conçu pour l'audit à grande échelle sans verrouiller des comptes de prod.
- Backend optionnel **NetExec** pour les environnements Active Directory.
- Aucune wordlist de credentials n'est fournie dans le dépôt ; l'utilisateur fournit ses propres
  listes via un chemin explicite dans `conf/cyberauto.conf`.
- Liste de services ciblables limitée et explicite dans la config (pas de "tout service détecté").

## 7. Flux de données

```
cyberauto -t <cible> -m <mode> -w <workspace>
  → scope.sh : valide autorisation + appartenance de la cible à l'allow-list (échec net sinon)
  → modes/<mode>.sh : exécute, écrit loot/ + findings.jsonl, logge warnings
  → report.sh : lit findings.jsonl, rend templates/ → Markdown/HTML, PDF optionnel via pandoc
```

## 8. Gestion d'erreurs

- Violation de scope/autorisation → échec immédiat avant toute exécution, message explicite.
- Outil externe absent pour un mode → ce mode est sauté (`WARN` loggé), le reste continue.
- `mass*` / `airstrike` : l'échec sur une cible est loggé par cible, n'interrompt pas les autres.

## 9. Tests & CI

- `shellcheck` sur tous les scripts (gate CI).
- Tests `bats` : scope guard (autorisation/allow-list), CRUD workspace, parsing `findings.jsonl`,
  génération de rapport depuis un fixture de findings, parsing des arguments du CLI.
- Un test d'intégration avec un mode factice (aucun accès réseau) validant la chaîne complète
  jusqu'à la génération du rapport.
- Aucun test en CI n'effectue de scan réseau réel.
- `.github/workflows/ci.yml` exécute shellcheck + bats à chaque push/PR.

## 10. Installation & licence

- `scripts/install.sh` détecte la distro (apt/pacman/...) et installe nmap + les outils FOSS
  listés au §5 qui sont disponibles en paquet ; les autres sont signalés comme optionnels avec
  instruction d'installation manuelle.
- `scripts/uninstall.sh` symétrique.
- `scripts/schedule.sh` génère une entrée crontab pour relancer un workspace (`daily|weekly|monthly`)
  — ne modifie jamais le crontab système sans confirmation explicite.
- Licence **MIT** sur l'ensemble du dépôt.
- README : mention explicite "projet indépendant, aucune réutilisation de code Sn1per, usage
  autorisé uniquement".
- Langue du projet (README, commentaires) : anglais, par convention pour un projet open source
  destiné à une audience large (cohérent avec Sn1per et CyberShield).

## 11. Hébergement

Nouveau dépôt GitHub `marcarna90/CyberAutomatic`, créé et poussé une fois cette spec validée et le
plan d'implémentation établi.

## 12. Hors périmètre v1

- Dashboard web / API (CyberShield couvre déjà ce besoin pour le volet défensif complet).
- Modules `flyover`, `javascript-analysis`, `sc0pe*` (inspiration Sn1per jugée secondaire).
- Scan OpenVAS/GVM (trop lourd pour un orchestrateur Bash léger).
- Intégration cloud (AWS/Azure/GCP asset discovery).
