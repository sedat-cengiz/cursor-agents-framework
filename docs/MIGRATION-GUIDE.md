# Goc Rehberi — jeager-agents v1/v2'den Framework v3'e

Bu rehber, mevcut `jeager-agents` v1 veya v2 kurulumunu `cursor-agents-framework` v3'e yukseltme adimlarini anlatir.

## Ne Degisti?

| Konu | Eski (v1/v2) | Yeni (v3) |
|------|-------------|-----------|
| Isim | `jeager-agents` | `cursor-agents-framework` |
| Yapi | Tek klasor, proje-ozel | 5 katmanli modular framework |
| Core kurallar | Proje sabitleri gomulu | Jenerik; sabitler manifest veya `project-*.mdc` ile |
| Teknoloji | Sabit (.NET + React) | Plug-in paketler (Python, Go, Java vb. eklenebilir) |
| Domain | Sabit (WMS) | Plug-in domain paketleri (WMS, E-Commerce, ozel) |
| Konfigurasyon | Yok | `agents.manifest.json` + schema |
| Kurulum | Manuel | Script (PowerShell, Bash) veya Cursor chat |

## v1'den v3'e Goc

v1'de 13 adet `agent-*.mdc` dosyasi bulunuyordu (her agent icin ayri dosya). v3'te bu dosyalar katmanli yapiya donustu.

### Adimlar

1. **Yedek alin:** `.cursor/rules/` klasorunun tamami ve `docs/agents/` klasoru
2. **Eski agent dosyalarini silin:** `agent-ba.mdc`, `agent-architect.mdc`, `agent-backend.mdc`, vb.
3. **Framework'u kurun:** [GETTING-STARTED.md](GETTING-STARTED.md) adimlarini izleyin
4. **Proje sabitlerini tasiyun:** Eski `global-conventions.mdc` icindeki proje-ozel bilgileri (port, tenant ID vb.) yeni `project-{name}.mdc` dosyasina aktarin
5. **docs/agents/ icerigini koruyun:** Mevcut taskboard, requirements, decisions, handoffs oldugu gibi kalir

### Dosya Eslemesi (v1 → v3)

| Eski Dosya (v1) | Yeni Dosya (v3) | Katman |
|------------------|------------------|--------|
| `agent-ba.mdc` | `process-analysis.mdc` | Process |
| `agent-architect.mdc` | `process-architecture.mdc` | Process |
| `agent-backend.mdc` | `tech-dotnet.mdc` | Technology |
| `agent-frontend.mdc` | `tech-react.mdc` | Technology |
| `agent-mobile.mdc` | `tech-maui.mdc` | Technology |
| `agent-db.mdc` | `tech-sql-server.mdc` | Technology |
| `agent-qa.mdc` | `tech-testing.mdc` | Technology |
| `agent-security.mdc` | `tech-security.mdc` | Technology |
| `agent-devops.mdc` | `tech-devops.mdc` | Technology |
| `agent-ai-ml.mdc` | `tech-ai-ml.mdc` | Technology |
| `agent-review.mdc` | `code-quality.mdc` | Core |
| `agent-pm.mdc` | `orchestrator.mdc` | Core |
| `agent-docs.mdc` | `process-documentation.mdc` | Process |
| `global-conventions.mdc` | `global-conventions.mdc` (jenerik) + `project-{name}.mdc` | Core + Proje |
| `agent-learning.mdc` | `agent-learning.mdc` | Learning |

## v2'den v3'e Goc

v2 zaten katmanli yapiya sahipti (core, technology, process, domain, learning). v3 ile buyuk olcude uyumludur.

### Adimlar

1. **Core dosyalari guncelleyin:** `core/` altindaki 3 dosyayi v3 surumleriile degistirin. v3'te proje-ozel sabitler cikarilmistir; jenerik surumleri kullanin.
2. **`agents.manifest.json` ekleyin:** Proje root'una manifest dosyasi olusturun. Mevcut teknoloji ve domain secimlerinizi burada tanimlayin.
3. **Teknoloji paketlerini kontrol edin:** v3'te paketler genisletilmis olabilir. Mevcut `tech-*.mdc` dosyalarinizi v3 surumleriyle karsilastirin ve isterseniz guncelleyin.
4. **Proje-ozel override'lari koruyun:** `project-{name}.mdc` dosyaniz zaten varsa oldugu gibi kalir. Yoksa proje sabitlerini buraya tasimasi onerilen bir adimdir.
5. **Domain paketlerini kontrol edin:** v3'te yeni domain paketleri (orn. ecommerce) eklenmis olabilir. Mevcut domain dosyalariniz gecerli kalir.

### Korumaniz Gerekenler

Bu dosya ve klasorler goc sirasinda degistirilmemeli, oldugu gibi kalir:

- `docs/agents/` altindaki tum icerik (taskboard, requirements, decisions, handoffs, reviews)
- `docs/agents/lessons-learned.md` — birikimli ogrenme verisi
- `project-{name}.mdc` — proje-ozel override'lar
- `AGENTS.md` — proje root'undaki giris noktasi

## Dogrulama

Goc sonrasi:

1. Cursor'u acin, `@sef` yazin — orkestrator aktif olmali
2. `.cursor/rules/` altinda v1/v2 kalintilarinin olmadigini dogrulayin
3. `agents.manifest.json` gecerli JSON ve schema'ya uygun olmali
4. Mevcut taskboard ve workflow-state bozulmamis olmali
