# Changelog

## 1.0.0+1 - 2026-06-09

Pierwsze przygotowanie wydania NoNetCom.

- Szyfrowany czat offline przez Bluetooth LE.
- Stabilny transport wiadomości z ramkami, ACK, kolejką i ponawianiem.
- Transport BLE v2 z natywnymi kolejkami GATT dla każdego kontaktu.
- Backpressure dla zapisów i powiadomień na Androidzie oraz iOS.
- Negocjowanie i raportowanie MTU.
- Binarna fragmentacja natywna niezależna od ramek wiadomości.
- Priorytety ruchu: sterowanie, głos, wiadomości i transfery masowe.
- Telemetria przeciążenia kolejki i błędów transportu.
- E2EE v2 z kierunkowymi kluczami HKDF-SHA256.
- Uwierzytelnianie identyfikatora pakietu i licznika przez AES-GCM AAD.
- Trwałe liczniki wysyłania oraz ochrona przed replay.
- Fingerprint kontaktu oparty na SHA-256.
- Android foreground service typu `connectedDevice`.
- Cache'owany FlutterEngine utrzymujący kolejkę i E2EE po zniknięciu UI.
- iOS Core Bluetooth state restoration dla central i peripheral.
- Jawny kontener zależności, koordynator lifecycle i serwisy diagnostyczne.
- Kontakty, lokalne nazwy i weryfikacja zaufania kluczy.
- Ostrzeżenie przy zmianie klucza kontaktu.
- Rozmowy grupowe do 6 osób.
- Wysyłanie plików do 30 MB.
- Zaszyfrowane wiadomości głosowe push-to-talk w rozmowach 1:1.
- Powiadomienia o nowych wiadomościach.
- Logi błędów z lokalnym podglądem, kopiowaniem i wysyłką do dewelopera.
- Onboarding, diagnostyka uprawnień i lokalne raporty diagnostyczne.
- Eksport/import zaufanych kontaktów bez prywatnego klucza E2EE.
- Konfiguracja release signing dla Androida.
