#!/usr/bin/env bash
# Ubuntu : verifier les prerequis du guide ou installer ceux qui manquent.
set -euo pipefail
export LC_ALL=C

mode="${1:---check}"
if (( $# > 1 )) || [[ "$mode" != --check && "$mode" != --install ]]; then
    echo "Usage : bash $0 [--check|--install]" >&2
    exit 2
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Impossible d'identifier le systeme. Ubuntu est requis." >&2
    exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != ubuntu ]] || ! command -v apt-get >/dev/null; then
    echo "Ce script est prevu pour Ubuntu avec APT." >&2
    exit 1
fi

if [[ "$mode" == --install ]] && (( EUID != 0 )); then
    echo "Pour installer : sudo bash $0 --install" >&2
    exit 1
fi

packages=(aircrack-ng iw iproute2 network-manager git curl ca-certificates tar gzip)
missing=()
for package in "${packages[@]}"; do
    if [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" == 'install ok installed' ]]; then
        echo "[OK] $package"
    else
        echo "[MANQUANT] $package"
        missing+=("$package")
    fi
done

if [[ "$mode" == --install ]] && (( ${#missing[@]} > 0 )); then
    apt-get update
    apt-get install -y --no-install-recommends "${missing[@]}"
fi

wordlist=/usr/share/wordlists/rockyou.txt
if [[ -r "$wordlist" && -s "$wordlist" ]]; then
    echo "[OK] $wordlist"
elif [[ "$mode" == --install ]]; then
    # Telecharger uniquement RockYou depuis SecLists, sans cloner tout le depot.
    free_kb=$(df -Pk /usr/share | awk 'NR == 2 {print $4}')
    temp_kb=$(df -Pk "${TMPDIR:-/tmp}" | awk 'NR == 2 {print $4}')
    if (( free_kb < 512000 || temp_kb < 512000 )); then
        echo "Espace insuffisant : prevoir 500 Mio libres dans /usr/share et le dossier temporaire." >&2
        exit 1
    fi
    archive=$(mktemp)
    dictionary=''
    trap 'rm -f -- "$archive"; if [[ -n "$dictionary" ]]; then rm -f -- "$dictionary"; fi' EXIT
    dictionary=$(mktemp)
    curl --fail --location --retry 3 --connect-timeout 20 \
        'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Leaked-Databases/rockyou.txt.tar.gz' \
        --output "$archive"
    tar -xOzf "$archive" rockyou.txt > "$dictionary"
    if [[ ! -s "$dictionary" ]]; then
        echo "Le dictionnaire telecharge est vide." >&2
        exit 1
    fi
    install -D -m 644 "$dictionary" "$wordlist"
    echo "[OK] $wordlist installe"
else
    echo "[MANQUANT] $wordlist"
fi

status=0
if [[ "$mode" == --check ]] && { (( ${#missing[@]} > 0 )) || [[ ! -r "$wordlist" || ! -s "$wordlist" ]]; }; then
    status=1
fi

# Lecture des capacites uniquement : aucune activation du mode moniteur.
if command -v iw >/dev/null; then
    if capabilities=$(iw list 2>/dev/null) && [[ "$capabilities" =~ \*[[:space:]]+monitor([[:space:]]|$) ]]; then
        echo "[OK] Mode moniteur annonce par au moins une carte Wi-Fi"
    else
        echo "[A VERIFIER] Aucune carte compatible mode moniteur detectee. Verifie le materiel et son pilote."
        status=1
    fi
else
    echo "[A VERIFIER] Installe iw pour verifier la compatibilite Wi-Fi."
    status=1
fi

echo "Le point d'acces WPA2 et l'appareil client du laboratoire restent a verifier manuellement."
exit "$status"
