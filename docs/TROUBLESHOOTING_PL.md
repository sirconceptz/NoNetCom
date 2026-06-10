# Rozwiązywanie problemów

## Kontakty się nie widzą

1. Sprawdź, czy oba urządzenia obsługują BLE.
2. Włącz Bluetooth na obu telefonach.
3. W trybie samolotowym włącz Bluetooth ponownie ręcznie.
4. Przyznaj uprawnienia skanowania, łączenia i reklamowania.
5. Na starszym Androidzie sprawdź uprawnienie lokalizacji.
6. Uruchom skanowanie na jednym urządzeniu i pozostaw aplikację aktywną na
   drugim.
7. Zmniejsz odległość i wyłącz inne intensywne urządzenia Bluetooth.

Emulator Androida i symulator iOS nie są wiarygodnym testem odkrywania BLE.

## Kontakt jest offline mimo wcześniejszego połączenia

- odczekaj do zakończenia ponownego skanowania;
- sprawdź, czy system nie wyłączył Bluetooth;
- na Androidzie upewnij się, że działa powiadomienie usługi NoNetCom;
- wyłącz dla aplikacji agresywne oszczędzanie baterii;
- nie używaj `Wymuś zatrzymanie`;
- na iOS ponownie otwórz aplikację po ręcznym force quit.

## Wiadomość pozostaje w stanie „wysyłanie”

Wiadomość jest zaszyfrowana i czeka w outboxie na kontakt lub ACK. Przywróć
zasięg i pozostaw oba urządzenia aktywne. Po wyczerpaniu prób status zmieni się
na `nie udało się`.

## Transfer pliku nie kończy się

- sprawdź, czy plik ma nie więcej niż 30 MB;
- utrzymuj urządzenia blisko siebie;
- zakończ walkie-talkie, jeśli transfer jest bardzo wolny;
- sprawdź wolne miejsce na urządzeniu odbiorcy;
- nie usuwaj pliku źródłowego podczas wysyłki.

Pliki mają niższy priorytet niż ACK, głos na żywo i zwykłe wiadomości.

## Brak dźwięku

- przyznaj dostęp do mikrofonu;
- sprawdź głośność multimediów i wyciszenie systemowe;
- upewnij się, że rozmowa jest 1:1;
- sprawdź, czy inne urządzenie pozostaje połączone;
- zakończ i rozpocznij nową sesję walkie-talkie.

## Brak powiadomień

- przyznaj uprawnienie powiadomień;
- sprawdź ustawienia kanału NoNetCom w systemie;
- wyłącz ograniczenia baterii dla aplikacji;
- pamiętaj, że ręczne wymuszenie zatrzymania blokuje pracę w tle.

## Ostrzeżenie o zmianie klucza

Nie zatwierdzaj automatycznie nowego klucza. Zapytaj kontakt, czy reinstalował
aplikację albo importował inną tożsamość. Porównaj nowy kod lub QR zaufanym
kanałem.

## Zgłoszenie błędu

1. Otwórz `Dane lokalne`.
2. Wejdź w podgląd logów błędów.
3. Sprawdź, czy nie zawierają danych, których nie chcesz udostępnić.
4. Opcjonalnie włącz metadane diagnostyczne.
5. Wybierz wysłanie logów do dewelopera.

W zgłoszeniu podaj modele telefonów, wersje systemów, odległość, stan ekranu,
moment utraty połączenia i kroki pozwalające odtworzyć problem.
