# İş Ağı v0.2.0

Flutter ile geliştirilen Türkçe mesleki sosyal ağ ve iş bulma uygulaması.

## Modüller
- E-posta/şifre ile üyelik ve oturum açma (Supabase Auth)
- Meslek, yetenek, şehir, biyografi ve müsaitlik profili
- Sosyal gönderiler, beğeni, yorum ve gönderi şikâyeti
- İş ilanı oluşturma, başvuru ve başvuruları görüntüleme
- Kullanıcı arama, takip ve engelleme
- İki kişi arasında özel mesajlaşma
- Takip, beğeni, yorum, iş başvurusu ve mesaj için uygulama içi bildirim
- Satır bazlı veritabanı güvenliği (RLS)

## Bağlantı ve çalıştırma
İş Ağı, ayrı İş Ağı kuruluşundaki Supabase projesine bağlanmıştır. `config/client.json` yalnızca yayımlanabilir mobil istemci anahtarını içerir; yönetim anahtarı veya veritabanı şifresi içermez.

- Çalıştırma: `flutter run --dart-define-from-file=config/client.json`
- APK: `flutter build apk --release --dart-define-from-file=config/client.json`
- AAB: `flutter build appbundle --release --dart-define-from-file=config/client.json`
- E-posta ile kayıt açıktır. İlk girişten önce e-posta doğrulama bağlantısını açın.
- Veritabanı şeması bu projeye kurulmuştur. `supabase/schema.sql` yeni boş projeye ilk kurulum içindir; mevcut projede tekrar çalıştırmayın.
- `main` dalına yüklemeler GitHub Actions ile APK ve AAB üretir. Actions > son çalışma > Artifacts bölümünden indirin.

## Sınırlar / sonraki sürüm
- v0.1'de bildirimler uygulama içindedir; FCM push bildirimleri yoktur.
- Sohbetler ön planda 4 saniyede, sohbet listesi ve bildirimler 8 saniyede, bildirim rozeti 15 saniyede yenilenir. Arka planda push bildirimi yoktur.
- Fotoğraf (5 MB) ve video (60 saniye / 25 MB) paylaşımı vardır. Gönderi medyaları herkese açık portföy deposundadır. Hikâyeler özel depoda saklanır; erişim 24 saatte sona erer. Süresi dolan dosyaların kalıcı depolamadan temizliği için henüz zamanlanmış görev yoktur.
- Üretim öncesi spam ve kötüye kullanım önleme, moderatör paneli, veri silme talebi akışı, KVKK metinleri ve güvenlik testi gereklidir.
- Android imzalama: Actions debug olmayan release çıktısı üretir; Play Store'a yüklemek için kalıcı kendi upload anahtarınla imzalama yapılandırmalısın.

## Test
`flutter analyze` ve `flutter test`; Flutter SDK'nın sistemde kurulu olması gereklidir.

## Sosyal medya aşamaları
1. Fotoğraf önizlemeli paylaşım, herkes/takip edilenler akışı, yenileme, profil takip durumu ve takipçi sayıları.
2. Mesaj önizlemeleri, otomatik sohbet yenileme, çift gönderim koruması, okunmamış bildirim rozeti ve bildirimden sohbete geçiş.
3. Video oynatma, 24 saatlik fotoğraf/video hikâyeleri, hikâyeden mesaj ve şikâyet, sahibinin silmesi.

Yeni projede ilk şemadan sonra supabase/social_v02.sql uygulanmalıdır. Mevcut İş Ağı projesinde her iki kurulum tamamlanmıştır. Hikâye süreleri ve engelleme kuralları sunucuda uygulanır.
