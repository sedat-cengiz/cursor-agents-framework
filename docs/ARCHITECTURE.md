# Framework Mimarisi

## Katman Modeli

Framework 5 bagimsiz katmandan olusur. Her katman kendi sorumluluk alanina sahiptir ve bagimsiz olarak eklenip cikarilabilir (Core, Process ve Learning her zaman yuklenir).

```
┌─────────────────────────────────────────────────┐
│  Layer 5: LEARNING (priority: 5)                │
│  Surekli ogrenme, bilgi birikimi, kural evrimi  │
├─────────────────────────────────────────────────┤
│  Layer 4: DOMAIN (priority: 60)                 │
│  WMS, E-Commerce, ERP, ... (plug-in)            │
├─────────────────────────────────────────────────┤
│  Layer 3: PROCESS (priority: 50)                │
│  BA, Architect, Documentation                   │
├─────────────────────────────────────────────────┤
│  Layer 2: TECHNOLOGY (priority: 40-100)         │
│  .NET, React, Python, DevOps, ... (plug-in)     │
├─────────────────────────────────────────────────┤
│  Layer 1: CORE (priority: 10-20)                │
│  Conventions, Orchestrator, Code Quality        │
└─────────────────────────────────────────────────┘
```

## Katman Detaylari

### Layer 1: CORE (Her Zaman Yuklenir)

Projenin genelini yoneten, teknoloji ve domain'den bagimsiz temel kurallar.

| Dosya | Priority | alwaysApply | Icerik |
|-------|----------|-------------|--------|
| `global-conventions.mdc` | 10 | true | Proje bilgileri, dil kurallari, API standartlari, performans hedefleri, guvenlik temelleri, agent iletisim protokolu, altin kurallar |
| `orchestrator.mdc` | 15 | true | Proje yoneticisi rolu, RACI matrisi, risk matrisi, sprint planlama, DoD, escalation, agent yonlendirme tablosu |
| `code-quality.mdc` | 20 | true | 360 derece code review, complexity metrikleri, code smell katalog, PR checklists, breaking change detection |

### Layer 2: TECHNOLOGY (Secmeli — Plug-in)

Projenin kullandigi teknoloji yiginina gore secilir. Her dosya bir "world-class expert" agent tanimlar.

| Dosya | Priority | Glob Pattern | Uzmanlik |
|-------|----------|--------------|----------|
| `tech-dotnet.mdc` | 40 | `**/*.cs`, `**/*.csproj` | .NET, ASP.NET Core, EF Core, CQRS, Clean Architecture |
| `tech-react.mdc` | 40 | `**/*.tsx`, `**/*.ts` (src/) | React, TypeScript, Vite, TanStack Query, Zustand |
| `tech-python.mdc` | 40 | `**/*.py` | Python, FastAPI/Django, SQLAlchemy, async |
| `tech-sql-server.mdc` | 40 | `**/*.sql`, `**/Migrations/**` | SQL Server, schema, index, query optimization |
| `tech-maui.mdc` | 40 | `**/*.xaml`, `**/Platforms/**` | .NET MAUI, Blazor Hybrid, MVVM, offline |
| `tech-ai-ml.mdc` | 40 | `**/*ML*`, `**/*Semantic*` | ML.NET, Semantic Kernel, RAG, MLOps |
| `tech-devops.mdc` | 40 | `**/Dockerfile`, `**/*.yml` (CI) | Docker, CI/CD, SRE, observability |
| `tech-security.mdc` | **100** | `**/*Auth*`, `**/*Security*` | OWASP, JWT, OAuth, Zero Trust |
| `tech-testing.mdc` | 40 | `**/tests/**`, `**/*.test.*` | xUnit/pytest, Playwright, TDD/BDD |

**Priority 100** olan `tech-security` en yuksek onceliklidir; guvenlik kurallarinin diger kurallari override etmesini saglar.

### Layer 3: PROCESS (Her Zaman Yuklenir)

Teknolojiden bagimsiz surec rolleri.

| Dosya | Priority | Icerik |
|-------|----------|--------|
| `process-analysis.mdc` | 50 | Is Analisti: user story, INVEST, kabul kriterleri, story splitting |
| `process-architecture.mdc` | 50 | Cozum Mimari: ADR, API kontrat, C4 model, DDD, distributed patterns |
| `process-documentation.mdc` | 50 | Surec Dokumantasyonu: BPMN 2.0, SOP, Lean Six Sigma, KPI |

### Layer 4: DOMAIN (Secmeli — Plug-in)

Is alanina ozgu bilgi paketleri. Birden fazla domain pack secilir.

| Pack | Dosyalar | Icerik |
|------|----------|--------|
| `wms/` | 3 dosya (concepts, processes, integrations) | Depo yonetimi: entity, surec, entegrasyon |
| `ecommerce/` | 2 dosya (concepts, processes) | E-ticaret: siparis, odeme, kargo, iade |
| `_template/` | 1 sablon | Yeni domain pack olusturma rehberi |

### Layer 5: LEARNING (Her Zaman Yuklenir)

| Dosya | Priority | Icerik |
|-------|----------|--------|
| `agent-learning.mdc` | **5** | Ogrenme tetikleyicileri, kayit formati, kural evrimi, bilgi okuma protokolu |
| `knowledge-base/lessons-learned.md` | — | Tum projelerden biriken evrensel dersler |
| `knowledge-base/evolution-log.md` | — | Kural degisikliklerinin versiyon gecmisi |

**Priority 5** ile en dusuk onceliktedir; diger tum kurallardan once yuklenir ve ogrenme bağlamını hazirlar.

## Priority Sistemi

Cursor `.mdc` dosyalarini `priority` degerine gore isler. Dusuk deger = once yuklenir, yuksek deger = son soz.

```
5    → Learning (ogrenme baglami hazirla)
10   → Core: global-conventions (temel standartlar)
15   → Core: orchestrator (gorev koordinasyonu)
20   → Core: code-quality (review standartlari)
40   → Technology (teknoloji-ozel kurallar)
50   → Process (surec kurallari)
60   → Domain (domain bilgisi)
100  → Security (guvenlik — en yuksek, override eder)
```

## alwaysApply vs Glob-Scoped

| Mod | Davranis | Katmanlar |
|-----|----------|-----------|
| `alwaysApply: true` | Her sohbette yuklenir | Core (3), Process (3), Learning (1) |
| `globs: [...]` | Sadece eslesen dosyalar acikken yuklenir | Technology (8), Domain (5+) |

## Dosya Iliskileri

```
agents.manifest.json  ─── Proje: hangi paketler aktif?
        │
        ├── .cursor/rules/
        │   ├── global-conventions.mdc  ← Core (proje bilgileriyle doldurulmus)
        │   ├── orchestrator.mdc        ← Core
        │   ├── code-quality.mdc        ← Core
        │   ├── tech-dotnet.mdc         ← Technology (secilmis)
        │   ├── tech-react.mdc          ← Technology (secilmis)
        │   ├── process-*.mdc           ← Process
        │   ├── domain-wms-*.mdc        ← Domain (secilmis)
        │   ├── agent-learning.mdc      ← Learning
        │   └── project-{name}.mdc      ← Proje-ozel overrides (opsiyonel)
        │
        └── docs/agents/
            ├── agent-guide.md          ← Agent sistem giris noktasi
            ├── taskboard.md            ← Aktif gorev tablosu
            ├── workflow-state.md        ← Proje durumu
            ├── lessons-learned.md       ← Proje ogrenme gunlugu
            ├── proje-sabitleri.md       ← Proje sabitleri (port, tenant ID, vb.)
            ├── requirements/            ← User story'ler
            ├── decisions/               ← ADR'ler
            ├── contracts/               ← API kontratlari
            ├── handoffs/                ← Agent devir notlari
            └── reviews/                 ← Code review raporlari
```

## Surec ve Orkestrasyon Eslesmesi

Framework orkestrasyonu (kalite kapilari + agent adimlari) ile surec dokumantasyonu (BPMN/SOP) tek bir referansla eslestirilebilir. Denetim veya uyumluluk raporu icin asagidaki tablo kullanilir.

| Orkestrasyon Adimi | Kalite Kapisi | BPMN Karsiligi | Surec Dokumani Referansi |
|--------------------|---------------|----------------|--------------------------|
| Kullanici istegi al | — | Start Event (Message) | process-documentation.mdc: BPMN Start |
| Analiz, siniflandirma | G1 Analiz | Task (User: Sef) | SOP: Is kabulu, kapsam belirleme |
| US / kabul kriterleri | G2 Kabul | Task (User: Analist) | process-analysis.mdc: US, INVEST |
| Mimari / ADR / kontrat | G3 Mimari | Task (User: Mimari) | process-architecture.mdc: ADR, kontrat |
| Backend gelistirme | G4 Uygulama | Task (Service: Backend) | tech-* backend pack |
| Frontend gelistirme | G4 Uygulama | Task (Service: Frontend) | tech-* frontend pack |
| backend ∥ frontend | G4 Uygulama | Parallel Gateway (AND) → 2 Task | orchestration-policies: Paralel adim |
| Test yazimi / calistirma | G5 Test | Task (Service: QA) | tech-testing.mdc |
| Code review | G6 Review | Task (User: Review) | code-quality.mdc |
| DoD onay, yayin | G7 Yayin | Task (User: Sef + Kullanici) | orchestrator.mdc: Final ozet |
| Final ozet kullaniciya | — | End Event | — |

**Kullanim:** Proje `docs/processes/` veya `docs/sop/` altinda BPMN/SOP tutuyorsa, yukaridaki adimlari ayni isimle veya referans numarasi ile eslestir. CMMI/ISO surec uyumlulugu icin "orkestrasyon adimi X = SOP-Y Adim Z" seklinde matris olusturulabilir.

---

## Tasarim Prensipleri

1. **Separation of Concerns**: Her katman kendi sorumluluk alanina sahip; katmanlar arasi bagimlilik minimal.
2. **Open/Closed**: Framework core'u degistirmeden yeni technology ve domain pack'ler eklenebilir.
3. **Convention over Configuration**: Makul varsayilanlar; sadece farkli olan yapilandirilir.
4. **Progressive Disclosure**: Basit projelerde sadece Core + bir tech pack yeterli; karmasik projeler tum katmanlari kullanir.
5. **Single Source of Truth**: Master kurallar framework repo'sunda; projelere kopyalanir, proje-ozel farklar ayri dosyada tutulur.
