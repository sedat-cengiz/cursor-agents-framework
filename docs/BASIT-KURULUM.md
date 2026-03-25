# Cursor Agents Framework — Adım adım kurulum

## İlk kez (bilgisayarda bir kere)

1. PowerShell aç.
2. Şunu çalıştır:
   ```powershell
   git clone https://github.com/sedat-cengiz/cursor-agents-framework.git "$env:USERPROFILE\.cursor\skills\cursor-agents-framework"
   ```
3. Bitti. Bu adımı bir daha yapma.

---

## Her yeni projede

1. Proje klasörüne gir (örn. `cd D:\MyProject`).
2. Şunu çalıştır:
   ```powershell
   & "$env:USERPROFILE\.cursor\skills\cursor-agents-framework\scripts\install.ps1" -ProjectPath . -Quick
   ```
3. Cursor’da bu projeyi aç.
4. Chat’e yaz: **`@sef`** ve ne yapmak istediğin (örn. `@sef Sipariş modülü ekle`).

Bu kadar.
