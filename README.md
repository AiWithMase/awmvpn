# awmvpn

کلاینت VPN رایگان و متن‌باز برای ویندوز، مک، لینوکس و اندروید. ترافیک را روی
HTTP/2 و HTTP/3 از شبکهٔ Fastly عبور می‌دهد و هر اشتراک ۵۰ گیگابایت در ماه
دارد. چند اشتراک کنار هم جمع می‌شوند و وقتی حجم یکی تمام شود، برنامه خودش به
اشتراک بعدی می‌رود.

> **بدون ثبت‌نام در برنامه.** این نسخهٔ awmvpn با سرویس awmvpn کار می‌کند:
> توکن اشتراک را ربات تلگرام می‌دهد و برنامه همان را به یک اکانت آماده تبدیل
> می‌کند. هیچ فرم ورود یا ثبت‌نامی در برنامه نیست.

## شروع

1. در تلگرام به [@awmvpn_bot](https://t.me/awmvpn_bot) پیام بدهید.
2. دستور `/token` را بفرستید تا یک توکن بگیرید (هر درخواست یک توکن).
3. برنامه را باز کنید، به **اشتراک‌ها** بروید و **فعال‌سازی** را بزنید.
4. توکن، یا کل پیام ربات، را بچسبانید. اکانت اضافه می‌شود و تا تاریخ پایان
   توکن کار می‌کند.

هر زیرمجموعه (دعوت دوستان با `/ref`) یک جایگاه اشتراک بیشتر می‌دهد. با
`/revoke` همهٔ توکن‌های فعال لغو می‌شوند و برنامه هم در اولین بررسی، اکانت آن‌ها
را حذف می‌کند. پس از پایان تاریخ توکن، اکانت حذف می‌شود و برای ادامه باید
توکن تازه بگیرید.

## امکانات

- **چند اشتراک:** هر توکن یک اکانت و حجم ماهانهٔ خودش را دارد.
- **مسیریابی مستقیم:** سایت‌های ایران بدون VPN باز می‌شوند (سریع‌تر و
  کم‌مصرف‌تر).
- **حالت TUN و پروکسی:** همهٔ برنامه‌ها یا فقط برنامه‌هایی که خودتان انتخاب
  می‌کنید.
- **تم شب:** رابط تیرهٔ بنفش‌مشکی، فارسی‌محور و راست‌به‌چپ.
- **چند زبانه:** فارسی، انگلیسی، عربی، ترکی، روسی، چینی و چند زبان دیگر.

## ساخت از سورس

پیش‌نیازها: Go 1.24+، Flutter 3.47+، و برای اندروید JDK 17 و Android SDK.

```sh
# هستهٔ Go
cd core
go test ./...
go build ./cmd/awmvpn-core

# برنامهٔ Flutter
cd ../app
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

اسکریپت‌های ساخت در `scripts/` هستند (`build-windows.ps1`،
`build-linux.sh`، `build-macos.sh`، `build-android.ps1`).

## ساختار

- `app/` — برنامهٔ Flutter (رابط، بومی‌سازی، اشتراک‌ها).
- `core/` — هستهٔ Go (پروکسی، اکانت‌ها، TUN، داشبورد محلی).
- `brand/` — نشان و آیکون‌ها.
- `scripts/` — ساخت و انتشار.
- `docs/` — راهنمای OpenWrt و جزئیات.

## مجوز

این برنامه نرم‌افزار آزاد است، تحت **GNU GPL v3**. متن کامل در
[LICENSE](LICENSE) و یادداشت‌های حق نسخه‌برداری در [NOTICE](NOTICE) است.
awmvpn بر پایهٔ [Firefox VPN](https://github.com/armanlife/firefox-vpn-client)
ساخته شده و کلاینت غیررسمی است؛ وابسته به Mozilla نیست.

---

**English.** awmvpn is a free, open-source VPN client for Windows, macOS,
Linux, and Android. Subscriptions come from the [@awmvpn_bot](https://t.me/awmvpn_bot)
Telegram bot: send `/token`, then paste the token into the app's
**Subscriptions** page. There is no sign-in or sign-up form in the app. Each
subscription carries its own monthly allowance; several can be active at once.
Built with Flutter and a Go core, licensed under GPL-3.0. See
[LICENSE](LICENSE) and [NOTICE](NOTICE).
