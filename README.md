# İş Ağı v0.1

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
- Özel mesajlar cihazda periyodik yenilenmez; sohbet ekranını yeniden açarak yenileyebilirsin. Realtime aboneliği sonraki sürüm hedefidir.
- Fotoğraf yükleme için SQL depolama kurgusu hazır, ancak v0.1 arayüzü yalnızca metin gönderisi yayınlar.
- Üretim öncesi spam ve kötüye kullanım önleme, moderatör paneli, veri silme talebi akışı, KVKK metinleri ve güvenlik testi gereklidir.
- Android imzalama: Actions debug olmayan release çıktısı üretir; Play Store'a yüklemek için kalıcı kendi upload anahtarınla imzalama yapılandırmalısın.

## Test
`flutter analyze` ve `flutter test`; Flutter SDK'nın sistemde kurulu olması gereklidir.
