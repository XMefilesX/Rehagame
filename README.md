# Rehagame

**Interaktywna gra wspierająca rozwój zręczności, czasu reakcji oraz rehabilitację ruchową** (projekt zaliczeniowy – Informatyka, WSEI Lublin)

## Opis

Gra typu non-immersive exergame w Godot 4.2D. 
- 30-sekundowe sesje treningowe
- Ruchome cele do klikania (element śledzenia obiektów)
- Pomiar czasu reakcji + system punktowy z bonusem za szybkie trafienia
- Binarny wynik sesji: „WYGRAŁEŚ!” / „PRZEGRAŁEŚ!” (próg: średni RT < 1s lub ≥80 pkt)
- Zapis wyników lokalnie do `user://sessions.json`
- **Ekran „Moje postępy”** – tekstowa lista ostatnich sesji (data, RT, trafienia, punkty, wynik)
- Wysoki kontrast, duże czcionki – zgodne z zasadami dostępności
- Sterowanie: mysz (główne) + klawiatura (ESC = pauza)
- Stały poziom trudności „normalny” – brak gamifikacji odznak/poziomów (zgodnie z minimalnym zakresem prototypu)

## Wymagania PDF (zadanie 2.2) – spełnione
- Rejestrowanie: czas reakcji, liczba trafień, powtórzenia
- Lokalny zapis JSON
- Tekstowy ekran postępów
- Gamifikacja podstawowa (punkty + binarny wynik)
- Dostępność (kontrast, czytelność)

## Jak uruchomić
1. Otwórz folder w Godot Engine (4.3+)
2. Uruchom scenę `main.tscn`
3. Kliknij ▶ Start
4. Po sesji lub w menu: 📊 Moje postępy

Stworzone jako prototyp unsupervised exergame dla osób z łagodnymi zaburzeniami motorycznymi.