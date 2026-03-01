# Yeni Technology Pack Olusturma

Bu rehber, framework'e yeni bir teknoloji bilgi paketi eklemeyi anlatir.

## Ne Zaman Gerekir?

Mevcut teknoloji paketleri (`dotnet`, `react`, `python`, `sql-server`, `maui`, `ai-ml`, `devops`, `security`, `testing`) projenizin teknoloji yiginini kapsaniyorsa yeni bir pack gerekmez.

Yeni pack olusturmaniz gereken durumlar:

- **Farkli bir dil/framework:** Go, Java/Spring, Rust, Angular, Vue, Svelte, Flutter, vb.
- **Farkli bir veritabani:** PostgreSQL, MongoDB, DynamoDB, vb.
- **Ozel bir altyapi:** Kubernetes operatorleri, Terraform, Pulumi, vb.

## Dosya Yapisi

Her teknoloji paketi `technology/` altinda tek bir `.mdc` dosyasidir:

```
technology/
├── tech-go.mdc              ← Yeni tech pack
├── tech-dotnet.mdc          ← Mevcut ornek
├── tech-react.mdc           ← Mevcut ornek
└── _template/               ← Sablon (olusturulacak)
    └── tech-template.mdc
```

## Olusturma Adimlari

### 1. Mevcut Bir Pack'i Referans Alin

Sifirdan yazmak yerine mevcut bir pack'i (ornegin `tech-dotnet.mdc` veya `tech-react.mdc`) inceleyerek yapinin ne icerdigini anlayin.

### 2. Dosyayi Olusturun

`technology/tech-{name}.mdc` adinda yeni dosya olusturun.

### 3. Frontmatter Ayarlayin

```yaml
---
description: "Go Backend Expert — Go 1.22+, Gin/Echo, GORM, concurrency patterns"
globs: ["**/*.go", "**/go.mod"]
alwaysApply: false
priority: 40
---
```

**Kritik noktalar:**

- **`priority: 40`** — Tum teknoloji paketleri icin standart deger. Tek istisna `tech-security.mdc` (priority: 100; guvenlik kurallarini en yuksek onceliklimolarak korur).
- **`globs`** — Pack'in hangi dosyalar acikken aktif olacagini belirler. Teknolojinize uygun dosya uzantilari ve klasor kaliplari kullanin.
- **`alwaysApply: false`** — Teknoloji paketleri sadece ilgili dosyalar acikken yuklenir.

### 4. Zorunlu Bolumler

Her tech pack asagidaki bolumleri icermelidir:

#### Kimlik ve Uzmanlik

```markdown
# {Teknoloji Adi} Expert — World-Class Expert

## Kimlik
- **Rol:** Principal {Teknoloji} Developer
- **Uzmanlik:** [Detayli uzmanlik alanlari]
- **Referanslar:** [Resmi dokumanlar, kitaplar, best practice kaynaklari]
```

#### Best Practices

Teknolojiye ozel en iyi uygulamalar listesi. Somut, uygulanabilir maddeler olmali.

#### Anti-Patterns

Kacinilmasi gereken yapilar ve bunlarin dogru alternatifleri. Tablo formatinda:

```markdown
| Anti-Pattern | Tespit | Dogru Yaklasim |
|---|---|---|
| [Yanlis] | [Nasil tespit edilir] | [Dogru cozum] |
```

#### Code Smells

Teknolojiye ozel kod kokulari ve cozumleri. `code-quality.mdc` ile uyumlu formatta yazin.

#### Naming Conventions

Isimlendirme kurallari: dosya, sinif, fonksiyon, degisken, sabit vb. icin tutarli kurallar.

#### (Opsiyonel) Ek Bolumler

Teknolojiye gore: proje yapisi, test stratejisi, dependency management, deployment, performans optimizasyonu vb.

### 5. Glob Pattern'leri Dogru Secin

| Teknoloji | Ornek Glob |
|-----------|-----------|
| Go | `**/*.go`, `**/go.mod` |
| Java | `**/*.java`, `**/pom.xml`, `**/build.gradle` |
| Angular | `**/*.component.ts`, `**/*.module.ts` |
| Vue | `**/*.vue`, `**/nuxt.config.*` |
| Flutter | `**/*.dart`, `**/pubspec.yaml` |
| PostgreSQL | `**/*.sql`, `**/migrations/**` |

Glob pattern'lerinin diger paketlerle cakismamastna dikkat edin. Ornegin `**/*.ts` hem React hem Angular icin gecerlidir; daha spesifik kaliplar kullanmayi tercih edin.

### 6. Framework'e Kaydedin

1. **Manifest schema'ya ekleyin:** `agents.manifest.schema.json` dosyasindaki `layers.technology.items.enum` listesine yeni pack adini ekleyin
2. **Install script'lere ekleyin:** `scripts/install.ps1` ve `scripts/install.sh` dosyalarindaki teknoloji secim listesine ekleyin
3. **SKILL.md'yi guncelleyin:** Layer 2 listesine yeni pack'i ekleyin
4. **README.md'yi guncelleyin:** Architecture bolumune yeni pack'i ekleyin

## En Iyi Pratikler

1. **"World-class expert" perspektifiyle yazin:** Pack, o teknolojide uzman bir gelistiricinin bilgisini temsil etmeli.
2. **Somut olun:** "Dikkatli ol" degil, "X yerine Y kullan, cunku Z" formatinda yazin.
3. **Ornek kod ekleyin:** Anti-pattern ve best practice'lerde kisa kod ornekleri agent'in anlamasini kolaylastirir.
4. **Mevcut paketlerle tutarli olun:** Bolum yapisi, tablo formati ve dil kullanimi diger paketlerle ayni olmali.
5. **Priority'yi 40'ta binakin:** Ozel bir sebep olmadikca tum tech pack'ler priority 40 kullanir. Security 100'de kalir.
6. **Glob'lari dar tutun:** Gereksiz yere genis glob kullanmak, alakasiz dosyalarda pack'in aktif olmasina neden olur.
7. **Referans kaynaklari belirtin:** Resmi dokumantasyon, taninmis kitaplar ve style guide'lara atif yapin.
