# Ornek Akis: Refactor

Bu dokumanda @sef ile bir refactor isteginin siniflandirmasi, agent secimi, kapilar ve final ozet ornegi gosterilir.

---

## 1. Kullanici Istegi

```
@sef "Service katmanini ayir: domain mantigi application servicelerinden cikaralim, DDD uyumlu hale getirelim"
```

---

## 2. Is Siniflandirmasi (@sef)

| Boyut | Sonuc | Gerekce |
|-------|--------|---------|
| **Tur** | `refactor` | "ayir", "DDD", "uyumlu" — yapisal degisiklik, davranis ayni kalir |
| **Kapsam** | M veya L | Birden fazla dosya/sinif, katman etkilenir |
| **Risk** | orta | Mimari degisiklik, mevcut testlerin guncellenmesi gerekebilir |

**Cikti (kullaniciya):**
- Is: Service katmani refaktoru (domain/application ayrimi, DDD)
- Tur: refactor | Kapsam: M/L | Risk: orta
- Agent Hatti: mimari(?) → backend (veya ilgili tech agent) → qa → review
- Decision Log: mimari dahil etme ve retry/escalation kararlarinin hepsi loglanir
- Mimari tetikleyici: katman degisikligi, bu yuzden mimari genelde dahil edilir.

---

## 3. Agent Secimi ve Handoff

| # | Agent | Gorev |
|---|-------|--------|
| 1 | @mimari | Mevcut yapiyi ve hedef DDD/katman modelini belirle; kisa ADR veya refactor plani; domain/application sinirini tanimla |
| 2 | @backend | Servisleri bol, domain mantigini tasi, mevcut API davranisini koru; testleri guncelle |
| 3 | @qa | Unit/integration testlerin hala gectigini dogrula, gerekirse testleri uyarla |
| 4 | @review | Katman ihlali yok mu, dependency yonu dogru mu kontrol et |

Handoff: Mimari cikti (ADR/plan) backend’e referans verilir; backend handoff’ta hangi dosyalarin nasil bolunecegi ve kontrat (API ayni kalacak) netlesir. `workflow-state.md` icinde `changed_components`, `failure_counters` ve `major_decisions` alanlari aktif tutulur.

---

## 4. Kalite Kapilari

| Kapi | Bu akista | Sonuc ornegi |
|------|-----------|--------------|
| G1 Analiz | Gecti | Refactor kapsami net |
| G2 Kabul | Gecti veya kisa | Refactor kabul kriterleri (davranis korunacak, katmanlar ayri) |
| G3 Mimari | Mimari sonrasi | ADR/refactor plani onaylandi |
| G4 Uygulama | Backend sonrasi | Kod refactor edildi, build ve mevcut testler gecti |
| G5 Test | QA sonrasi | Tum testler guncel ve gecti |
| G6 Review | Review sonrasi | Katman ihlali yok, DoD karsilandi |
| G7 Yayin | Kullanici onayi | Refactor yayina hazir |

Kapi raporu ve workflow-state’te "Gerekce / Decision Ref" doldurulur. Bir gate once kalip sonra retry ile gecerse, ilgili failure report ve retry decision logu da baglanir.

---

## 5. Final Ozet (@sef)

- **Yapilan isler:** Mimari plan/ADR olusturuldu, service katmani bolundu, domain/application ayrildi, testler guncellendi, review tamamlandi.
- **Degisiklikler:** Tasinan/yeniden duzenlenen dosyalar, yeni klasor yapisi, API ayni (breaking change yok).
- **Dogrulanmasi gerekenler:** Kullanici/ekip davranisin degismedigini kabul eder.
- **Acik kalemler:** Sonraki refactor adimlari veya dokumantasyon guncellemesi.
- **Traceability:** workflow-state + retry karar logu + failure report + gate raporlari.

---

## Ozet Akis Semasi

```
@sef "Service katmanini ayir..."
  → SINIFLANDIRMA: refactor / M veya L / orta
  → ONAY: Kullanicidan onay
  → @mimari → ADR / refactor plani → [G3 GECTI]
  → @backend → Refactor + test guncelleme → [G4 GECTI]
  → @qa → Test dogrulama → [G5 GECTI]
  → @review → Katman/DoD kontrolu → [G6 GECTI]
  → Final ozet → [G7 ONAYI]
```

Detay: `orchestrator.mdc` (refactor agent hatti), `orchestration-policies.mdc` (DoR ve kapi kriterleri).
