# Dokumentacja NoNetCom

NoNetCom jest komunikatorem offline dla iOS i Androida. Urządzenia znajdujące
się w pobliżu wymieniają wiadomości, pliki i segmenty głosowe przez Bluetooth
Low Energy bez serwera dostarczającego rozmowy.

## Stan projektu

- wersja aplikacji: `1.0.0+1`;
- Android application ID: `com.matapps.nonetcom`;
- iOS bundle ID: `com.matapps.nonetcom`;
- protokół transportowy: `transport-v2`;
- protokół szyfrowania: `e2ee-v2`;
- strona publiczna: <https://nonetcom.mat-apps.com>;
- limit grupy: 6 osób;
- limit pliku: 30 MB;
- walkie-talkie: rozmowy 1:1 bez limitu czasu.

Projekt mobilny i strona WWW są osobnymi repozytoriami Git. Repozytorium strony
znajduje się w katalogu `website/`, który jest ignorowany przez repozytorium
mobilne.

## Dokumenty

### Dla użytkownika

- [Przewodnik użytkownika](USER_GUIDE_PL.md)
- [Rozwiązywanie problemów](TROUBLESHOOTING_PL.md)
- [Dane, prywatność i bezpieczeństwo](SECURITY_AND_DATA_PL.md)

### Dla dewelopera

- [Uruchomienie i rozwój aplikacji](DEVELOPMENT_PL.md)
- [Architektura](../ARCHITECTURE.md)
- [Protokół](../PROTOCOL.md)
- [Model zagrożeń](../THREAT_MODEL.md)
- [Macierz QA na fizycznych urządzeniach](../QA_DEVICE_MATRIX.md)
- [Metodyka benchmarków](../BENCHMARKS.md)
- [Proces wydania](../RELEASE.md)
- [Historia zmian](../CHANGELOG.md)

### Strona WWW

Dokumentacja strony znajduje się w osobnym repozytorium:

- `website/README.md`;
- `website/docs/DEVELOPMENT_PL.md`;
- `website/docs/DEPLOYMENT_PL.md`.

## Ważne ograniczenia

- BLE musi być testowane na fizycznych urządzeniach.
- Zasięg i transfer zależą od sprzętu, systemu, MTU i zakłóceń radiowych.
- E2EE nie chroni odblokowanego lub przejętego urządzenia.
- Ręczne wymuszenie zatrzymania aplikacji przez użytkownika zatrzymuje pracę w
  tle zgodnie z zasadami Androida i iOS.
- Projekt nie przeszedł niezależnego audytu kryptograficznego.
