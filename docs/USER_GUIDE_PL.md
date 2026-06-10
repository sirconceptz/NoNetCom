# Przewodnik użytkownika

## Wymagania

Do rozmowy potrzebne są dwa fizyczne telefony z NoNetCom i włączonym
Bluetooth. Internet, konto użytkownika ani karta SIM nie są wymagane.

W samolocie:

1. Włącz tryb samolotowy.
2. Ręcznie włącz Bluetooth.
3. Uruchom NoNetCom na obu urządzeniach.

Korzystanie z Bluetooth musi być zgodne z poleceniami załogi i regulaminem
przewoźnika.

## Pierwsze uruchomienie

1. Ustaw lokalną nazwę profilu.
2. Przyznaj wymagane uprawnienia Bluetooth i powiadomień.
3. Przyznaj dostęp do mikrofonu, jeśli chcesz używać funkcji głosowych.
4. Uruchom Bluetooth LE.
5. Wybierz skanowanie kontaktów.

Android może dodatkowo pokazać trwałe powiadomienie usługi Bluetooth. Jest ono
potrzebne, aby system pozwalał aplikacji pracować w tle.

## Dodawanie i weryfikowanie kontaktu

Po wykryciu urządzenia kontakt pojawi się na liście. Nazwę kontaktu można
zmienić lokalnie; nie zmienia to nazwy na drugim telefonie.

Przed zaufaniem kontaktowi:

1. Otwórz szczegóły weryfikacji.
2. Porównaj kod bezpieczeństwa na obu urządzeniach albo użyj QR.
3. Potwierdź kontakt dopiero po zgodnym porównaniu.

Jeżeli zweryfikowany kontakt zacznie przedstawiać inny klucz, aplikacja pokaże
ostrzeżenie. Może to oznaczać reinstalację, zmianę tożsamości albo próbę
podszycia się. Kod należy porównać ponownie innym zaufanym kanałem.

## Wiadomości

Status własnej wiadomości może mieć jedną z wartości:

- `wysyłanie` - pakiet jest w kolejce lub czeka na potwierdzenie;
- `dostarczono` - odbiorca przetworzył wiadomość i odesłał ACK;
- `nie udało się` - wyczerpano limit prób dostarczenia.

Gdy kontakt chwilowo znika z zasięgu, zaszyfrowana wiadomość pozostaje w
lokalnej kolejce. Po ponownym wykryciu kontaktu aplikacja próbuje wznowić
dostarczenie.

## Grupy

Grupa może zawierać maksymalnie 6 osób. Wiadomość grupowa jest szyfrowana i
dostarczana osobno do każdego członka grupy. Grupy obsługują obecnie wiadomości
tekstowe; rozmowy głosowe na żywo pozostają funkcją 1:1.

## Pliki

NoNetCom wysyła pliki do 30 MB. Plik jest dzielony na zaszyfrowane fragmenty, a
interfejs pokazuje postęp transferu. Odebrane pliki są przechowywane w katalogu
dokumentów aplikacji.

Nie zamykaj aplikacji systemowym `Wymuś zatrzymanie` podczas transferu. Zwykłe
przejście do innej aplikacji może pozostawić transport aktywny w tle.

## Funkcje głosowe

NoNetCom ma dwa tryby:

- wiadomość głosowa 1:1 - nagranie do 45 sekund i maksymalnie 5 MB;
- walkie-talkie 1:1 - nieograniczona czasowo sesja segmentowa.

Walkie-talkie nie jest klasycznym połączeniem telefonicznym. Dźwięk jest
dzielony na krótkie zaszyfrowane segmenty i korzysta z priorytetowej kolejki BLE.
Jakość zależy od odległości i obciążenia łącza.

## Blokada aplikacji

W centrum bezpieczeństwa można ustawić PIN. Po jego ustawieniu aplikacja może
również używać biometrii dostępnej na urządzeniu. PIN chroni dostęp do
interfejsu, ale nie zastępuje blokady ekranu i zabezpieczeń systemowych.

## Backupy

NoNetCom obsługuje dwa różne eksporty:

| Eksport | Zawartość | Ryzyko |
| --- | --- | --- |
| Zaufane kontakty | lokalne nazwy i publiczne klucze zweryfikowanych kontaktów | nie zawiera prywatnej tożsamości |
| Tożsamość E2EE | klucz prywatny, klucz publiczny i nazwa profilu | plik należy chronić jak hasło |

Import kontaktów po reinstalacji przywraca zaufane publiczne dane, ale nie
przywraca tej samej tożsamości urządzenia. Do zachowania tożsamości służy osobny
backup tożsamości E2EE.

## Diagnostyka i logi

W ustawieniach danych lokalnych można:

- sprawdzić uprawnienia i stan możliwości urządzenia;
- wyeksportować raport diagnostyczny;
- podejrzeć i skopiować logi błędów;
- przygotować wiadomość e-mail z logami do dewelopera;
- wyczyścić logi, wiadomości albo kontakty.

Dołączenie metadanych diagnostycznych do zgłoszenia jest kontrolowane osobnym
przełącznikiem. Raport nie powinien zawierać treści rozmów ani przesyłanych
plików.
