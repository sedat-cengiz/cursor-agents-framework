# Yeni Domain Pack Olusturma

Bu rehber, framework'e yeni bir domain (is alani) bilgi paketi eklemeyi anlatir.

## Ne Zaman Gerekir?

Asagidakilerden biri veya birkaci projeniz icin gecerliyse yeni bir domain pack olusturmaniz gerekir:

- **Domain-ozel terimler** var (orn. saglik: "hasta", "randevu", "reçete")
- **Domain-ozel is kurallari** var (orn. finans: "T+2 settlement", "KYC kontrol")
- **Domain-ozel surecler** var (orn. lojistik: "sevk planlama", "rota optimizasyonu")
- Mevcut domain paketleri (`wms`, `ecommerce`) projenize uymuyor

## Klasor Yapisi

Her domain pack `domains/{name}/` altinda bulunur:

```
domains/
├── healthcare/                      ← Yeni domain pack
│   ├── domain-healthcare-concepts.mdc     (zorunlu)
│   ├── domain-healthcare-processes.mdc    (opsiyonel)
│   └── domain-healthcare-integrations.mdc (opsiyonel)
├── wms/                             ← Mevcut ornek
├── ecommerce/                       ← Mevcut ornek
└── _template/                       ← Sablon
    └── domain-template.mdc
```

### Dosya Rolleri

| Dosya | Amac | Zorunlu? |
|-------|------|----------|
| `domain-{name}-concepts.mdc` | Terimler, entity'ler, roller, is kurallari, status akislari | Evet |
| `domain-{name}-processes.mdc` | Surec akislari, adim-adim islemler, edge case'ler | Hayir |
| `domain-{name}-integrations.mdc` | Dis sistem entegrasyonlari, protokoller, veri alisi | Hayir |

## Olusturma Adimlari

### 1. Sablonu Kopyalayin

```bash
cp domains/_template/domain-template.mdc domains/healthcare/domain-healthcare-concepts.mdc
```

### 2. Sablonu Doldurun

Sablon icindeki her bolumu domain'inize gore doldurun:

- **Domain Tanimi:** Kisa ozet (1-2 cumle)
- **Terimler Sozlugu:** Her domain teriminin Turkce/Ingilizce karsiligi ve tanimi
- **Core Entity'ler:** Ana varliklar, temel property'leri, birbirleriyle iliskileri
- **Kullanici Rolleri:** Kimlerin hangi yetkilere sahip oldugu
- **Is Kurallari:** "X oldugunda Y olmali, Z hariç" formatinda somut kurallar
- **Status Akislari:** Her entity'nin durum gecis diyagrami
- **Edge Case'ler:** Istisnai durumlar ve nasil handle edilecegi

### 3. Frontmatter'i Ayarlayin

Her `.mdc` dosyasinin basinda uygun metadata olmali:

```yaml
---
description: "Domain: Healthcare — Saglik sektoru kavramlari ve is kurallari"
globs:
alwaysApply: false
priority: 60
---
```

- `priority: 60` tum domain paketleri icin standarttir
- `globs` bos birakilir veya domain'e ozel dosya kaliplari eklenir
- `alwaysApply: false` — domain bilgisi sadece ilgili dosyalar acikken yuklenir

### 4. (Opsiyonel) Ek Dosyalar Ekleyin

Icerik buyurse processes ve integrations dosyalarini ayri olusturun. Ayni frontmatter yapisini kullanin.

### 5. Framework'e Kaydedin

- `domains/{name}/` klasorunu framework repo'suna ekleyin
- Install script'lerin bu domain'i taniyabilmesi icin ek bir islem gerekmez; script `domains/` altindaki tum klasorleri otomatik listeler
- `SKILL.md` dosyasindaki Layer 4 bolumune yeni domain'i ekleyin

## En Iyi Pratikler

1. **Terimler sozlugu kapsamli olsun:** Agent'lar bu sozlugu domain terimlerini anlamak icin kullanir. Her terimin net bir tanimi olmali.
2. **Entity iliskilerini gorsellestirin:** Basit metin diyagramlari (`A 1---* B`) agent'larin veri modelini anlamasini saglar.
3. **Status lifecycle'larini tanimlayin:** Her entity'nin hangi durumlardan gecebildigi, hangi gecislerin gecerli/gecersiz oldugu belirtilmeli.
4. **Edge case'leri somutlastirin:** "Dikkatli ol" degil, "X durumunda Y yap, Z durumunda hata don" formatinda yazin.
5. **Is kurallarini kural formatinda yazin:** Kosul → Sonuc → Istisna sablonu kullanin.
6. **Entegrasyonlarda protokol belirtin:** API mi, dosya mi, event mi? Format, frekans ve hata yonetimi net olmali.
7. **Mevcut domain paketlerini referans alin:** `domains/wms/` ve `domains/ecommerce/` orneklerine bakin.
