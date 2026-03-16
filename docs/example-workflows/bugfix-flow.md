# Ornek Akis: Hata Duzeltme (Bugfix)

Bu dokumanda @sef ile bir bugfix isteginin nasil siniflandirildigi, hangi agent’larin calistigi ve kapilarin nasil isledigi gosterilir.

---

## 1. Kullanici Istegi

```
@sef "Login sayfasi 500 hatasi veriyor, giris yapilamiyor"
```

---

## 2. Is Siniflandirmasi (@sef)

| Boyut | Sonuc | Gerekce |
|-------|--------|---------|
| **Tur** | `bugfix` | "hata", "500", "calismiyor" |
| **Kapsam** | S | Tek akis, muhtemelen tek katman (backend veya auth) |
| **Risk** | orta | Giris fonksiyonu etkileniyor |

**Cikti (kullaniciya):**
- Is: Login 500 hatasi duzeltmesi
- Tur: bugfix | Kapsam: S | Risk: orta
- Agent Hatti: backend (veya hatanin oldugu teknik agent) → qa → review
- Decision Log: kisa bugfix akisi secimi `docs/agents/decisions/` altina yazilir
- Bugfix’te G1/G2/G3 genelde atlanir; G4 (Uygulama), G5 (Test), G6 (Review) uygulanir.

---

## 3. Agent Secimi ve Handoff

| # | Agent | Gorev |
|---|-------|--------|
| 1 | @backend (veya ilgili tech agent) | 500 nedenini tespit et, duzelt (ornegin exception handling, validation) |
| 2 | @qa | Regression testi yaz veya mevcut testi guncelle; giris akisini dogrula |
| 3 | @review | Kod degisikligini incele, MUST-FIX kontrolu |

Handoff: Sef, backend’e hatanin ozeti, ilgili dosyalar ve beklenen ciktiyi (duzeltme + test edilebilir senaryo) verir. `workflow-state.md` icinde gereksiz agent'larin atlandigi ve aktif gate'in G4 oldugu gorunur.

---

## 4. Kalite Kapilari

| Kapi | Bu akista | Sonuc ornegi |
|------|-----------|--------------|
| G1–G3 | Atlandi | Bugfix icin analiz/kabul/mimari kapilari atlanir |
| G4 Uygulama | Backend sonrasi | Duzeltme yapildi, build/run basarili |
| G5 Test | QA sonrasi | Regression testi gecti |
| G6 Review | Review sonrasi | Inceleme tamamlandi |
| G7 Yayin | Kullanici onayi | Duzeltme yayina hazir |

Kapi raporunda `decision_id`, evidence alanlari ve "Gerekce / Decision Ref" ile neden gecti/atlandi belgelenir.

---

## 5. Final Ozet (@sef)

- **Yapilan isler:** 500 sebebi bulundu ve duzeltildi, test eklendi/guncellendi, review tamamlandi.
- **Degisiklikler:** Degisen dosyalar, eklenen test.
- **Dogrulanmasi gerekenler:** Kullanici login akisini test etmeli.
- **Acik kalemler:** Yoksa bos; varsa ilgili tech debt notu.
- **Traceability:** workflow-state + bugfix routing decision log + G4/G5/G6 gate raporlari.

---

## Ozet Akis Semasi

```
@sef "Login 500 hatasi..."
  → SINIFLANDIRMA: bugfix / S / orta
  → ONAY: Kullanicidan onay
  → @backend → Duzeltme → [G4 GECTI]
  → @qa → Regression test → [G5 GECTI]
  → @review → Inceleme → [G6 GECTI]
  → Final ozet → [G7 ONAYI]
```

Detay: `orchestrator.mdc` (bugfix agent hatti), `orchestration-policies.mdc` (kapi atlama kurallari).
