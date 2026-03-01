# API Kontrati: {{RESOURCE_ADI}}

**Tarih:** YYYY-MM-DD
**Versiyon:** v1
**Durum:** Taslak | Onaylandi | Uygulanmis
**Ilgili ADR:** ADR-XXX
**Ilgili US:** US-XXX

## Resource

- **Base URL:** `/api/v1/{{resource-name}}`
- **Auth:** Bearer JWT + `[RequirePermission("{{Permission}}")]`
- **Multi-tenant:** TenantId header'dan veya token claim'den

## Endpoint Tablosu

| Method | Endpoint | Aciklama | Auth | Puan |
|--------|----------|----------|------|------|
| GET | `/` | Listele (paged) | Evet | - |
| GET | `/{id}` | Detay getir | Evet | - |
| POST | `/` | Yeni olustur | Evet | - |
| PUT | `/{id}` | Guncelle | Evet | - |
| DELETE | `/{id}` | Sil (soft) | Evet | - |

## Request / Response

### POST `/api/v1/{{resource-name}}`

**Request Body:**

```json
{
  "field1": "string (required, max 200)",
  "field2": 0,
  "field3": "2025-01-01T00:00:00Z"
}
```

**Response 201:**

```json
{
  "isSuccess": true,
  "message": "Created successfully",
  "data": {
    "id": "guid",
    "field1": "string",
    "field2": 0,
    "createdAt": "2025-01-01T00:00:00Z"
  }
}
```

### GET `/api/v1/{{resource-name}}?page=1&pageSize=20`

**Response 200:**

```json
{
  "isSuccess": true,
  "data": {
    "items": [],
    "totalCount": 0,
    "page": 1,
    "pageSize": 20
  }
}
```

## Hata Kodlari

| HTTP | Kod | Aciklama | Ne Zaman |
|------|-----|----------|----------|
| 400 | VALIDATION_ERROR | Gecersiz input | FluentValidation fail |
| 401 | UNAUTHORIZED | Token yok/gecersiz | Auth middleware |
| 403 | FORBIDDEN | Yetki yok | Permission check |
| 404 | NOT_FOUND | Kayit bulunamadi | Entity yok |
| 409 | DUPLICATE | Ayni kayit var | Unique constraint |
| 422 | BUSINESS_RULE | Is kurali ihlali | Domain validation |

## Notlar

<!-- Ozel davranislar, idempotency, cache, rate limit -->
