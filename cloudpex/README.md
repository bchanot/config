# cloudpex : montage à la demande du partage SMB CloudPex

`cloudpex` monte et démonte le partage SMB `CloudPex` du NAS (`//192.168.1.111/CloudPex`)
sur `/mnt/cloudpex`. Le mot de passe SMB est demandé à chaque montage. Rien n'est
écrit sur disque, rien ne passe en argument (le mot de passe est transmis à
`mount.cifs` par la variable d'environnement `PASSWD`, invisible dans `ps`).

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
cloudpex        # monte (demande le mot de passe de bchanot_smb)
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
| `/mnt/cloudpex` | point de montage, créé vide |
| `cifs-utils` | installé via `apt-get` seulement si `mount.cifs` manque |

Réexécutable. `../install.sh` l'appelle sur Linux, donc une installation complète
du dépôt suffit. Rien n'est monté à l'installation.

## Paramètres

En tête de `cloudpex` : `SHARE`, `MNT`, `SMB_USER`, `SMB_VERS`. Pour changer de NAS
ou de compte, édite ces valeurs puis relance `./cloudpex/install.sh`.

## Dépannage

- Échec du montage : `dmesg | tail` (mot de passe, réseau, ou version SMB
  refusée par le NAS : essayer `SMB_VERS="3.1.1"`).
- Démontage refusé (fichiers ouverts) : `lsof +D /mnt/cloudpex`, fermer, réessayer.
