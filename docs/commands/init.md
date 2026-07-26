# `init` Commands

## Amac

Shell ortaminda plume PHP shim'lerini tek komutla aktif etmek; ilk kurulumda host profili ve onboarding.

Alt komutlar:

- `init shell` — bu dosya
- `init host` — [init-host.md](init-host.md)
- `init onboarding` — [init-onboarding.md](init-onboarding.md)
- `init permissions` — [init-permissions.md](init-permissions.md)

## Kullanim

```bash
./plume.sh init shell
./plume.sh init host
./plume.sh init onboarding
./plume.sh init permissions --open
./plume.sh init shell --shell=zsh
./plume.sh init shell --shell=bash
./plume.sh init shell --rc=$HOME/.zshrc --force
```

## Parametreler

- `shell`
  - `--shell=zsh|bash`: hedef shell tipi
  - `--rc=/abs/path`: custom rc dosyasi
  - `--force`: mevcut plume bloğunu silip yeniden yazar

## Davranis

- `php shim install` otomatik calisir.
- Shell rc dosyasina su blok eklenir:
  - `# >>> plume php shim >>>`
  - `eval "$(<plume-exec> php shim env)"`
  - `# <<< plume php shim <<<`
- Bu sayede her shell acilisinda:
  - shim `PATH` aktivasyonu
  - default disi kurulu PHP versiyonlari icin `php81`, `php82`, `phpfpm81` gibi aliaslar
  otomatik yuklenir.
- Tekrar calistirilirsa duplicate yazmaz (idempotent).

## Cikti / Exit Codes

- `0`: basarili
- `2`: invalid option/shell veya yazma hatasi

## Ornekler

```bash
./plume.sh php install 8.4
./plume.sh init shell --shell=zsh
source ~/.zshrc
php8.4 -v
```

## Hata Senaryolari

- Desteklenmeyen shell (`fish`, vb.)
- RC dosyasina yazma izni olmamasi
- plume executable cozumlenememesi
