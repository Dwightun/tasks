# Привычки

Минималистичный трекер привычек для iPhone: заводишь привычку, задаёшь периодичность,
отмечаешь выполнение в приложении или прямо с виджета на экране «Домой».

- `ios/` — нативное приложение (SwiftUI, iOS 17+) и интерактивный виджет (WidgetKit + App Intents)
- `web/` — ранний веб-прототип (PWA)

Xcode-проект не хранится в репозитории: он генерируется из `ios/project.yml` через
[XcodeGen](https://github.com/yonaskolb/XcodeGen). Сборка идёт в GitHub Actions на macOS
(`.github/workflows/ios.yml`):

- на каждый push и PR — проверочная сборка под симулятор;
- на push в `main` (или ручной запуск) — подпись и загрузка в TestFlight, если настроены секреты ниже.

## Настройка подписи и TestFlight

Идентификаторы, которые использует проект:

| Что | Значение |
|---|---|
| App Group | `group.com.dwightun.track` |
| Приложение | `com.dwightun.track` |
| Виджет | `com.dwightun.track.widget` |
| Профиль приложения | `Track AppStore` |
| Профиль виджета | `Track Widget AppStore` |

Если какой-то bundle ID уже занят, поменяйте его в `ios/project.yml`,
`ios/ExportOptions.plist` и `ios/Shared/HabitStorage.swift`.

### developer.apple.com → Certificates, Identifiers & Profiles

1. **Identifiers → + → App Groups** → `group.com.dwightun.track`.
2. **Identifiers → + → App IDs → App** → Explicit `com.dwightun.track`, включить **App Groups**,
   нажать *Configure* и выбрать группу из п.1.
3. То же самое для `com.dwightun.track.widget`.
4. **Certificates → + → Apple Distribution** → загрузить CSR-файл → скачать `.cer`.
5. **Profiles → + → App Store Connect** → App ID `com.dwightun.track` → сертификат из п.4 →
   имя **`Track AppStore`** → скачать. Повторить для виджета с именем **`Track Widget AppStore`**.

### appstoreconnect.apple.com

6. **Apps → + → New App**: iOS, bundle ID `com.dwightun.track`, любой SKU.
   Имя должно быть уникальным во всём App Store.
7. **Users and Access → Integrations → Team Keys → +**, роль *App Manager*.
   Скачать `.p8` (скачивается только один раз), записать *Key ID* и *Issuer ID*.

### GitHub → Settings → Secrets and variables → Actions

| Секрет | Откуда |
|---|---|
| `DEVELOPMENT_TEAM` | Team ID: developer.apple.com → Membership details |
| `DIST_CERT_P12_BASE64` | сертификат из п.4 + приватный ключ, упакованные в `.p12`, в base64 |
| `DIST_CERT_PASSWORD` | пароль от `.p12` |
| `APP_PROFILE_BASE64` | профиль `Track AppStore` в base64 |
| `WIDGET_PROFILE_BASE64` | профиль `Track Widget AppStore` в base64 |
| `ASC_KEY_ID` | Key ID из п.7 |
| `ASC_ISSUER_ID` | Issuer ID из п.7 |
| `ASC_KEY_P8` | содержимое `.p8` из п.7 |

После этого каждый push в `main` публикует сборку в TestFlight. Установка — через
приложение TestFlight на iPhone (себя нужно добавить во внутреннюю группу тестирования).
