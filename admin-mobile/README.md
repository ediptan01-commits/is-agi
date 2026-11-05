# İş Ağı Yönetim — Android 1.0.0

Ayrı Android paket kimliğiyle kurulan, doğrudan mevcut Supabase yönetim API'sine bağlanan yönetici uygulaması. Web paneli veya ChatGPT tarayıcı oturumu gerektirmez.

- Kullanıcıları listeleme ve askıya alma / yeniden açma
- Gönderi, yorum, iş ilanı ve hikâye denetimi
- Fotoğraf/video inceleme, içeriği gizleme / geri açma
- Şikâyet kararları ve işlem geçmişi
- Tekrar gönderim korumalı uygulama içi duyuru

Mevcut İş Ağı hesap e-postası ve şifresiyle giriş yapılır. Yetki her yönetim isteğinde sunucuda doğrulanır; mobil uygulamada yönetim anahtarı veya veritabanı şifresi bulunmaz. Özel mesajlara erişim sunulmaz. Yönetici oturumu diske kalıcı kaydedilmez.

`config/client.json` yalnızca yayımlanabilir istemci bağlantısıdır.

Yerel geliştirme:
1. `flutter create --platforms android --org com.teknolojix --project-name is_agi_yonetim .`
2. `flutter pub get`
3. `flutter analyze` ve `flutter test`
4. `flutter build apk --release --dart-define-from-file=config/client.json`

Depodaki admin-android.yml iş akışı ayrı APK/AAB ve çözülmüş bağımlılık kilidini oluşturur. İlk sürüm test dağıtımı için Flutter'ın oluşturduğu geliştirme imzasını kullanır; mağaza dağıtımı ve kalıcı güncellemeler için ayrı upload anahtarı gerekir.
