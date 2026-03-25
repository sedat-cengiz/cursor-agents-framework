# Yeni Projeye Framework Ekleme ve Kullanım

---

## En basit yol (2 adım)

### 1. Framework'ü bir kez kurun

```powershell
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git "$env:USERPROFILE\.cursor\skills\cursor-agents-framework"
```

### 2. Proje klasörüne gidip tek komutla kurun

```powershell
cd D:\YeniProjem
& "$env:USERPROFILE\.cursor\skills\cursor-agents-framework\scripts\install.ps1" -ProjectPath . -Quick
```

**`-Quick`** = Soru sormaz; varsayılan olarak .NET + React + Testing kurulur. Manifest dosyası gerekmez.

Projeyi Cursor'da açıp chat'te **`@sef "yapılacak işi yaz"`** yazarak kullanmaya başlayın. İsterseniz `.cursor/rules/global-conventions.mdc` içinde proje adını düzenleyin.

---

## Alternatif: Bootstrap (proje klasöründen)

Framework zaten skills'ta kuruluysa, proje klasörüne **bootstrap.ps1** kopyalayıp oradan çalıştırabilirsiniz:

```powershell
cd D:\YeniProjem
Copy-Item "$env:USERPROFILE\.cursor\skills\cursor-agents-framework\scripts\bootstrap.ps1" .
.\bootstrap.ps1
```

Bootstrap, mevcut klasörü proje kabul edip `-Quick` ile kurar.

---

## Detaylı yol (manifest veya interaktif)

### Seçenek A: Manifest ile

1. **Yeni projenizin kök dizininde** `agents.manifest.json` oluşturun:

```json
{
  "$schema": "./agents.manifest.schema.json",
  "projectName": "ProjemAdi",
  "platform": "Kısa platform tanımı",
  "language": { "communication": "tr", "code": "en", "docs": "tr" },
  "layers": {
    "technology": ["dotnet", "react", "sql-server", "devops", "security", "testing"],
    "domain": ["ecommerce"]
  },
  "aliases": {
    "backend": "tech-dotnet",
    "frontend": "tech-react"
  }
}
```

2. **Kurulum script'ini çalıştırın** (framework dizininden veya proje dizininden):

```powershell
# PowerShell — framework'ü skills'ta kurduysanız:
& "$env:USERPROFILE\.cursor\skills\cursor-agents-framework\scripts\install.ps1" -ProjectPath "D:\YeniProjem"

# Veya framework dizinindeyken:
cd D:\cursor-agents-framework
.\scripts\install.ps1 -ProjectPath "D:\YeniProjem"
```

```bash
# Bash (macOS/Linux)
~/.cursor/skills/cursor-agents-framework/scripts/install.sh ~/YeniProjem
```

Script, manifest'i okuyup teknoloji/domain seçimini otomatik yapar; `.cursor/rules/`, `docs/agents/`, `runtime/`, `scripts/` yapısını oluşturur.

### Seçenek B: Manifest olmadan (İnteraktif)

Proje kökünde `agents.manifest.json` yoksa script sizi adım adım yönlendirir:

1. Teknoloji paketlerini seçin (örn: 1,2,14,15 = .NET, React, Security, Testing)
2. Domain paketi seçin (örn: ecommerce, wms) veya "None"
3. Script aynı dosya ve klasör yapısını oluşturur

---

## 3. Projeyi Yapılandırma

Kurulumdan sonra:

1. **`.cursor/rules/global-conventions.mdc`** dosyasını açın.
2. Şunları projenize göre doldurun:
   - **Proje Adı**, **Platform** tanımı
   - **Teknoloji stack** (backend, frontend, veritabanı vb.)
   - **Dil kuralları** (iletişim/kod/döküman dili)

3. **(Opsiyonel)** Runtime ile gerçek agent çalıştırmak istiyorsanız:
   - `docs/agents/runtime/agent-invocation.json` — hangi agent için hangi komutun çalışacağı
   - `docs/agents/runtime/evidence-command-map.json` — build/test/security kanıt komutları (dotnet, node, python vb.)

---

## 4. Kullanım

### Tek giriş noktası: `@sef`

Tüm işleri **Cursor chat'te** `@sef` ile başlatın. Kullanıcı sadece `@sef` ile konuşur; diğer agent'lar `@sef` tarafından seçilip yönetilir.

**Örnekler:**

```
@sef "Sipariş modülü ekle"
@sef "Login sayfası 500 hatası veriyor, düzelt"
@sef "Service katmanını ayrı bir projeye taşı"
```

### Ne olur?

1. **Intake:** İsteğiniz sınıflandırılır (feature / bugfix / refactor vb.), kapsam ve risk belirlenir.
2. **Rota:** İş türüne göre minimal agent hattı seçilir (analist → mimari → backend ∥ frontend → qa → review vb.).
3. **Onay:** Plan için onay istenir (opsiyonel ama önerilir).
4. **Çalıştırma:** Her agent için handoff yazılır, kalite kapıları (G1–G7) uygulanır, workflow state güncellenir.
5. **Özet:** Sonuç ve durum size raporlanır.

### Doğrudan agent kullanımı

Gerekirse belirli bir role doğrudan da yazabilirsiniz (örn. sadece mimari danışmak için):

- `@backend` — Backend geliştirici
- `@frontend` — Frontend geliştirici
- `@qa` — Test
- `@review` — Kod inceleme
- `@mimari` — Çözüm mimarı
- `@analist` — İş analisti
- `@guvenlik` — Güvenlik
- `@devops` — DevOps

Ancak **tamamlanmış bir iş akışı** (feature/bugfix/refactor) için her zaman `@sef` ile başlamak en doğrusudur.

### Önemli dosyalar (proje içinde)

| Dosya / Klasör | Amaç |
|----------------|------|
| `docs/agents/agent-guide.md` | Agent rehberi, rol/kural eşlemesi |
| `docs/agents/workflow-state.md` | Paylaşılan iş durumu |
| `docs/agents/taskboard.md` | Görev tablosu |
| `docs/agents/decisions/` | Karar kayıtları (decision log, ADR) |
| `docs/agents/handoffs/` | Agent arası devir notları |
| `docs/agents/quality-gates/` | Kalite kapısı kanıtları |
| `AGENTS.md` (proje kökü) | Agent sistemine giriş; `docs/agents/agent-guide.md` linki |

---

## 5. Güncelleme

Framework'ü güncelledikten sonra projedeki runtime ve script'leri yenilemek için:

```powershell
# PowerShell
& "$env:USERPROFILE\.cursor\skills\cursor-agents-framework\scripts\update.ps1" -ProjectPath "D:\YeniProjem"
```

Bu script `runtime/`, `scripts/validate.ps1`, `scripts/validate-orchestration.ps1`, `scripts/run-agent.ps1` ve şablonları projeye geri kopyalar. Kendi `agents.manifest.json` ve `.cursor/rules/` düzenlemeleriniz korunur.

---

## 6. Kısa Kontrol Listesi

- [ ] Framework klonlandı (skills veya başka dizin)
- [ ] `agents.manifest.json` oluşturuldu (veya interaktif kurulum tamamlandı)
- [ ] `install.ps1` / `install.sh` çalıştırıldı
- [ ] `global-conventions.mdc` düzenlendi
- [ ] Cursor'da proje açıldı
- [ ] Chat'te `@sef` denendi
- [ ] (Opsiyonel) `docs/agents/runtime/agent-invocation.json` ve evidence map yapılandırıldı

Bu adımlardan sonra yeni projede framework kurulmuş ve kullanıma hazır demektir.
