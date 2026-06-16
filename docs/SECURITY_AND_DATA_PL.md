# Dane, prywatność i bezpieczeństwo

## Granice systemu

Treści rozmów nie przechodzą przez serwer NoNetCom. Strona WWW i jej formularz
kontaktowy są oddzielone od mobilnego kanału wiadomości. Serwer WWW nie
uczestniczy w odkrywaniu kontaktów, szyfrowaniu ani dostarczaniu rozmów.

## E2EE

NoNetCom używa:

- X25519 jako kluczy tożsamości;
- HKDF-SHA256 do kierunkowych kluczy 256-bitowych;
- AES-256-GCM do szyfrowania i uwierzytelniania;
- AAD zawierającego wersję protokołu, `packetId` i licznik;
- trwałych liczników wysyłania;
- okna 512 odebranych liczników jako ochrony przed replay.

Kod bezpieczeństwa kontaktu jest skróconym fingerprintem publicznego klucza.
Pełny opis znajduje się w [PROTOCOL.md](../PROTOCOL.md), a założenia i
ograniczenia w [THREAT_MODEL.md](../THREAT_MODEL.md).

## Model zagrożeń w skrócie

NoNetCom chroni treść wiadomości, plików i segmentów głosowych przesyłanych
między zweryfikowanymi urządzeniami. Zakłada, że użytkownik porówna kod QR lub
kod bezpieczeństwa przy budowaniu zaufania.

Aplikacja nie ukrywa samego faktu używania Bluetooth, czasu transmisji, rozmiaru
zaszyfrowanych pakietów ani obecności urządzenia w pobliżu. Nie chroni też
telefonu przejętego przez malware, urządzenia z rootem/jailbreakiem ani
odblokowanej aplikacji pozostawionej osobie trzeciej.

Aktywny atakujący w pobliżu może opóźniać, gubić, duplikować lub modyfikować
pakiety. Szyfrowanie i AAD mają wykrywać modyfikacje, a trwałe okno replay ma
blokować ponowne przetwarzanie wcześniej uwierzytelnionych pakietów. Atakujący
może jednak spowodować brak dostępności przez zakłócanie radia lub zalewanie
kanału.

## Dane lokalne

`SharedPreferences` przechowuje między innymi:

- profil;
- kontakty, grupy i historię wiadomości;
- publiczne klucze kontaktów i stan zaufania;
- prywatną i publiczną tożsamość X25519;
- liczniki E2EE i okno replay;
- skrót PIN-u;
- stan kolejki i transferów oczekujących;
- ustawienia diagnostyczne.

Katalog dokumentów aplikacji zawiera odebrane pliki, eksporty, outbox transportu
i logi. Tymczasowe nagrania głosowe są tworzone w katalogu cache systemu.

Prywatny klucz jest obecnie zapisany w lokalnym magazynie aplikacji, ale nie
jest jeszcze opakowany kluczem sprzętowym Android Keystore lub iOS Keychain.
Jest to znane zadanie hardeningowe przed pozycjonowaniem produktu jako
rozwiązania o podwyższonym poziomie bezpieczeństwa.

## Logi

- maksymalny rozmiar jednego pliku: 15 MB;
- maksymalnie 2 pliki dla bieżącej wersji;
- logi poprzednich wersji są usuwane po aktualizacji;
- eksporty tymczasowe są usuwane przy kolejnym uruchomieniu loggera;
- użytkownik może podejrzeć, skopiować, wyczyścić lub udostępnić logi.

Logi mogą zawierać komunikaty błędów, stack trace, wersję aplikacji i techniczne
zdarzenia transportu. Kod nie powinien logować treści wiadomości ani zawartości
plików. Przed wysłaniem użytkownik ma możliwość ręcznego podglądu.

Regresję prywatności raportów zabezpieczają testy, które sprawdzają brak pól
wiadomości, plików, kluczy prywatnych i danych kryptograficznych w eksporcie
diagnostycznym.

## Checklista bezpieczeństwa przed wydaniem

- uruchomić `flutter analyze` i `flutter test`;
- potwierdzić testy E2EE: zły klucz, zły `packetId`, nieznana wersja protokołu,
  replay window;
- potwierdzić testy transportu: duplikaty ramek, losowa kolejność, retry,
  trwały outbox i `deliveryAck`;
- sprawdzić, że logi i raporty nie zawierają treści rozmów ani kluczy
  prywatnych;
- wykonać testy na fizycznych urządzeniach Android-Android, Android-iOS i
  iOS-iOS;
- potwierdzić ostrzeżenie przy zmianie klucza zweryfikowanego kontaktu;
- upewnić się, że dokumentacja i polityka prywatności opisują aktualny stan
  aplikacji.

## Backup tożsamości

Plik `nonetcom-identity-backup.json` zawiera prywatny klucz E2EE. Pozwala
zachować tę samą tożsamość po reinstalacji, ale jego przejęcie umożliwia
podszywanie się pod użytkownika. Należy przechowywać go w zaszyfrowanym miejscu
i nie wysyłać przez niezaufane kanały.

## Backup kontaktów

Eksport zaufanych kontaktów zawiera lokalne nazwy, publiczne klucze i stan
zaufania. Nie zawiera prywatnego klucza użytkownika ani historii rozmów. Import
nie przywraca tożsamości nadawcy.

## PIN i biometria

PIN jest przechowywany jako skrót SHA-256, a nie jawny tekst. Blokada aplikacji
ogranicza dostęp do interfejsu. Nie jest pełnym szyfrowaniem lokalnej bazy i nie
chroni urządzenia przejętego przez malware lub atakującego z dostępem
systemowym.

## Uprawnienia

| Uprawnienie | Cel |
| --- | --- |
| Bluetooth scan/connect/advertise | odkrywanie i transport BLE |
| Lokalizacja na starszym Androidzie | wymaganie systemowe dla skanowania BLE |
| Mikrofon | wiadomości głosowe i walkie-talkie |
| Powiadomienia | nowe wiadomości i foreground service |
| Biometria / Face ID | opcjonalne odblokowanie aplikacji |

NoNetCom nie powinien żądać uprawnienia, którego nie wykorzystuje w opisanej
funkcji.
