# Yeni Proje Kurulumu — Adim Adim

Bu rehber, Cursor Agents Framework'u sifirdan bir projeye kurarken izlenmesi gereken tum adimlari detayli olarak anlatir.

> Hizli baslangic icin: [GETTING-STARTED.md](GETTING-STARTED.md)

## On Kosul

Framework'un `~/.cursor/skills/cursor-agents-framework/` altinda veya baska bir dizinde mevcut oldugunu varsayiyoruz. Yoksa once [GETTING-STARTED.md](GETTING-STARTED.md#kurulum-yontemleri) adimlarini tamamlayin.

---

## Adim 1: agents.manifest.json Olusturun

Proje root dizininde `agents.manifest.json` dosyasi olusturun. Bu dosya projenizin hangi teknoloji ve domain paketlerini kullanacagini tanimlar.

```json
{
  "frameworkVersion": "3.0.0",
  "projectName": "MyApp",
  "platform": "Multi-tenant SaaS E-Commerce Platform",
  "language": {
    "communication": "tr",
    "code": "en",
    "docs": "tr",
    "commits": "en"
  },
  "layers": {
    "technology": ["dotnet", "react", "sql-server", "testing", "security"],
    "domain": ["ecommerce"]
  },
  "aliases": {
    "backend": "tech-dotnet",
    "frontend": "tech-react"
  }
}
```

Mevcut teknoloji paketleri: `dotnet`, `react`, `python`, `sql-server`, `maui`, `ai-ml`, `devops`, `security`, `testing`. Mevcut domain paketleri: `wms`, `ecommerce`.

> Manifest opsiyoneldir. Olmadan da install script'i interaktif modda calisir.

## Adim 2: Install Script'i Calistirin

```powershell
# PowerShell (Windows)
.\scripts\install.ps1 -ProjectPath "D:\MyProject"

# Bash (macOS / Linux)
./scripts/install.sh ~/my-project

# Manuel kurulum (script kullanamayanlar icin)
# 1. .cursor/rules/ klasoru olusturun
# 2. core/*.mdc dosyalarini kopyalayin
# 3. Sectiginiz technology/tech-*.mdc dosyalarini kopyalayin
# 4. process/*.mdc dosyalarini kopyalayin
# 5. Sectiginiz domains/{domain}/*.mdc dosyalarini kopyalayin
# 6. learning/agent-learning.mdc dosyasini kopyalayin
```

Script 6 adim uygular: Core → Technology → Process → Domain → Learning + docs → Aliases.

## Adim 3: global-conventions.mdc Yapilandirin

Projenizin `.cursor/rules/global-conventions.mdc` dosyasini acin. Asagidaki alanlari projenize gore doldurun:

| Placeholder | Ne Yazilmali | Ornek |
|-------------|-------------|-------|
| Proje Adi | Projenizin adi | `MyApp` |
| Platform | Platform tanimi | `Multi-tenant SaaS E-Commerce` |
| Teknoloji Stack | Backend, frontend, DB vb. | `.NET 9, React 19, SQL Server 2022` |
| Dil Kurallari | Iletisim ve kod dili tercihi | Turkce iletisim, Ingilizce kod |

Manifest varsa install script bu alanlarin cogunlugunu otomatik doldurur.

## Adim 4: (Opsiyonel) Proje-Ozel Kural Dosyasi Olusturun

Projenize ozel sabitler ve kurallar icin `.cursor/rules/project-{name}.mdc` dosyasi olusturun:

```yaml
---
description: "Proje ozelinde kurallar ve sabitler"
alwaysApply: true
priority: 25
---
```

Bu dosyada proje portlari, dev tenant ID, ozel naming convention'lar gibi proje-ozel bilgiler tutulur. Framework kurallarini degistirmez, ustune ekler.

## Adim 5: AGENTS.md Giris Noktasini Olusturun

Proje root dizinine `AGENTS.md` dosyasi ekleyin. Bu dosya Cursor'un agent sisteminin giris noktasidir:

```markdown
# Agent Sistemi

Bu proje coklu agent (Cursor rules) ile gelistirilir.

**Baslangic:** [docs/agents/agent-guide.md](docs/agents/agent-guide.md)
```

## Adim 6: docs/agents/ Yapisini Dogrulayin

Install script asagidaki yapinin tamamini olusturur. Manuel kurulumda bu klasorleri kendiniz yaratmaniz gerekir:

```
docs/agents/
├── taskboard.md           ← Gorev tablosu
├── workflow-state.md      ← Proje durumu
├── lessons-learned.md     ← Ogrenme gunlugu
├── requirements/          ← User story'ler
├── decisions/             ← ADR (Architecture Decision Records)
├── contracts/             ← API kontratlari
├── handoffs/              ← Agent devir notlari
└── reviews/               ← Code review raporlari
```

## Adim 7: Dogrulama

Projeyi Cursor'da acin ve asagidakileri kontrol edin:

1. Cursor chat'te `@sef` yazin — orkestrator agent'inin aktif oldugunu gorun
2. `.cursor/rules/` altinda kurallar mevcut olmali
3. `docs/agents/` altinda taskboard ve diger dosyalar olmali

---

## Kurulum Sonrasi Kontrol Listesi

Asagidaki her maddenin var oldugunu dogrulayin:

- [ ] `.cursor/rules/global-conventions.mdc` — proje bilgileri dolu
- [ ] `.cursor/rules/orchestrator.mdc` — mevcut
- [ ] `.cursor/rules/code-quality.mdc` — mevcut
- [ ] `.cursor/rules/tech-*.mdc` — secilen teknoloji paketleri
- [ ] `.cursor/rules/process-*.mdc` — surec kurallari (3 dosya)
- [ ] `.cursor/rules/agent-learning.mdc` — ogrenme sistemi
- [ ] `.cursor/rules/domain-*.mdc` — secilen domain paketleri (varsa)
- [ ] `agents.manifest.json` — proje root'unda (opsiyonel ama onerilen)
- [ ] `AGENTS.md` — proje root'unda
- [ ] `docs/agents/taskboard.md` — gorev tablosu
- [ ] `docs/agents/workflow-state.md` — workflow durumu
- [ ] `docs/agents/lessons-learned.md` — ogrenme gunlugu
- [ ] `docs/agents/requirements/` — klasor mevcut
- [ ] `docs/agents/decisions/` — klasor mevcut
- [ ] `docs/agents/contracts/` — klasor mevcut
- [ ] `docs/agents/handoffs/` — klasor mevcut

Her sey hazirsa Cursor chat'te `@sef` ile ilk gorevinizi tanimlayin.
