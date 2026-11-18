# impasto-local

Nakładka magiszonek na [impasto](https://github.com/andreumassanet/impasto).
`~/impasto` jest czystym klonem autora (origin = autor), tu są tylko moje zmiany.

- `hypr-custom/`  -> `~/.config/hypr/custom/` (loader autora; `setup` tego nie rusza)
- `patches/quickshell/` -> łatki na pliki quickshell (autor nie ma tu haka)
- `packages/` -> paczki ponad listę autora
- `bin/ systemd/ config/ applications/ icons/` + `bootstrap.sh`, `finish.sh` -> system i narzędzia

`./apply.sh` nakłada nakładkę, `./update.sh` = `setup update` od autora + nakładka.
Łatka, która przestaje pasować, wypisuje `NIE PASUJE` (autor zmienił ten fragment).
