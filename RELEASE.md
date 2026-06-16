# NoNetCom Release Checklist

## Versioning

- Publiczna wersja aplikacji jest w `pubspec.yaml` jako `version: x.y.z+build`.
- `x.y.z` to wersja widoczna w App Store i Google Play.
- `build` musi rosnąć przy każdym uploadzie do sklepów.
- Po zmianie wersji dopisz wpis w `CHANGELOG.md`.

## Android Signing

1. Wygeneruj lub pobierz release keystore.
2. Umieść plik keystore poza repo albo w `android/app/nonetcom-release.jks`.
3. Skopiuj `android/key.properties.example` do `android/key.properties`.
4. Uzupełnij:
   - `storePassword`
   - `keyPassword`
   - `keyAlias`
   - `storeFile`
5. Nie commituj `android/key.properties` ani plików `.jks` / `.keystore`.
6. Zbuduj:

```sh
flutter build appbundle --release
```

Artefakt do Google Play: `build/app/outputs/bundle/release/app-release.aab`.

## iOS Bundle/Profile Checklist

- Bundle Identifier: `com.matapps.nonetcom`.
- Team: konto Apple Developer MatApps.
- Signing Certificate: Apple Distribution.
- Provisioning Profile: App Store profile dla `com.matapps.nonetcom`.
- Capabilities do sprawdzenia w Xcode:
  - Background Modes: Uses Bluetooth LE accessories.
  - Background Modes: Acts as a Bluetooth LE accessory.
  - Push Notifications tylko jeśli w przyszłości pojawią się zdalne push.
  - App Groups tylko jeśli pojawi się współdzielenie danych z rozszerzeniami.
- `Info.plist` musi zawierać opisy użycia Bluetooth, powiadomień i lokalnych plików.
- Przed uploadem uruchom:

```sh
flutter build ios --release
```

Potem archiwizuj w Xcode i wyślij przez Organizer / Transporter.

## Preflight

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
plutil -lint ios/Runner/Info.plist
```

## Physical Device QA

Przed publikacją wykonaj macierz z [QA_DEVICE_MATRIX.md](QA_DEVICE_MATRIX.md):

- Android ↔ Android;
- Android ↔ iOS w obu kierunkach;
- iOS ↔ iOS.

Wyniki `FAIL` i `FLAKY` muszą mieć decyzję wydaniową lub link do znanego
problemu. Wyniki wydajnościowe publikuj dopiero po osobnym przebiegu według
[BENCHMARKS.md](BENCHMARKS.md).

## Store Review Notes

- Test offline wymaga dwóch fizycznych urządzeń.
- Na Androidzie aktywne BLE pokazuje trwałe powiadomienie foreground service.
- Na iOS test przywrócenia wymaga zablokowania ekranu lub ubicia procesu przez
  system, a nie ręcznego force quit użytkownika.
- Włącz tryb samolotowy, następnie ręcznie włącz Bluetooth.
- Uruchom NoNetCom na obu urządzeniach i użyj skanowania BLE.
- Symulatory i emulatory nie pokrywają realnego BLE.
