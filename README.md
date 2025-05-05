# 📷 Raspberry Pi Kamera Webinterface mit Aufnahme & Livestream

Ich habe mit Unterstützung von ChatGPT ein vollautomatisiertes Kamera-System für den Raspberry Pi Zero 2 W entwickelt.  
Ziel war es, eine WLAN-fähige Kamera mit Livestream, segmentierter Aufnahme und einfacher Weboberfläche bereitzustellen – mit bestmöglicher Auflösung der Raspberry Pi Kamera v3.

---

## 🔧 Funktionen

- **Livestream** in voller 4608x2592 Auflösung
- **Automatische Aufnahme** in 15-Minuten-Segmenten (als `.mp4`)
- **Webinterface** zur Steuerung (Start, Stop, Zoom, Autofokus)
- **Aufnahmezugriff über NGINX**, geschützt per Passwort
- **Autostart** beim Hochfahren des Pi
- **Automatische Löschung alter Aufnahmen** nach 7 Tagen

---

## 🚀 Installation

1. Raspberry Pi OS Lite (empfohlen) installieren
2. SSH aktivieren & WLAN konfigurieren
3. Dieses Repository klonen:
   ```bash
   git clone <REPO-URL>
   cd <Ordnername>
