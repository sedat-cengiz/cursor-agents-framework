# Hizli Baslangic

Bu rehber, Cursor Agents Framework'u indirip ilk projenize kurmak icin gereken adimlari anlatir.

## On Kosullar

- **Cursor IDE** (guncel surum) — [cursor.com](https://cursor.com)
- **Git** (git clone icin; ZIP yonteminde gerekmez)
- Bir proje klasoru (bos veya mevcut)

## Kurulum Yontemleri

### Yontem 1: Skill Olarak Kurulum (Onerilen)

Framework'u Cursor skills dizinine klonlayin. Tum projeleriniz ayni kaynagi paylasir, `git pull` ile guncellenir.

```bash
# Windows (PowerShell)
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git `
  "$env:USERPROFILE\.cursor\skills\cursor-agents-framework"

# macOS / Linux
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git \
  ~/.cursor/skills/cursor-agents-framework
```

### Yontem 2: Dogrudan Repo'dan Kullanim

Framework'u herhangi bir klasore klonlayin ve install script'i oradan calistirin.

```bash
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git
cd cursor-agents-framework
# Kurulum icin bkz. asagi
```

### Yontem 3: ZIP Indirme

GitHub Releases sayfasindan son surumu ZIP olarak indirip `~/.cursor/skills/cursor-agents-framework/` dizinine cikarin. Git gerekmez; ancak guncelleme icin tekrar indirmeniz gerekir.

## Ilk Projeyi Kurmak

### 1. Install script'i calistirin

```powershell
# PowerShell (Windows)
.\scripts\install.ps1 -ProjectPath "D:\MyProject"

# Bash (macOS / Linux)
./scripts/install.sh ~/my-project
```

Script interaktif olarak teknoloji ve domain secmenizi ister, dosyalari `.cursor/rules/` altina kopyalar ve `docs/agents/` yapisini olusturur.

> **Alternatif:** Projenize bir `agents.manifest.json` koyarsaniz script otomatik olarak onu okur ve soru sormaz. Detay: [NEW-PROJECT-SETUP.md](NEW-PROJECT-SETUP.md)

### 2. global-conventions.mdc dosyasini duzenleyin

Projenizin `.cursor/rules/global-conventions.mdc` dosyasini acin ve su alanlari doldurun:

- **Proje Adi** ve **Platform** bilgisi
- **Teknoloji Stack** (projenize uygun sekilde)
- **Dil Kurallari** (iletisim dili, dokumantasyon dili)

### 3. Cursor'da `@sef` yazarak baslayin

Cursor chat'te `@sef` yazdiginizda orkestrator agent'i aktif olur. Gorev tanimlayin; o diger agent'lari koordine eder.

Diger faydali agent alias'lari:

| Alias | Rol |
|-------|-----|
| `@sef` | Proje Yoneticisi (buradan baslayin) |
| `@backend` | Backend gelistirici |
| `@frontend` | Frontend gelistirici |
| `@qa` | Test muhendisi |
| `@review` | Kod incelemeci |
| `@mimari` | Cozum mimari |
| `@analist` | Is analisti |

## Sonraki Adimlar

- **Detayli kurulum rehberi:** [NEW-PROJECT-SETUP.md](NEW-PROJECT-SETUP.md)
- **Yapilandirma detaylari:** [CONFIGURATION.md](CONFIGURATION.md)
- **Framework mimarisi:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **Eski surumden gec:** [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)
