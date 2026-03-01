# Agent Rehberi — {{PROJE_ADI}}

> Bu proje **Cursor Agents Framework v3.0** kullanir.

## Rol / Kural Eslemesi

| Rol | Kural Dosyasi (.mdc) | Alias | Aciklama |
|-----|----------------------|-------|----------|
| Proje Yoneticisi | orchestrator.mdc | @sef | Koordinasyon, gorev dagitimi, risk yonetimi |
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

> Alias'lar Cursor chat'te `@sef`, `@backend` seklinde kullanilir.

## Iletisim Dosyalari

| Dosya | Yol | Amac |
|-------|-----|------|
| Taskboard | `docs/agents/taskboard.md` | Gorev tablosu (BACKLOG → DONE) |
| Workflow State | `docs/agents/workflow-state.md` | Aktif faz ve adim durumu |
| Requirements | `docs/agents/requirements/` | User story'ler (US-*.md) |
| Decisions | `docs/agents/decisions/` | ADR'ler (ADR-*.md) |
| Contracts | `docs/agents/contracts/` | API kontratlari |
| Handoffs | `docs/agents/handoffs/` | Agent arasi teslim notlari |
| Lessons Learned | `docs/agents/lessons-learned.md` | Ogrenilen dersler |

## Calisma Akisi

### @sef ile Basla

1. **Kullanici** Cursor chat'te `@sef` ile gorev verir
2. **Sef** taskboard ve workflow-state okur, mevcut durumu anlar
3. **Sef** gerekli handoff dokümanini yazar (gorev spec, DoD)
4. **Sef** ilgili agent'i cagirir (mcp_task ile)
5. **Agent** isi yapar, testleri yazar, taskboard gunceller
6. **Sef** sonucu kullaniciya ozetler

### Tipik Akis

```
Kullanici → @sef "Yeni ozellik: X"
  → Sef → @analist (US yazar)
  → Sef → @mimari (ADR + kontrat yazar)
  → Sef → @backend (kodu yazar)
  → Sef → @frontend (UI yazar)
  → Sef → @qa (testleri yazar)
  → Sef → @review (kod inceler)
  → Sef → Kullanici (ozet + demo)
```

## Klasor Yapisi

```
docs/agents/
├── agent-guide.md          ← Bu dosya (giris noktasi)
├── taskboard.md
├── workflow-state.md
├── lessons-learned.md
├── proje-sabitleri.md
├── requirements/
│   └── US-001-*.md
├── decisions/
│   └── ADR-001-*.md
├── contracts/
│   └── *-contract.md
└── handoffs/
    └── *.md
```
