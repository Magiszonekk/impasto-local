# impasto-local

Moja nakładka na [impasto](https://github.com/andreumassanet/impasto) (Arch + Hyprland + Quickshell).

Zasada: `~/impasto` jest **czystym klonem autora** (`origin` = `andreumassanet/impasto`, zero własnych commitów),
a wszystko moje leży tutaj i jest nakładane na wierzch. Dzięki temu aktualizacje idą od autora.

| Co | Gdzie w repo | Dokąd trafia |
|---|---|---|
| skróty, reguły okien, klawiatura, env (NVIDIA) | `hypr-custom/*.lua` | `~/.config/hypr/custom/` (autor tego katalogu nie rusza) |
| zmiany w Quickshell (przyciski paska, tooltip, dock) | `patches/quickshell/*.patch` | nakładane na `~/.config/quickshell` |
| dodatkowe paczki | `packages/pacman.txt`, `aur.txt` | instalowane ponad listę autora |
| skrypty i timery | `bin/`, `systemd/` | `~/.local/bin`, `~/sw.sh`, `~/.config/systemd/user` |
| greeting kitty | `home/zshrc.local` | `~/.zshrc.local` |
| system (snapper, Limine, mkinitcpio, mirrorlist) | `bootstrap.sh` | `/etc`, `/boot` |
| narzędzia i domyślne aplikacje | `finish.sh`, `config/`, `applications/`, `icons/` | `~` |

Skrypty: `bootstrap.sh` (faza systemowa), `finish.sh` (faza w sesji), `apply.sh` (nałóż nakładkę, idempotentny),
`update.sh` (aktualizacja od autora + nakładka).

---

## Nowa maszyna

Wymagania: Arch zainstalowany przez `archinstall` z **btrfs**, bootloaderem **Limine** (ESP zamontowane jako `/boot`),
NetworkManagerem i zwykłym użytkownikiem z sudo. `bootstrap.sh` sprawdza to na starcie i przerywa, jeśli coś się nie zgadza.

1. Zaloguj się na TTY jako zwykły użytkownik i sklonuj oba repo:

   ```sh
   git clone https://github.com/andreumassanet/impasto ~/impasto
   git clone https://github.com/Magiszonekk/impasto-local ~/impasto-local
   ```

2. Faza systemowa (z TTY, nie z sesji graficznej):

   ```sh
   ~/impasto-local/bootstrap.sh
   ```

   Robi: multilib, polską klawiaturę (TTY i SDDM), **przypięty mirrorlist** (Arch Linux Archive, domyślnie „wczoraj”),
   snapper + snap-pac + limine-snapper-sync, `btrfs-overlayfs`, `/etc/default/limine`, zram, skrypty użytkownika
   i timery, sterownik NVIDIA tylko jeśli wykryje kartę NVIDIA, `hyprland` i `kitty`, snapshot bazowy.
   Jest idempotentny, więc można uruchomić ponownie.

   Zmienne (opcjonalne):
   - `PIN_DATE=RRRR/MM/DD` – inna data przypięcia repozytoriów. **Hyprland musi być ≥ 0.56** w tym snapshocie.
   - `KEYMAP=pl` – układ klawiatury konsoli i ekranu logowania.
   - `WIN_UUID=… UBUNTU_UUID=…` – partycje innych systemów do zamontowania w `/mnt/win` i `/mnt/ubuntu`
     (puste = pominięte). UUID-y sprawdzisz przez `lsblk -o NAME,UUID,MODEL`. Wpisy Windows/Ubuntu w Limine robi
     `bin/limine-dualboot` na podstawie NVRAM, więc dotyczy to tylko maszyn z dualbootem.

3. `sudo reboot`. Sprawdź w menu Limine wpis „Arch Linux” i podmenu Snapshots, a po starcie `efibootmgr`
   (firmware potrafi przestawić kolejność bootowania).

4. Uruchom Hyprland (`start-hyprland`), w kitty:

   ```sh
   ~/impasto-local/finish.sh
   ```

   Robi: snapshot, `./setup install` w `~/impasto`, **potem** `apply.sh` (hypr `custom/`, łatki, paczki),
   splash Plymouth (ręcznie przez `/etc/default/limine`, bo `./setup splash` edytuje generowany `limine.conf`),
   Claude Code, Hermes Agent, herdr, Discordrive (AppImage) oraz domyślne aplikacje i układ paska.
   Trwa kilka minut (kompilacja pluginów Hyprlanda).

5. Ręcznie zostaje: logowanie (`claude`, `hermes setup`), Spotify (uruchom raz, potem `~/impasto/setup spotify`),
   wylogowanie i zalogowanie, żeby pasek wczytał układ.

> `finish.sh` uruchamiaj z sesji Hyprland. Poza nią przerywa, bo pluginy są budowane pod działający kompozytor.

---

## Migracja ze starej wersji

„Stara wersja” = `~/impasto` jest klonem **mojego forka** `Magiszonekk/impasto` (z własnymi commitami i edytowanymi
plikami autora), a nie czystym klonem autora.

Przed czymkolwiek:

```sh
sudo snapper -c root create -d "przed migracją na impasto-local" --print-number
cd ~/impasto
git status -sb                      # niewypchnięte commity? wypchnij je do forka, zostaną jako archiwum
git branch backup/pre-split         # lokalne zabezpieczenie
git bundle create ~/impasto-pre-split.bundle --all
```

1. **Przepnij `~/impasto` na autora.** `checkout -B` jest tu jedyną operacją, której samym gitem nie cofniesz
   (dlatego backup powyżej):

   ```sh
   cd ~/impasto
   git remote rename origin fork
   git remote add origin https://github.com/andreumassanet/impasto.git
   git fetch origin
   git checkout -B main origin/main
   git branch -u origin/main
   ```

2. **Przywróć pliki, które edytowałeś, do wersji autora.** Inaczej `setup` zachowa Twoje edycje, a nową wersję
   położy obok jako `.new`, i łatki quickshella nigdy nie złapią nowych plików. Twoje wersje trafiają
   do kopii w `~/.local/state/impasto/backups/<data>`.

   ```sh
   cd ~/impasto
   ./setup files list                                   # co jest „edited”
   ./setup files list | python3 -c 'import json,sys; print(*[e["path"] for e in json.load(sys.stdin)["edited"]])' \
       | xargs -r ./setup files reset
   ./setup files list                                   # ma pokazać puste "edited"
   ```

   Jeśli coś w tych plikach było Twoje i nie ma go w `hypr-custom/` ani w `patches/`, weź to z kopii
   w `backups/` zanim pójdziesz dalej.

3. **Sklonuj nakładkę i zaktualizuj.** `update.sh` robi `setup update` od autora, a potem `apply.sh`:

   ```sh
   git clone https://github.com/Magiszonekk/impasto-local ~/impasto-local
   ~/impasto-local/update.sh
   ```

   `apply.sh` przy okazji instaluje skrypty z `bin/` i timery, więc stare wersje na migrowanej maszynie
   zostaną zastąpione. Kończy się przeładowaniem Hyprlanda i sprawdzeniem `hyprctl configerrors`.

4. **Posprzątaj po starym układzie** (opcjonalnie):
   - `vscodium-bin` i `zen-browser-bin` dołoży teraz `./setup install` autora. Jeśli ich nie chcesz:
     `yay -Rns vscodium-bin zen-browser-bin`. Nakładka nie umie ich ukryć przed `setup`.
   - Stare pliki `*.bak*` w `~/.config`.
   - Remote `fork` możesz zostawić albo usunąć: `git remote remove fork`.

5. `sudo reboot`, jeśli `setup` napisał o wymienionych bibliotekach.

Po migracji sprawdź:

```sh
cd ~/impasto && git remote -v && ./setup files list    # origin = autor; edited tylko 3 pliki z patches/
hyprctl configerrors                                   # puste
```

---

## Aktualizacje

```sh
~/impasto-local/update.sh
```

Nie używaj `./setup update` ani przycisku Update w Ustawieniach → System. Przycisk wywołuje `~/impasto/setup update`
bez nakładki: trzy pliki quickshell z łatek zostaną wtedy po staremu, a nowa wersja autora wyląduje obok jako `.new`.
Zakładka Updates poprawnie pokazuje za to, że autor ma nowości, bo porównuje `~/impasto` z `origin`.

`update.sh` odmawia pracy, jeśli `~/impasto` ma lokalne zmiany albo `origin` nie wskazuje na autora.
Jeśli `apply.sh` napisze `NIE PASUJE <plik>.patch`, autor zmienił ten fragment pliku: popraw łatkę
(nałóż ją `git apply --3way` w świeżym `git worktree` z `origin/main`, a nową zrób przez `git diff HEAD`).

Aktualizacje paczek systemowych idą osobno przez `sys-update` (przypięty mirrorlist, miesięczny cykl).

## Nowe zmiany

Nie edytuj plików w `~/impasto`. Skróty, reguły okien i env dopisuj w `hypr-custom/` (ładowane po module
autora, więc przeniesienie cudzego skrótu na inny klawisz wymaga `hl.unbind(...)` przed własnym `hl.bind`).
Zmiany w Quickshell rób jako nowa łatka w `patches/quickshell/`. Różnice sprzętowe wykrywaj w czasie działania
(`/sys`, `/proc/driver/nvidia`), a nie osobnymi gałęziami.

## Co nie jest przetestowane

Skrypty sprawdzono składniowo (`bash -n`), a `apply.sh` także w dwóch przebiegach na kopii czystych plików autora.
Ścieżki **nowej maszyny** (`bootstrap.sh` + `finish.sh`) i **migracji** nie były uruchomione na czystym systemie.
