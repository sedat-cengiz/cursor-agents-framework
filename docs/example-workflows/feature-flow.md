# Ornek Akis: Yeni Ozellik (Feature)

Bu dokumanda @sef ile yeni bir ozellik isteginin basindan sonuna nasil isledigi adim adim gosterilir.

---

## 1. Kullanici Istegi

```
@sef "Siparis modulu ekle: musteri siparis verebilsin, liste goruntulensin, durum guncellensin"
```

---

## 2. Is Siniflandirmasi (@sef)

Sef istegi analiz eder ve sunu cikarir:

| Boyut | Sonuc | Gerekce |
|-------|--------|---------|
| **Tur** | `feature` | "ekle", "modul" — yeni islev |
| **Kapsam** | L | Birden fazla katman (API, UI, DB), coklu ekran |
| **Risk** | orta | Veri modeli ve API degisikligi, migration olabilir |

**Cikti (kullaniciya):**
- Is: Siparis modulu (siparis olusturma, listeleme, durum guncelleme)
- Tur: feature | Kapsam: L | Risk: orta
- Agent Hatti: analist → mimari → backend ∥ frontend → qa → review
- Decision Log: siniflandirma ve routing karari `docs/agents/decisions/` altina yazilir
- Kullanicidan onay istenir; onaydan sonra yurutme baslar.

---

## 3. Agent Secimi ve Handoff

Sef agent hattini belirler ve her adim icin filtrelenmis handoff uretir.
Bu asamada `workflow-state.md` baslatilir ve `selected_agents`, `active_gate`, `major_decisions` alanlari doldurulur.

| # | Agent | Handoff icerigi (ozet) |
|---|-------|-------------------------|
| 1 | @analist | US yazimi; kabul kriterleri, scope netlestirme |
| 2 | @mimari | ADR + API kontrati (siparis endpoint’leri, durum enum) |
| 3 | @backend ∥ @frontend | Kontrat referansi, backend/frontend gorevleri; paralel calisir |
| 4 | @qa | Test stratejisi, unit/integration/E2E kapsami |
| 5 | @review | Kod incelemesi, DoD kontrolu |

Handoff ornegi (analist → mimari): `docs/agents/handoffs/` altinda; icinde is ozeti, bu agent’in gorevi, kesinlesmis kararlar (ADR ref), teknik baglam, kisitlar, beklenen cikti, DoD.

---

## 4. Kalite Kapilari

Her kapi gecisinde Sef kriterleri kontrol eder; gecti/kaldi raporu (ve gerekiyorsa decision log) uretir.

| Kapi | Bu akista | Sonuc ornegi |
|------|-----------|--------------|
| G1 Analiz | Gecti | Istek net, kapsam belirlendi |
| G2 Kabul | Analist sonrasi | US onaylandi, kabul kriterleri yazildi |
| G3 Mimari | Mimari sonrasi | ADR + kontrat olusturuldu |
| G4 Uygulama | Backend/Frontend sonrasi | Kod ve UI uretildi, kontrat uyumlu |
| G5 Test | QA sonrasi | Unit/integration testler gecti |
| G6 Review | Review sonrasi | MUST-FIX yok, DoD karsilandi |
| G7 Yayin | Kullanici onayi | Demo/gosterim icin hazir |

Kapi raporu: `_template-quality-gate.md` formatinda; `decision_id`, `state_ref` ve evidence alanlari doldurulur.

---

## 5. Final Ozet (@sef)

Tum adimlar ve kapilar tamamlaninca Sef kullaniciya ozet verir:

- **Yapilan isler:** US yazildi, ADR + kontrat olusturuldu, backend API ve frontend ekranlari yazildi, testler ve review tamamlandi.
- **Degisiklikler:** Eklenen/degisen dosyalar, yeni endpoint’ler, migration detayi, test sayilari.
- **Dogrulanmasi gerekenler:** Kullanici kabulu, demo.
- **Acik kalemler:** Varsa sonraki iyilestirmeler veya tech debt notu.
- **Traceability:** workflow-state, decision loglari ve quality gate raporlari referans verilir.

---

## Ozet Akis Semasi

```
@sef "Siparis modulu ekle..."
  → SINIFLANDIRMA: feature / L / orta
  → ONAY: Kullanicidan agent hatti onayi
  → @analist → US → [G2 GECTI]
  → @mimari → ADR + kontrat → [G3 GECTI]
  → @backend ∥ @frontend → Kod → [G4 GECTI]
  → @qa → Testler → [G5 GECTI]
  → @review → Inceleme → [G6 GECTI]
  → Final ozet → [G7 ONAYI]
```

Detayli orkestrasyon kurallari: `orchestrator.mdc`, `orchestration-policies.mdc`. Daha kisa ornekler: `templates/agent-guide.md`.
