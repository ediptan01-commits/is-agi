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

## Kurulum
1. [Supabase](https://supabase.com/) üzerinden yeni proje oluştur.
2. SQL Editor'de `supabase/schema.sql` dosyasını çalıştır.
3. Authentication > Providers altında Email sağlayıcısını etkinleştir. E-posta doğrulaması etkinse gelen kutusundan onayla.
4. Lokal geliştirme için Flutter SDK kur ve `flutter create --platforms android --org com.teknolojix --project-name is_agi .` çalıştır.
5. `flutter pub get` ve ardından:
   `flutter run --dart-define=SUPABASE_URL=https://PROJE.supabase.co --dart-define=SUPABASE_ANON_KEY=YAYIMLANABILIR_ANAHTAR`
6. GitHub Actions için Repository > Settings > Secrets and variables > Actions içine `SUPABASE_URL` ve `SUPABASE_ANON_KEY` ekle.
7. GitHub'a push yapıldığında Actions iş akışı Android APK ve AAB üretir. Actions > son çalışma > Artifacts bölümünden indir.

`SUPABASE_ANON_KEY` yalnızca yayımlanabilir istemci anahtarı olmalıdır. `service_role` anahtarını **asla** mobil uygulamaya veya istemci Secrets yapılandırmasına ekleme.

## Sınırlar / sonraki sürüm
- v0.1'de bildirimler uygulama içindedir; FCM push bildirimleri yoktur.
- Özel mesajlar cihazda periyodik yenilenmez; sohbet ekranını yeniden açarak yenileyebilirsin. Realtime aboneliği sonraki sürüm hedefidir.
- Fotoğraf yükleme için SQL depolama kurgusu hazır, ancak v0.1 arayüzü yalnızca metin gönderisi yayınlar.
- Üretim öncesi spam ve kötüye kullanım önleme, moderatör paneli, veri silme talebi akışı, KVKK metinleri ve güvenlik testi gereklidir.
- Android imzalama: Actions debug olmayan release çıktısı üretir; Play Store'a yüklemek için kalıcı kendi upload anahtarınla imzalama yapılandırmalısın.

## Test
`flutter analyze` ve `flutter test`; Flutter SDK'nın sistemde kurulu olması gereklidir.
