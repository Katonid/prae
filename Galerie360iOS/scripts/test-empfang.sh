#!/usr/bin/env bash
# Prüft die Empfangsdatei (Galerie360/Web/galerie360-empfang-vorlage.txt) mit `php -S`:
# Schlüssel, Teil-Upload, Liste, Löschen — und dass sie nichts außerhalb ihrer Galerieordner
# anfasst (keine Pfadsprünge, kein PHP, kein .htaccess, keine fremden Ordner).
set -u
HIER="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d)"
trap 'kill $PID 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/web/360Grad"
KEY="probe-$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
SUMME=$(printf %s "$KEY" | sha256sum | cut -d' ' -f1)
sed "s/{{SCHLUESSEL_SHA256}}/$SUMME/" "$HIER/Galerie360/Web/galerie360-empfang-vorlage.txt" > "$W/web/360Grad/galerie360-empfang.php"
echo fremd > "$W/web/360Grad/andere.txt"
php -S 127.0.0.1:8765 -t "$W/web" >"$W/server.log" 2>&1 &
PID=$!
sleep 1
U=http://127.0.0.1:8765/360Grad/galerie360-empfang.php
O=urlaub-abcdefghijklmnopqrstuvwxyz
FEHLER=0
pruefe() { if [ "$1" = "$2" ]; then echo "  ✓ $3"; else echo "  ✗ $3 (erwartet $2, war $1)"; FEHLER=$((FEHLER+1)); fi; }
code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" "$U?aktion=pruefen")" 200 "richtiger Schlüssel"
pruefe "$(code -X POST -H "X-G360-Schluessel: falsch" "$U?aktion=pruefen")" 403 "falscher Schlüssel abgewiesen"
pruefe "$(code "$U?aktion=pruefen")" 405 "GET abgewiesen"

head -c 3000000 /dev/urandom > "$W/gross.bin"
head -c 1500000 "$W/gross.bin" > "$W/t1"; tail -c +1500001 "$W/gross.bin" > "$W/t2"
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" --data-binary @"$W/t1" "$U?aktion=hochladen&pfad=$O/media/videos/a.mp4&versatz=0")" 200 "erstes Stück"
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" --data-binary @"$W/t2" "$U?aktion=hochladen&pfad=$O/media/videos/a.mp4&versatz=1500000&ende=1&groesse=3000000")" 200 "letztes Stück"
cmp -s "$W/gross.bin" "$W/web/360Grad/$O/media/videos/a.mp4"; pruefe $? 0 "Datei kommt Byte für Byte an"
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" --data-binary @"$W/t2" "$U?aktion=hochladen&pfad=$O/b.jpg&versatz=99")" 409 "falsche Stelle abgewiesen"
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" --data-binary 'kurz' "$U?aktion=hochladen&pfad=$O/c.jpg&versatz=0&ende=1&groesse=99")" 422 "unvollständige Datei abgewiesen"
LISTE=$(curl -s -X POST -H "X-G360-Schluessel: $KEY" "$U?aktion=liste&ordner=$O")
case "$LISTE" in *"$O/media/videos/a.mp4\":3000000"*) pruefe 1 1 "Liste mit Größe";; *) pruefe "$LISTE" "…a.mp4:3000000" "Liste mit Größe";; esac

for p in "../andere.txt" "$O/../andere.txt" "$O/x.php" "$O/x.PHP" "$O/.htaccess" "andere.txt" "normalerordner/x.jpg" "$O/a/../../x.jpg" "$O/x.phtml"; do
  pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" --data-binary 'x' "$U?aktion=hochladen&pfad=$p&versatz=0&ende=1")" 400 "abgewiesen: $p"
done
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" "$U?aktion=loeschen&pfad=andere.txt")" 400 "fremde Datei nicht löschbar"
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" "$U?aktion=loeschen&pfad=galerie360-empfang.php")" 400 "Empfangsdatei nicht löschbar"
[ -f "$W/web/360Grad/andere.txt" ]; pruefe $? 0 "fremde Datei unberührt"
pruefe "$(code -X POST -H "X-G360-Schluessel: $KEY" "$U?aktion=loeschen&pfad=$O")" 200 "Galerieordner löschen"
[ -e "$W/web/360Grad/$O" ]; pruefe $? 1 "Ordner ist weg"
[ -f "$W/web/360Grad/galerie360-empfang.php" ]; pruefe $? 0 "Empfangsdatei bleibt"

if [ "$FEHLER" -gt 0 ]; then echo "$FEHLER Prüfung(en) fehlgeschlagen"; cat "$W/server.log"; exit 1; fi
echo "Empfangsdatei in Ordnung."
