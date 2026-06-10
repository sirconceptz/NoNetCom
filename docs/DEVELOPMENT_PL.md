# Uruchomienie i rozwój aplikacji

## Wymagania

- Flutter z Dartem zgodnym z `sdk: ^3.12.0`;
- Android SDK i JDK 17;
- Xcode oraz CocoaPods do kompilacji iOS;
- macOS do budowania wersji iOS;
- dwa fizyczne urządzenia do testów BLE.

Aktualna wersja produktu pozostaje `1.0.0+1` do czasu przygotowania pierwszego
wydania sklepowego.

## Instalacja

```sh
flutter pub get
flutter doctor
flutter devices
```

Projekt zawiera lokalne wersje wybranych pluginów w `third_party/`. Są one
podłączone przez `dependency_overrides` w `pubspec.yaml`. Nie należy usuwać tego
katalogu bez wcześniejszego wycofania override'ów i ponownej weryfikacji
kompilacji natywnej.

## Uruchomienie

```sh
flutter run -d <device-id>
```

Emulator i symulator nadają się do pracy nad większością UI oraz logiką Dart,
ale nie odzwierciedlają transportu BLE, pracy radia i zużycia baterii.

## Struktura

```text
lib/
  main.dart
  src/
    app/             kompozycja aplikacji, lifecycle i kontrolery funkcji
    data/            lokalny magazyn danych
    domain/          modele kontaktów, grup i wiadomości
    platform/        kanały Flutter <-> Android/iOS
    services/        kryptografia, logi, powiadomienia, audio i bezpieczeństwo
    transport/       trwała kolejka, ramki, ACK i retry
    ui/              widżety rozmów, kontaktów i onboardingu
android/             natywny transport GATT i foreground service
ios/                 Core Bluetooth i state restoration
test/                testy architektury, danych, E2EE i transportu
third_party/         lokalne pluginy Fluttera
```

`AppDependencies` jest composition rootem. `ChatShell` korzysta z przekazanych
serwisów, a kontrolery w `lib/src/app/controllers/` koordynują poszczególne
funkcje. Widżety nie powinny samodzielnie konstruować pluginów ani implementować
logiki protokołu.

## Przepływ wiadomości

1. Kontroler tworzy payload domenowy.
2. `ChatCrypto` szyfruje go do koperty `e2ee-v2`.
3. `ReliableTransport` zapisuje kopertę w trwałym outboxie i dzieli ją na ramki.
4. `BleBridge` przekazuje ramki do natywnej kolejki priorytetowej.
5. Android lub iOS dzieli zapis na binarne fragmenty `N2`.
6. Odbiorca odsyła ACK ramki, a po przetworzeniu całości `deliveryAck`.
7. Dopiero `deliveryAck` usuwa pakiet z outboxa i ustawia `dostarczono`.

Szczegóły są w [PROTOCOL.md](../PROTOCOL.md).

## Kanały platformowe

- metody BLE: `skybridge/ble`;
- zdarzenia BLE: `skybridge/ble/events`;
- wybór pliku: `skybridge/files`.

Główny service UUID:

```text
6d2f9877-2c82-456b-b3f5-09f0fd2f9a11
```

Zmiana UUID albo formatu ramek jest zmianą protokołu i wymaga aktualizacji
Androida, iOS, dokumentacji oraz testów kompatybilności.

## Priorytety transportu

1. `control` - hello i ACK;
2. `realtime` - walkie-talkie;
3. `normal` - wiadomości;
4. `bulk` - transfery plików.

Nie należy kierować dużych danych do kolejki `control`, ponieważ może to
zablokować potwierdzenia i pogorszyć niezawodność całego połączenia.

## Weryfikacja zmian

Minimalny zestaw:

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
plutil -lint ios/Runner/Info.plist
```

Zmiany w BLE, pracy w tle, plikach lub audio wymagają dodatkowo testu na dwóch
fizycznych urządzeniach. Scenariusze wydajnościowe opisuje
[BENCHMARKS.md](../BENCHMARKS.md).

## Dodawanie funkcji

- model i stan trwały umieszczaj odpowiednio w `domain/` i `data/`;
- logikę funkcji dodawaj do kontrolera lub serwisu, nie do dużego widżetu;
- powtarzalne elementy interfejsu umieszczaj w `ui/common/`;
- payloady protokołu wersjonuj i odrzucaj nieznane wersje;
- nie zapisuj plaintextu wiadomości w logach;
- dla zmian współdzielonych dodawaj testy regresji;
- aktualizuj dokumentację, `CHANGELOG.md` i `RELEASE.md`.
