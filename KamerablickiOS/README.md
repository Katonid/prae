# Kamerablick

iOS/iPadOS-App für RTSP-IP-Kameras (z. B. Tapo):

- beliebig viele Kameras, Passwörter im iOS-Schlüsselbund
- Vollbild-Wiedergabe, Bildschirm bleibt während der Wiedergabe an
- Bild füllend oder eingepasst, waagerecht und/oder senkrecht spiegeln
  (wird je Kamera gemerkt)
- Zoomen mit zwei Fingern und Verschieben, Doppeltipp setzt zurück
- automatischer Neuaufbau, wenn die Verbindung abreißt
- Vorschaubild in der Übersicht

## Bauen

`Kamerablick.xcodeproj` in Xcode öffnen — Xcode lädt VLCKit beim ersten
Mal selbst (einige hundert MB). iPhone wählen, ausführen.

Beim ersten Start fragt iOS nach Zugriff auf das **lokale Netzwerk** —
erlauben, sonst erreicht die App keine Kamera.

## Tapo-Einstellungen

- Port 554, Pfad `/stream1` (HD) oder `/stream2` (SD)
- Benutzer/Passwort = das in der Tapo-App unter *Kameraeinstellungen →
  Erweitert → Kamerakonto* angelegte Konto

Außerhalb des Heimnetzes braucht es wie bisher eine Portweiterleitung
oder ein VPN.
