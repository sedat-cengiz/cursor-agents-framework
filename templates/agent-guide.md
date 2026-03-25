# Agent Rehberi — {{PROJE_ADI}}

> Bu proje **Cursor Agents Framework v4.0** kullanir.
> **Tek giris noktasi: `@sef`** — Kullanici sadece `@sef` ile calisir; diger agent'lar ic koordinasyon katmanidir.

## Nasil Calisir?

```
Kullanici → @sef "su ozelligi ekle"
  → Sef: Is siniflandirir (tur, kapsam, risk)
  → Sef: Agent hattini belirler
  → Sef: Kullanicidan onay ister
  → Sef: Kalite kapilari ile adim adim yurutur
  → Sef: Kullaniciya final ozet verir
```

Kullanici diger agent'lari dogrudan cagirmaz. `@sef` gerekli agent'lari otomatik secer, yonlendirir, state'i gunceller ve gerekiyorsa gate / failure / decision kayitlari uretir.
Runtime artik serbest metin kullanici isteginden `job_type`, `scope`, `risk_level`, etkilenen katmanlar ve onay checkpoint'leri cikarir; sonra baglama gore minimal agent set secer.

## Rol / Kural Eslemesi

| Rol | Kural Dosyasi (.mdc) | Alias | Aciklama |
|-----|----------------------|-------|----------|
| Orkestrator | orchestrator.mdc | @sef | Tek giris noktasi, siniflandirma, yonlendirme, kalite kapilari |
| Is Analisti | process-analysis.mdc | @analist | US yazimi, gereksinim analizi |
| Cozum Mimari | process-architecture.mdc | @mimari | ADR, API kontrat, DDD |
| Backend Gelistirici | tech-{{BACKEND}}.mdc | @backend | Sunucu taraf gelistirme |
| Frontend Gelistirici | tech-{{FRONTEND}}.mdc | @frontend | Istemci taraf gelistirme |
| QA Muhendisi | tech-testing.mdc | @qa | Test stratejisi ve yazimi |
| Kod Kalite | code-quality.mdc | @review | 360 derece code review |
| Guvenlik | tech-security.mdc | @guvenlik | OWASP, auth, guvenlik |
| DevOps / SRE | tech-devops.mdc | @devops | CI/CD, Docker, altyapi |
| DB Mimari | tech-{{DATABASE}}.mdc | @db | Sema, index, migration |
| Dokumantasyon | process-documentation.mdc | @dokumantasyon | BPMN, SOP |

## Orkestrasyon Akisi

### Is Turleri

| Tur | Ornek |
|-----|-------|
| `feature` | Yeni siparis modulu ekle |
| `bugfix` | Login 500 donuyor |
| `refactor` | Service katmanini ayir |
| `integration` | ERP entegrasyonu |
| `performance` | Liste sorgusu optimizasyonu |
| `ux-ui` | Dashboard yeniden tasarimi |
| `devops-infra` | Staging ortami kurulumu |
| `research` | Redis vs Memcached karsilastirmasi |

### Kalite Kapilari

Her is, turune gore belirlenen kalite kapilarindan gecer:

```
G1 Analiz → G2 Kabul → G3 Mimari → G4 Uygulama → G5 Test → G6 Review → G7 Yayin
```

Kapilar is turune gore atlanabilir (ornegin bugfix icin G1/G2/G3 atlanir). Ancak gate karari yalnizca anlatimla verilmez; evidence alanlari ve decision ref'leri ile kaydedilir.
Detay: `orchestrator.mdc` ve `orchestration-policies.mdc`. Tam ornek akislar (feature, bugfix, refactor): framework `docs/example-workflows/`.

### Enforcement Katmani

`feature`, `bugfix` ve `refactor` akislari icin `@sef` su omurga uzerinden ilerler:

- serbest metin istegi siniflandirilir (tur, kapsam, risk)
- plan ve release onaylari kullanicidan alinir
- her agent adimi icin filtrelenmis handoff yazilir
- `mcp_task` ile ilgili Cursor subagent'i baslatilir
- agent ciktisi dogrulanir
- gate evidence kontrol edilir
- workflow-state, decision log, gate report ve failure report arasinda bag kurulur
- ayni `execution_id` ile resume edilir; tamamlanmis adimlar tekrar kosulmaz

Desteklenen gercek yol:
- `feature`
- `bugfix`
- `refactor`

`scripts/run-agent.ps1` ve `docs/agents/runtime/agent-invocation.json` bu modda kullanilmaz; agent cagrisi dogrudan `mcp_task` ile yapilir.

### Ornek Akis: Yeni Ozellik (feature)

```
@sef "Siparis modulu ekle"
  ├── SINIFLANDIRMA: feature / L / orta
  ├── ONAY: Kullanicidan agent hatti onayi
  ├── @analist → US yazar → [G2 Kabul GECTI]
  ├── @mimari → ADR + kontrat yazar → [G3 Mimari GECTI]
  ├── @backend → Kodu yazar → [G4 Uygulama GECTI]
  ├── @frontend → UI yazar → [G4 Uygulama GECTI]
  ├── @qa → Testleri yazar → [G5 Test GECTI]
  ├── @review → Kod inceler → [G6 Review GECTI]
  └── OZET: Kullaniciya final rapor → [G7 Yayin ONAYI]
```

### Ornek Akis: Hata Duzeltme (bugfix)

```
@sef "Login sayfasi 500 hatasi veriyor"
  ├── SINIFLANDIRMA: bugfix / S / orta
  ├── ONAY: Kullanicidan onay
  ├── @backend → Hatayi duzeltir → [G4 Uygulama GECTI]
  ├── @qa → Regression test yazar → [G5 Test GECTI]
  ├── @review → Kod inceler → [G6 Review GECTI]
  └── OZET: Kullaniciya rapor → [G7 Yayin ONAYI]
```

## Iletisim Dosyalari

| Dosya | Yol | Amac |
|-------|-----|------|
| Workflow State | `docs/agents/workflow-state.md` | Paylasimli state — is durumu, agent hatti, degisiklikler |
| Taskboard | `docs/agents/taskboard.md` | Gorev tablosu (BACKLOG → DONE) |
| Requirements | `docs/agents/requirements/` | User story'ler (US-*.md) |
| Decisions | `docs/agents/decisions/` | ADR'ler (ADR-*.md) + Decision log (orkestrasyon kararlari) |
| Contracts | `docs/agents/contracts/` | API kontratlari |
| Handoffs | `docs/agents/handoffs/` | Agent arasi filtrelenmis teslim notlari |
| Quality Gates | `docs/agents/quality-gates/` | Gate evidence ve gate kararlari |
| Failures | `docs/agents/failures/` | Retry / escalation / hard stop kayitlari |
| State Snapshots | `docs/agents/state-snapshots/` | Checkpoint veya failure sonrasi dondurulmus state |
| Runtime Config | `docs/agents/runtime/` | Event log, evidence command map, agent invocation config |
| Lessons Learned | `docs/agents/lessons-learned.md` | Ogrenilen dersler |

### Decision Log (Orkestrasyon Kararlari)

@sef onemli operasyonel kararlari (siniflandirma, agent secimi, kapi gecisi/atlama, retry, eskalasyon, hard stop) `docs/agents/decisions/` altinda decision log formatinda kaydeder. Sablon: `templates/doc-templates/_template-decision-log.md` (framework repo'da). Mimari kararlar icin ADR (ADR-*.md), operasyonel kararlar icin decision log kullanilir.

## Klasor Yapisi

```
docs/agents/
├── agent-guide.md          ← Bu dosya (giris noktasi)
├── workflow-state.md        ← Paylasimli state (sadece @sef yazar)
├── taskboard.md
├── lessons-learned.md
├── proje-sabitleri.md
├── requirements/
│   └── US-001-*.md
├── decisions/
│   ├── ADR-001-*.md        ← Mimari kararlar (ADR)
│   └── decision-log-*.md  ← Orkestrasyon kararlari (@sef)
├── contracts/
│   └── *-contract.md
├── handoffs/
│   └── *.md
├── runtime/
│   ├── state-events.jsonl
│   ├── agent-invocation.json
│   └── evidence-command-map.json
├── quality-gates/
│   └── *.md
├── failures/
│   └── *.md
├── state-snapshots/
│   └── *.md
└── reviews/
    └── *.md
```

## Hata Yonetimi

Bir agent basarisiz olursa @sef otomatik olarak:
1. Hata turunu tespit eder
2. Workflow-state icindeki sayaclari gunceller
3. Risk seviyesine gore retry veya eskalasyon uygular
4. 3 kumulatif hata veya guvenlik riski → DURDUR
5. Gerekirse plan/release onayi veya human loop checkpoint'ine doner
6. Kullaniciya durum raporu verir

Detay: `orchestration-policies.mdc`
