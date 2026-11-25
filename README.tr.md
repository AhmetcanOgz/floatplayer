[English](README.md) | **Türkçe**

# FloatPlayer

Tüm masaüstlerinde ve tam ekran uygulamaların üstünde duran, çerçevesiz bir macOS video penceresi
(Swift + AppKit + WKWebView, SwiftPM ile derlenir; Xcode gerekmez).

## Kurulum

```sh
bash scripts/install.sh     # derler, ~/Applications/FloatPlayer.app olarak kurar ve açar
bash scripts/uninstall.sh   # kaldırır (--purge: ayarları ve çerezleri de siler)
bash scripts/make-app.sh    # sadece dist/FloatPlayer.app üretir
```

## Kısayollar (pencere seçiliyken; hepsi menü çubuğu menüsünde de var)

| Kısayol | İşlev |
| --- | --- |
| ⌘L | URL aç |
| ⇧⌘V | Panodaki bağlantıyı doğrudan aç |
| ⌘R | Yenile |
| ⌘P | Yalnız oynatıcıyı göster: sıradan sitelerde gömülü oynatıcı (ör. Close/Rapid) pencereyi doldurur; başka kaynak/bölüm seçmek için kapatın |
| ⌘W | Pencereyi gizle (menüden geri gösterilir) |
| ⌘] / ⌘[ | Saydamlık artır / azalt (%30–%100) |
| ⌘= / ⌘- | Yakınlaştır / uzaklaştır |
| ⌥⌘↓ / ⌥⌘↑ | Üst-alt siyah bantları kırp / kırpmayı azalt |
| ⌥⌘→ / ⌥⌘← | Yan siyah bantları kırp / kırpmayı azalt |
| ⌘0 | Yakınlaştırma ve kırpmayı sıfırla |
| ⌘K | En-boy oranı kilidini aç/kapat (varsayılan 16:9) |
| ⌘1 ⌘2 ⌘3 ⌘4 | Sol üst, sağ üst, sol alt, sağ alt köşeye yerleştir |
| ⌘Q | Çıkış |

Taşıma: üst kenara gelince çıkan çubuktan, boş alandan ya da ⌘ basılıyken herhangi bir yerden sürükleyin.

## Geliştirme

```sh
swift test                                                      # URL çevirme ve pencere geometrisi testleri (swift-testing)
swift run FloatPlayer --check "https://youtu.be/dQw4w9WgXcQ?t=42"  # videonun gerçekten oynadığını doğrular
swift run FloatPlayer --check "<url>" --no-referer               # Referer olmadan (Error 153'ü gösterir)
swift run FloatPlayer --check "<url>" --layout [--no-focus]      # sayfadaki oynatıcı pencereyi dolduruyor mu? (Tests/Fixtures içinde sahte sayfalar var)
```

## Lisans

[MIT](LICENSE)
