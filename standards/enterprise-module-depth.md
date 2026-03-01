# Enterprise Modül Derinlik Standardı

**Amaç:** Yaşam döngüsü, invariant'lar, çok kiracılık ve ölçek gerektiren modüller (LPN, Sipariş, Wave, Görev vb.) için analiz ve tasarımın **enterprise seviyesinde** yapılması. Sadece "oluşturma + lokasyon atama" gibi yüzeysel user story'ler yetmez; açık domain modeli, state machine, invariant'lar, concurrency, audit, event'ler ve edge case'ler net tanımlanmalıdır.

**Referans:** process-analysis.mdc (§ Enterprise Modül US), process-architecture.mdc (§ Enterprise Modül ADR/Kontrat)

---

## 1. Ne Zaman Uygulanır?

Aşağıdakilerden **en az üçü** modülde geçerliyse bu standard **zorunludur**:

- Entity'nin **yaşam döngüsü** (state machine) var (örn. Created → Available → Reserved → …)
- **Invariant** kuralları var (lokasyonsuz dolu olamaz, stok varken silinemez, belirli geçişler yasak)
- **Depo + tenant** bazında benzersizlik veya format validasyonu
- **Parent/child** veya hiyerarşik ilişki (döngü koruması gerekir)
- **Milyonlarca kayıt** hedefi (indekslenmiş, filtrelenebilir sorgu)
- **RF / mobil** senaryolarda kullanım (atomic işlem garantisi)
- **Audit trail** veya **domain event** üretimi gerekiyor
- **Rol bazlı yetkilendirme** matrisi (kim hangi statüyü değiştirebilir)

Örnek modüller: LPN (License Plate), Sipariş (Order), Wave, Pick/Shipment Task, Lokasyon, Stok Hareketi.

---

## 1.1. Mevcut / Geçmiş US'ler

**Daha önce yazılmış US'ler geçerlidir; iptal edilmez.** Yeni standard **ileriye dönük** (yeni modüller + isteğe bağlı revizyon) uygulanır. İhtiyaç halinde modül modül revize edilir.

---

## 2. Domain Modeli — 3. State Machine — 4. Invariant'lar — 5. Optimistic Concurrency — 6. Audit Trail — 7. Domain Event'ler — 8. Parent/Child — 9. Ölçek/Sorgu — 10. RBAC — 11. RF Atomiklik — 12. Edge Case'ler

(Özet: Kurallar process-analysis.mdc ve process-architecture.mdc içinde referanslanır. Tam metin proje docs/agents/ veya bu skill'deki tam sürümden kopyalanabilir.)

---

## 13. Checklist — İş Analisti (US Yazarken)

- [ ] Domain model özeti US dokümanında var mı?
- [ ] State machine + geçiş matrisi referanslı mı?
- [ ] Invariant'lar listelendi mi? Her biri için en az bir AC var mı?
- [ ] Depo + tenant benzersizlik ve format validasyonu AC'lerde net mi?
- [ ] Optimistic concurrency edge case AC'de var mı?
- [ ] Audit trail bir AC'de geçiyor mu?
- [ ] Domain event'ler gerekiyorsa AC'de belirtildi mi?
- [ ] Parent/child varsa döngü koruması ve silme kuralı AC'de mi?
- [ ] Filtreleme, sayfalama, sıralama listeleme US'inde tanımlı mı?
- [ ] RBAC en az bir AC veya ayrı US'te var mı?
- [ ] RF atomik işlem AC'de var mı?
- [ ] Edge case'ler (çakışma, kapasite, rezervasyon, inter-warehouse) net AC'lerle yazıldı mı?

---

## 14. Checklist — Çözüm Mimari (ADR / Kontrat Yazarken)

- [ ] Domain modeli, state machine + matris, invariant listesi ADR'da var mı?
- [ ] RowVersion/ETag, audit trail, domain event'ler, parent/child döngü koruması belirtildi mi?
- [ ] Sorgu/indeks, RBAC, RF atomiklik ADR'da var mı?
- [ ] Kontratda ETag/If-Match, 409/422/403 hata kodları belirtildi mi?

---

**Bu dosya:** Jeager Agents v2 skill'den yeni projeye kurulum sırasında `docs/agents/` altına kopyalanır. Projede genişletilmiş sürüm (tam §2–§12) tutulabilir.
