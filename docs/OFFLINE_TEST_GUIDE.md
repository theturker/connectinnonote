# 🧪 Offline-First Test Kılavuzu

Bu kılavuz, uygulamanın offline-first özelliklerini test etmek için hazırlanmıştır.

## 📋 Test Senaryoları

### ✅ **Test 1: Offline Login (Ana Sorun Çözümü)**

**Amaç**: İnternet olmadan giriş yapabilme

**Adımlar:**
1. ✅ **Online Giriş Yap**
   - Uygulamayı aç
   - Email ve şifre ile giriş yap
   - Ana ekrana yönlendirildiğini doğrula

2. ✅ **Uygulamayı Kapat**
   - Uygulamayı tamamen kapat (kill)

3. ✅ **İnterneti Kapat**
   - WiFi kapat
   - Mobil veriyi kapat
   - Uçak modunu aç

4. ✅ **Uygulamayı Tekrar Aç**
   - Uygulamayı başlat
   
**Beklenen Sonuç:**
- ✅ Login ekranı gösterilmemeli
- ✅ Otomatik olarak ana ekrana yönlendirilmeli
- ✅ "Offline Mode" göstergesi görünmeli
- ✅ Tüm notlar görüntülenmeli

**Hata Durumu (Eski):**
- ❌ Login ekranına atılıyor
- ❌ "Giriş yapılamadı" hatası

---

### ✅ **Test 2: Offline Not Ekleme**

**Adımlar:**
1. Offline modda olduğundan emin ol
2. "+" butonuna bas
3. Başlık ve içerik gir
4. "Kaydet" butonuna bas

**Beklenen Sonuç:**
- ✅ Not anında kaydedilmeli (<100ms)
- ✅ "Not kaydedildi (Offline)" mesajı gösterilmeli
- ✅ Not listede görünmeli
- ✅ Üstte "Offline Mode" göstergesi

**İnterneti Aç:**
- ✅ "Bağlantı Sağlandı" mesajı
- ✅ "Senkronize ediliyor" göstergesi
- ✅ Not Firebase'e gönderilmeli

---

### ✅ **Test 3: Offline Not Düzenleme**

**Adımlar:**
1. Offline modda bir nota tıkla
2. Başlık veya içeriği değiştir
3. "Güncelle" butonuna bas

**Beklenen Sonuç:**
- ✅ Değişiklik anında kaydedilmeli
- ✅ "Not güncellendi (Offline)" mesajı
- ✅ Listede güncel bilgi görünmeli

**İnterneti Aç:**
- ✅ Otomatik sync
- ✅ Değişiklik Firebase'e gönderilmeli

---

### ✅ **Test 4: Offline Not Silme + Geri Alma**

**Adımlar:**
1. Offline modda bir notu sil
2. "Sil" onayını ver

**Beklenen Sonuç:**
- ✅ Not anında silinmeli
- ✅ "Not silindi (Offline)" mesajı
- ✅ "GERİ AL" butonu gösterilmeli

**Geri Al:**
- ✅ "GERİ AL" butonuna bas
- ✅ Not geri gelmeli

**İnterneti Aç:**
- ✅ Silme/geri alma sync edilmeli

---

### ✅ **Test 5: Çoklu İşlem Offline**

**Adımlar:**
1. Offline modda:
   - 3 yeni not ekle
   - 2 notu düzenle
   - 1 notu sil
   - 1 notu favorilere ekle

**Beklenen Sonuç:**
- ✅ Tüm işlemler anında çalışmalı
- ✅ Hiçbir hata olmamalı
- ✅ UI güncel kalmalı

**İnterneti Aç:**
- ✅ "Senkronize ediliyor (X/Y)" göstergesi
- ✅ Tüm değişiklikler Firebase'e gönderilmeli
- ✅ "Senkronizasyon tamamlandı" mesajı

---

### ✅ **Test 6: Arama ve Filtreleme (Offline)**

**Adımlar:**
1. Offline modda arama yap
2. Favori filtresini kullan

**Beklenen Sonuç:**
- ✅ Arama anında çalışmalı
- ✅ Filtreleme anında çalışmalı
- ✅ Local DB'den veri geldiği için çok hızlı

---

### ✅ **Test 7: Manuel Sync**

**Adımlar:**
1. Offline modda değişiklikler yap
2. İnterneti aç
3. AppBar'daki sync butonuna bas

**Beklenen Sonuç:**
- ✅ Manuel sync başlamalı
- ✅ "Senkronizasyon başlatılıyor" mesajı
- ✅ Progress göstergesi
- ✅ "Senkronizasyon tamamlandı" mesajı

---

### ✅ **Test 8: Periyodik Auto-Sync**

**Adımlar:**
1. Online modda bekle (30 saniye)
2. Konsolu gözlemle

**Beklenen Sonuç:**
- ✅ Her 30 saniyede otomatik sync
- ✅ Konsol logları: "Starting full sync..."

---

### ✅ **Test 9: Çoklu Cihaz Sync**

**Adımlar:**
1. **Cihaz A**: Giriş yap, not ekle
2. **Cihaz B**: Aynı hesapla giriş yap

**Beklenen Sonuç:**
- ✅ Cihaz B'de Cihaz A'nın notu görünmeli
- ✅ Her iki cihazda da sync çalışmalı

**Çapraz Test:**
1. **Cihaz A**: Offline, not ekle
2. **Cihaz B**: Online, başka not ekle
3. **Cihaz A**: İnterneti aç

**Beklenen Sonuç:**
- ✅ Her iki cihazda da tüm notlar görünmeli
- ✅ Conflict yok

---

### ✅ **Test 10: App Yeniden Başlatma (Offline)**

**Adımlar:**
1. Offline modda notlar ekle/düzenle
2. Uygulamayı kapat (kill)
3. Uygulamayı tekrar aç (hala offline)

**Beklenen Sonuç:**
- ✅ Otomatik giriş yapılmalı
- ✅ Tüm değişiklikler kayıtlı
- ✅ Local DB'den hızlı yükleme

---

## 🔍 Debug Kontrolleri

### Console Logları

**Online → Offline:**
```
📡 Connection: Offline
```

**Offline → Online:**
```
📡 Connection: Online (WiFi)
🔄 Connection restored, starting sync...
🔄 Starting full sync...
🔄 Syncing X notes to Firebase...
✅ Full sync completed
```

**Not Ekleme (Offline):**
```
📝 Adding note (offline-first)...
✅ Note saved to local DB
✅ Local listeye eklendi
⚠️ Offline - Note will sync when online
```

**Not Ekleme (Online):**
```
📝 Adding note (offline-first)...
✅ Note saved to local DB
✅ Local listeye eklendi
✅ Note synced: [note_id]
```

---

## 📊 Performans Beklentileri

| İşlem | Offline | Online (Local First) | Online (Direct Firebase) |
|-------|---------|---------------------|-------------------------|
| Not Okuma | 10-50ms | 10-50ms | 500ms-2s |
| Not Ekleme | <100ms | <100ms + bg sync | 1-3s |
| Not Güncelleme | <100ms | <100ms + bg sync | 1-3s |
| Not Silme | <100ms | <100ms + bg sync | 1-3s |
| Arama | <50ms | <50ms | 200ms-1s |

---

## ✅ Test Checklist

Tüm testleri tamamladıktan sonra:

- [ ] **Test 1**: Offline login çalışıyor ✓
- [ ] **Test 2**: Offline not ekleme çalışıyor ✓
- [ ] **Test 3**: Offline not düzenleme çalışıyor ✓
- [ ] **Test 4**: Offline not silme + geri alma çalışıyor ✓
- [ ] **Test 5**: Çoklu işlem offline çalışıyor ✓
- [ ] **Test 6**: Arama/filtreleme offline çalışıyor ✓
- [ ] **Test 7**: Manuel sync çalışıyor ✓
- [ ] **Test 8**: Periyodik auto-sync çalışıyor ✓
- [ ] **Test 9**: Çoklu cihaz sync çalışıyor ✓
- [ ] **Test 10**: App restart offline çalışıyor ✓

---

## 🐛 Bilinen Sınırlamalar

1. **Firebase Auth**: Offline login için local session kullanılır
2. **Conflict Resolution**: Son güncelleme kazanır (timestamp based)
3. **Sync Interval**: 30 saniye (değiştirilebilir)
4. **Storage**: Hive local database (sınırsız, cihaz kapasitesine bağlı)

---

## 🎯 Başarı Kriterleri

✅ **Tüm testler başarılı ise:**
- Offline-first implementasyonu tam çalışıyor
- Kullanıcı deneyimi mükemmel
- Production'a hazır

❌ **Herhangi bir test başarısız ise:**
- Hangi testin başarısız olduğunu not et
- Console loglarını kontrol et
- Hata mesajını kaydet
- Geliştirici ile paylaş

---

**Test Tarihi**: _____________

**Test Eden**: _____________

**Sonuç**: ⬜ Başarılı / ⬜ Başarısız

**Notlar**:
_______________________________________
_______________________________________

