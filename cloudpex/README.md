# cloudpex : montage à la demande d'un partage SMB (NAS)

`cloudpex` monte et démonte un partage SMB du NAS sur un point de montage local.
Le mot de passe SMB est demandé à chaque montage. Rien n'est écrit sur disque,
rien ne passe en argument (le mot de passe est transmis à `mount.cifs` par la
variable d'environnement `PASSWD`, invisible dans `ps`).

Les valeurs propres au site (hôte du NAS, nom du partage, utilisateur SMB, point
de montage, version SMB) ne sont pas dans le script. Elles sont demandées à
l'installation et écrites dans `/etc/cloudpex.conf`, lisible par root seulement.

## Pourquoi à la demande, et pas dans fstab

Sur l'ancien serveur le partage était monté en permanence, en écriture, avec
`uid=1000` forcé. Tout processus de l'utilisateur pouvait donc tout effacer, agents
Claude compris. C'est ce qui a rendu l'incident du 21/09 total (voir
`RECOVERY/01-prochain-systeme/04-NAS-cloudpex-sauvegardes.md` sur le partage).

Ce script applique la règle 2 de ce document :

- montage à la demande, par un humain, jamais automatique au boot ;
- aucun identifiant stocké (`/root/.smbcredentials` n'existe plus) ;
- `noexec,nosuid,nodev` : rien ne s'exécute depuis le partage ;
- `dir_mode=0750`, propriétaire = l'utilisateur qui a lancé `sudo` : les autres
  comptes (dont les comptes agents) ne voient pas le contenu.

Démonte quand tu as fini (`cloudpex -u`). Un partage monté reste effaçable par
tes propres processus.

## Usage

```sh
cloudpex        # monte (demande le mot de passe SMB)
cloudpex -s     # état
cloudpex -u     # démonte (alias : -d, dc, disconnect, disable)
cloudpex -h     # aide
```

Le script se relance lui-même via `sudo` : pas besoin de le préfixer.

## Installation

```sh
./cloudpex/install.sh
```

Ce que ça fait, à l'identique de cette machine :

| Cible | Détail |
| --- | --- |
| `/usr/local/bin/cloudpex` | copie du script, `root:root`, `0755` |
| `/etc/cloudpex.conf` | les cinq valeurs du site, demandées au clavier, `root:root`, `0600` |
| point de montage | créé vide (`/mnt/cloudpex` par défaut) |
| `cifs-utils` | installé via `apt-get` seulement si `mount.cifs` manque |

Questions posées (défaut entre crochets) :

```
Hôte du NAS (IP ou nom) :
Nom du partage SMB :
Utilisateur SMB :
Point de montage [/mnt/cloudpex] :
Version SMB [3.0] :
```

Réexécutable : si `/etc/cloudpex.conf` existe, il est affiché et gardé sauf
réponse `n`. Sans terminal (`curl | bash`), le script est réinstallé mais la
config n'est ni créée ni modifiée. `../install.sh` appelle cet installeur sur
Linux. Rien n'est monté à l'installation.

## Changer de NAS, de partage ou de compte

Relance `./cloudpex/install.sh` et réponds `n` à « La garder ? », ou édite
`/etc/cloudpex.conf` en root (format `CLÉ=valeur`, une par ligne : `HOST`,
`SHARE`, `SMB_USER`, `MNT`, `SMB_VERS`). Le script lit ce fichier ligne à ligne,
il ne l'exécute jamais.

## Dépannage

- `config absente` : lance `./cloudpex/install.sh` depuis un terminal.
- Échec du montage : `dmesg | tail` (mot de passe, réseau, ou version SMB
  refusée par le NAS : essayer `SMB_VERS=3.1.1` dans la config).
- Démontage refusé (fichiers ouverts) : `lsof +D <point de montage>`, fermer,
  réessayer.
