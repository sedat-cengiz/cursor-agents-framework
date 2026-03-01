# Yapilandirma Rehberi

## agents.manifest.json

Her projede root dizinde `agents.manifest.json` dosyasi bulunur. Bu dosya projenin hangi agent paketlerini kullandigini ve proje-ozel ayarlarini tanimlar.

### Minimal Ornek

```json
{
  "projectName": "MyApp",
  "platform": "Internal HR Portal",
  "layers": {
    "technology": ["dotnet", "react", "sql-server", "testing"]
  }
}
```

### Tam Ornek

```json
{
  "$schema": "./node_modules/cursor-agents-framework/agents.manifest.schema.json",
  "frameworkVersion": "3.0.0",
  "projectName": "JeagerWMS",
  "platform": "Multi-tenant SaaS Depo Yonetim Sistemi",
  "architecturePhilosophy": "Simple things should be simple, complex things should be possible.",
  "language": {
    "communication": "tr",
    "code": "en",
    "docs": "tr",
    "commits": "en"
  },
  "layers": {
    "technology": ["dotnet", "react", "sql-server", "maui", "devops", "security", "testing", "ai-ml"],
    "domain": ["wms"]
  },
  "technologyStack": {
    "backend": ".NET 9 Web API, Clean Architecture (DDD), EF Core 9, MediatR (CQRS)",
    "frontend": "React 19 + TypeScript 5.x + Vite 6, Ant Design 5, TanStack Query v5, Zustand",
    "mobile": ".NET MAUI 9, CommunityToolkit.Mvvm, SQLite (offline)",
    "database": "SQL Server 2022 (multi-tenant: shared DB + TenantId)",
    "cache": "Redis 7+",
    "messageBroker": "RabbitMQ + MassTransit",
    "auth": "ASP.NET Identity + JWT + Refresh Token",
    "test": "xUnit, Moq, Testcontainers, Playwright, Vitest",
    "observability": "Serilog + Seq + OpenTelemetry"
  },
  "aliases": {
    "backend": "tech-dotnet",
    "frontend": "tech-react",
    "db": "tech-sql-server"
  },
  "performanceTargets": {
    "apiResponseP50Ms": 200,
    "apiResponseP95Ms": 500,
    "frontendFcpSec": 2.5,
    "frontendBundleKb": 500
  },
  "sprintConfig": {
    "durationDays": 10,
    "capacityPercent": 80,
    "pointScale": "fibonacci"
  }
}
```

### Alan Aciklamalari

| Alan | Zorunlu | Aciklama |
|------|---------|----------|
| `projectName` | Evet | Proje adi; global-conventions'daki {{PROJE_ADI}}'yi doldurur |
| `platform` | Evet | Platform tanimi; {{PLATFORM_TANIMI}}'yi doldurur |
| `language` | Hayir | Dil tercihleri (varsayilan: communication=tr, code=en) |
| `layers.technology` | Evet | Aktif teknoloji paketleri listesi |
| `layers.domain` | Hayir | Aktif domain paketleri (bos birakilabilir) |
| `technologyStack` | Hayir | Detayli stack aciklamasi (tech pack varsayilanlarini override eder) |
| `aliases` | Hayir | Ozel takma ad eslesmesi (varsayilanlar install script'te tanimli) |
| `performanceTargets` | Hayir | Proje-ozel performans hedefleri |
| `sprintConfig` | Hayir | Sprint ayarlari |

## global-conventions.mdc Yapilandirmasi

Kurulum sirasinda `global-conventions.mdc` projede kopyalanir. Asagidaki placeholder'lar manifest'ten doldurulur:

| Placeholder | Kaynak |
|-------------|--------|
| `{{PROJE_ADI}}` | `projectName` |
| `{{PLATFORM_TANIMI}}` | `platform` |
| `{{TECHNOLOGY_STACK}}` | `technologyStack` blogu (veya tech pack listesinden otomatik olusturulur) |
| `{{ILETISIM_DILI}}` | `language.communication` |
| `{{DOKUMAN_DILI}}` | `language.docs` |

## Override Mekanizmasi

Proje-ozel kurallar icin `.cursor/rules/project-{name}.mdc` dosyasi olusturulur. Bu dosya:
- `alwaysApply: true` ve yuksek priority (ornegin 25) ile core kurallari genisletir
- Proje sabitleri (port, tenant ID, ozel konvansiyonlar) icerir
- Framework kurallarini degistirmez; ek kurallar ekler

```mdc
---
description: "Proje ozelinde kurallar ve sabitler"
alwaysApply: true
priority: 25
---

# Proje: MyApp — Proje-Ozel Kurallar

## Proje Sabitleri
- Dev Tenant ID: 00000000-0000-0000-0000-000000000001
- API Portlari: Auth=5001, Core=5002, ...

## Proje-Ozel Naming
- ...
```

## Dogrulama

`agents.manifest.schema.json` ile manifest dosyasi IDE'de (VS Code, Cursor) otomatik dogrulanir. `$schema` alanini ekleyerek IntelliSense ve hata gosteriminden faydalanin.
