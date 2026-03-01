# Dagitim Modeli

## Secilen Model: Skill Paketi + Opsiyonel GitHub Template

Framework uc kanaldan dagitilir; hepsi ayni kaynak repo'yu kullanir.

### Kanal 1: Cursor Skill Paketi (Birincil)

Framework repo'su dogrudan Cursor skills dizinine klonlanir/kopyalanir. Cursor IDE oturumdaki skill referanslari uzerinden framework'e erisir.

```
~/.cursor/skills/cursor-agents-framework/
├── SKILL.md            ← Cursor bunu okur
├── core/
├── technology/
├── process/
├── domains/
├── learning/
├── scripts/
└── ...
```

**Kurulum:**
```bash
git clone https://github.com/sedat-cengiz/cursor-agents-framework.git \
  ~/.cursor/skills/cursor-agents-framework
```

**Guncelleme:**
```bash
cd ~/.cursor/skills/cursor-agents-framework && git pull
```

### Kanal 2: GitHub Template Repository

Ayni repo GitHub'da "template repository" olarak isaretlenir. Yeni proje baslatirken "Use this template" ile framework iskeletini alabilir.

Bu yontem **framework gelistiricileri** icin; framework'e katkida bulunmak veya ozel fork isteyenler icin uygundur.

### Kanal 3: Dogrudan Indirme (ZIP)

Git kullanmayan ortamlar icin GitHub Releases'tan ZIP indirilebilir.

## Neden Bu Model?

| Kriter | Skill Paketi | GitHub Template | CLI Tool |
|--------|-------------|-----------------|----------|
| Kurulum kolayligi | ✅ Tek git clone | ✅ Use this template | ❌ Tool kurmak gerekir |
| Guncelleme | ✅ git pull | ❌ Manual merge | ✅ agentfw update |
| Proje izolasyonu | ✅ Skill disarida, proje kurallar kopyalanir | ❌ Framework projeye gomulu | ✅ Secimli |
| Coklu proje | ✅ Tek skill, N proje | ❌ Her proje ayri kopya | ✅ Tek tool |
| Karmasiklik | ✅ Sifir bagimlilik | ✅ Sifir bagimlilik | ❌ Node/dotnet gerekir |

**Sonuc:** Skill paketi basitlik ve coklu proje destegi nedeniyle birincil kanal. CLI araci ileride (v4+) eklenebilir.

## Versiyon Yonetimi

Framework semver kullanir: `MAJOR.MINOR.PATCH`

| Degisiklik | Ornek | Versiyon |
|-----------|-------|----------|
| Yeni tech pack ekleme | tech-python.mdc | MINOR (3.1.0) |
| Yeni domain pack ekleme | domains/healthcare/ | MINOR (3.2.0) |
| Mevcut kurala icerik ekleme | code-quality'ye yeni smell | PATCH (3.0.1) |
| Kural formatini degistirme | manifest schema degisikligi | MAJOR (4.0.0) |
| Core kural silme/yeniden adlandirma | orchestrator.mdc rename | MAJOR (4.0.0) |

## Release Sureci

1. `main` branch her zaman kararlı
2. Degisiklikler feature branch + PR ile yapilir
3. PR'da en az 1 review
4. `CHANGELOG.md` guncellenir
5. Git tag ile release: `git tag v3.1.0 && git push --tags`
6. GitHub Release olusturulur (ZIP ile)
