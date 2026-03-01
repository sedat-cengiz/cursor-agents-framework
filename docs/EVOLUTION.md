# Evrim ve Versiyon Stratejisi

## Surekli Ogrenme Dongusu

Framework, agent'larin proje deneyimlerinden ogrendiklerini sistematik olarak biriktirir ve kurallara geri besler.

```
Proje Calismasi
    │
    ▼
Agent ogrenme kesfeder
    │
    ▼
docs/agents/lessons-learned.md (proje-ozel kayit)
    │
    ├── Projeye Ozel → proje dosyalarinda kalir
    │
    └── Evrensel → learning/knowledge-base/lessons-learned.md (global)
                    │
                    ▼ (her 5-10 evrensel ders)
               Ilgili .mdc dosyasini guncelle
                    │
                    ▼
               learning/knowledge-base/evolution-log.md (kayit)
                    │
                    ▼
               Yeni framework versiyonu (MINOR veya PATCH)
```

## Geri Bildirim Mekanizmasi

### Projeden Framework'e

1. **Agent ogrenme kaydeder:** Gorev sirasinda beklenmeyen sorun, anti-pattern, veya best practice kesfedilir.
2. **Projeye kaydedilir:** `docs/agents/lessons-learned.md` dosyasina standart formatta eklenir.
3. **Evrensel mi degerlendirmesi:** Ders sadece bu projeye mi ozgu, yoksa genel bir bilgi mi?
4. **Global'e aktarim:** Evrensel ise `learning/knowledge-base/lessons-learned.md` dosyasina eklenir.
5. **Kural evrimi:** Her 5-10 evrensel ders biriktiginde, ilgili `.mdc` kural dosyasi guncellenir (yeni anti-pattern eklenir, checklist genisletilir, karar agaci iyilestirilir).
6. **Evolution log:** Degisiklik `learning/knowledge-base/evolution-log.md` dosyasina kaydedilir.

### Framework'ten Projelere

1. **git pull:** Skill dizinindeki framework guncellenir.
2. **Proje kural guncellemesi:** Install script tekrar calistirilir (veya diff alinarak elle merge yapilir).
3. **Proje-ozel override'lar korunur:** `project-{name}.mdc` dosyalari framework guncellemesinden etkilenmez.

## Versiyon Numaralama (SemVer)

`MAJOR.MINOR.PATCH` — Ornek: `3.2.1`

| Degisiklik Turu | SemVer | Ornek |
|-----------------|--------|-------|
| Kural icerigi ekleme/iyilestirme | PATCH | code-quality'ye yeni smell ekleme |
| Yeni tech pack | MINOR | tech-python.mdc ekleme |
| Yeni domain pack | MINOR | domains/healthcare/ ekleme |
| Yeni sablon | MINOR | _template-retrospective.md ekleme |
| Manifest schema degisikligi (backward-compatible) | MINOR | Yeni opsiyonel alan ekleme |
| Core kural formati degisikligi | MAJOR | global-conventions bolum yapisi degisikligi |
| Manifest schema breaking change | MAJOR | Zorunlu alan ekleme |
| Kural silme veya yeniden adlandirma | MAJOR | orchestrator.mdc → pm.mdc |

## CHANGELOG Formati

```markdown
# Changelog

## [3.1.0] - 2026-XX-XX
### Added
- tech-python.mdc: Python 3.12+ / FastAPI / Django tech pack
- domains/healthcare/: Healthcare domain pack

### Changed
- code-quality.mdc: Added 3 new code smells from project feedback

### Fixed
- install.ps1: Fixed alias creation for projects without tech-maui

## [3.0.0] - 2026-03-01
### Added
- Initial framework release (extracted from jeager-agents v2)
- agents.manifest.schema.json
- Cross-platform install scripts (PowerShell, Bash, Batch)
- Technology pack template
- 9 documentation guides
```

## Kalite ve Dogrulama

### Dogfooding

Framework'un kendisi de ayni agent sistemini kullanir:
- `docs/agents/` dizini frameworkte bulunur (ogrenme kayitlari icin)
- Framework gelistirme gorevleri taskboard'da takip edilir
- Yeni tech/domain pack PR'lari code review'dan gecer

### Test Senaryolari

Her yeni versiyon icin asagidaki senaryolar dogrulanir:

1. **Temiz kurulum:** Bos bir dizine install script ile kurulum → tum katmanlar dogru kopyalanir
2. **Manifest-driven kurulum:** Mevcut agents.manifest.json ile kurulum → sadece belirtilen paketler yuklenir
3. **Domain olmadan kurulum:** Domain secmeden kurulum → domain dosyalari kopyalanmaz
4. **Alias dogrulama:** Secilen tech pack'lere gore dogru alias'lar olusturulur
5. **Override korunma:** Tekrar kurulumda project-{name}.mdc dosyasi uzerine yazilmaz
6. **Cursor entegrasyonu:** Cursor'da @sef yazildiginda orchestrator kurallari aktif olur

### Ornek Projelerle Dogrulama

Framework 3 farkli stack kombinasyonuyla dogrulanmistir:

| Senaryo | Stack | Domain | Durum |
|---------|-------|--------|-------|
| .NET + React + WMS | dotnet, react, sql-server, devops, security, testing | wms | ✅ Dogrulanmis (Jeager WMS) |
| Python + Vue + E-Commerce | python, react (Vue olarak), devops, testing | ecommerce | Ornek manifest mevcut |
| .NET + React (domain yok) | dotnet, react, sql-server, testing | — | Ornek manifest mevcut |

## Katkida Bulunma

1. Fork + feature branch
2. Degisikligi yap
3. CHANGELOG.md guncelle
4. PR olustur
5. Review sonrasi merge → yeni versiyon tag'i
