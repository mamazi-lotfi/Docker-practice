# Docker Practice Project

پروژه‌ی تمرینی یادگیری Docker — پیاده‌سازی یک زیرساخت کامل و به‌هم‌پیوسته شامل رجیستری خصوصی، مانیتورینگ، سه اپلیکیشن واقعی، و Orchestration با Docker Swarm.

## معرفی کلی

این پروژه روی یک سرور اختصاصی (Ubuntu) پیاده‌سازی شده و شامل ۶ تمرین اصلی است که هرکدام روی تمرین قبلی سوار می‌شوند. همه‌ی سرویس‌ها (به‌جز موارد صراحتاً استثنا شده) ایمیج‌شان از **رجیستری خصوصی خودِ پروژه** کشیده می‌شود، نه مستقیم از Docker Hub.

### اصول طراحی رعایت‌شده در کل پروژه

- **حداقل سطح دسترسی شبکه**: فقط پورت‌های ۲۲ (SSH)، ۸۰ و ۴۴۳ از سرور به بیرون باز هستند (با iptables).
- **تک‌نقطه‌ی ورودی (Single Entry Point)**: یک کانتینر nginx یکپارچه، با Virtual Hosting بر پایه‌ی دامنه، همه‌ی ترافیک HTTPS ورودی را مسیریابی می‌کند.
- **تفکیک شبکه‌ای (Network Segmentation)**: هر پشته‌ی اپلیکیشن (WordPress، Vote App) شبکه‌ی Docker مجزای خودش را دارد؛ لایه‌ی دیتابیس هرگز مستقیماً از لایه‌ی وب در دسترس نیست.
- **جداسازی Secret از کد**: تمام پسوردها و مقادیر حساس در فایل `.env` (خارج از گیت) نگه‌داری می‌شوند، نه هاردکد در `docker-compose.yml`.
- **ماندگاری داده (Persistence)**: داده‌ی تمام سرویس‌های stateful (رجیستری، Elasticsearch، MySQL) با bind mount روی دیسک هاست خارج شده است.

---

## ساختار کلی سرور

```
~/train/Docker/
├── registry-setup/          ← پروژه‌ی اصلی (docker-compose.yml مرکزی)
│   ├── auth/                ← htpasswd رجیستری
│   ├── data/                ← داده‌ی رجیستری
│   ├── elk/                 ← کانفیگ Filebeat / Metricbeat / Heartbeat
│   ├── nginx-unified/       ← Dockerfile + کانفیگ + گواهی nginx یکپارچه
│   ├── wordpress/           ← داده و nginx اختصاصی WordPress
│   └── .env                 ← تمام رمزهای عبور (خارج از گیت)
└── vote-app/                ← سورس Vote App + docker-stack.yml (Swarm)
```

---

## پیش‌نیاز: زیرساخت پایه

### فایروال (iptables)
- Policy پیش‌فرض `INPUT`/`FORWARD`: `DROP`
- فقط ۲۲ (SSH)، ۸۰، ۴۴۳ مجاز
- قوانین با `iptables-persistent` پایدار شده‌اند
- Chain اختصاصی `DOCKER-USER` برای کنترل دسترسی به کانتینرهای publish‌شده (نکته‌ی مهم: قوانین معمولی `INPUT` روی ترافیک منتشرشده‌ی داکر اثر ندارند چون از مسیر `FORWARD` رد می‌شود)

### کانفیگ دیمون داکر (`/etc/docker/daemon.json`)
- Registry Mirror برای پول‌های Docker Hub
- `bip` و `default-address-pools` سفارشی (جلوگیری از تداخل شبکه‌ای بین پروژه‌های چندشبکه‌ای)
- محدودیت لاگ کانتینر: `max-size: 10m`, `max-file: 5`

---

## تمرین ۱: رجیستری خصوصی Docker

| سرویس | نقش | دسترسی |
|---|---|---|
| `registry` (Registry v2) | ذخیره‌سازی ایمیج‌ها | داخلی، `127.0.0.1:5000` |
| `registry-ui` (joxit) | مرور ایمیج‌ها/تگ‌ها | از طریق `https://registry.local` |

- **Authentication**: htpasswd چندکاربره
- **SSL**: گواهی self-signed، ترمینیت روی nginx
- **Backup**: اسکریپت روزانه (cron) با نگهداری ۷ روزه

---

## تمرین ۲: ELK Stack

| سرویس | نقش |
|---|---|
| Elasticsearch | ذخیره و ایندکس‌گذاری داده (داخلی، بدون TLS چون فقط شبکه‌ی داخلی داکر) |
| Kibana | داشبورد و تحلیل، پشت `https://kibana.local` |
| Metricbeat | متریک CPU/RAM/دیسک هاست + هر کانتینر (هر ۳۰ ثانیه) |
| Filebeat | ارسال لاگ سیستم + لاگ خام همه‌ی کانتینرها |
| Heartbeat | مانیتور uptime (گوگل، گیت‌هاب، کیبانای داخلی) |

**نکته‌ی امنیتی مهم**: اتصال Kibana به Elasticsearch از طریق Service Account اختصاصی (`kibana_system`) انجام می‌شود، نه با کاربر سوپریوزر `elastic`.

**نکته‌ی عملیاتی**: مدیریت فضای دیسک یکی از چالش‌های اصلی این بخش بود؛ ایندکس‌های Beats با ILM/replica-zero کنترل حجم می‌شوند تا در محیط تک‌نودی، فضای دیسک به‌خاطر replica های بی‌مصرف قفل نشود.

---

## تمرین ۳: WordPress

معماری سه‌لایه با تفکیک شبکه‌ای واقعی:

```
اینترنت → nginx (web) → WordPress-FPM (app) → MySQL (db)
```

| شبکه | اعضا |
|---|---|
| `db-net` | MySQL + WordPress |
| `app-net` | WordPress + nginx |

- MySQL هرگز مستقیماً از nginx در دسترس نیست.
- ایمیج nginx با **Dockerfile سفارشی** ساخته شده (کانفیگ و گواهی SSL baked-in، نه mount در runtime).
- بکاپ روزانه‌ی دیتابیس با `mysqldump` + `gzip` + cron.
- در دسترس از `https://wordpress.local`.

---

## تمرین ۴: Vote App (Microservices)

پروژه‌ی نمونه‌ی رسمی Docker (`dockersamples/example-voting-app`)؛ همه‌ی ایمیج‌ها از سورس build و به رجیستری خصوصی push شده‌اند.

| سرویس | تکنولوژی | نقش |
|---|---|---|
| `vote` | Python/Flask + Gunicorn | رابط رأی‌دادن، `https://vote.local` |
| `redis` | Redis | صف موقت رأی‌ها |
| `worker` | .NET | انتقال رأی از Redis به Postgres |
| `db` | PostgreSQL | ذخیره‌ی نهایی نتایج |
| `result` | Node.js + Socket.IO | نمایش زنده‌ی نتایج، `https://result.local` |

شبکه‌ها: `vote-front-net` (فقط nginx↔vote/result) و `vote-back-net` (پشت‌صحنه).

---

## تمرین ۵: Portainer

مدیریت گرافیکی داکر، پشت `https://portainer.local`، بدون هیچ پورت مستقیم روی هاست (فقط از طریق nginx). دسترسی به `docker.sock` برای مدیریت کامل کانتینرها/ایمیج‌ها/شبکه‌ها از طریق UI.

---

## تمرین ۶: Docker Swarm

پیاده‌سازی جداگانه از Vote App روی حالت Swarm (`~/train/Docker/vote-app/docker-stack.yml`) برای نمایش مفاهیم Orchestration:

- **Service** به‌جای کانتینر تکی
- **Replica**: سرویس `vote` با ۳ نسخه‌ی هم‌زمان (قابل Scale زنده تا ۵ نسخه بدون داون‌تایم)
- **Overlay Network** برای ارتباط بین سرویس‌ها
- **Routing Mesh**: توزیع خودکار ترافیک بین replica ها بدون نیاز به لود بالانسر جداگانه
- **Placement Constraint**: پین کردن سرویس دیتابیس به نود Manager

دیپلوی مستقل از `docker-compose.yml` اصلی، روی پورت‌های ۸۰۸۰/۸۰۸۱، تا با nginx یکپارچه‌ی پروژه تداخل نداشته باشد.

```bash
docker stack deploy -c docker-stack.yml vote-stack
docker stack services vote-stack
docker service scale vote-stack_vote=5
```

---

## نحوه‌ی اجرا (برای بازبینی)

> ⚠️ فایل‌های حساس (`.env`, `auth/htpasswd.txt`, گواهی‌های `.key`) عمداً در گیت نیستند. برای اجرای کامل باید طبق نمونه‌های `.env.example` و `auth/htpasswd.txt.example` مقداردهی شوند.

```bash
cd registry-setup
cp .env.example .env   # و مقداردهی رمزهای واقعی
docker compose up -d
```

دامنه‌های مورد نیاز در `/etc/hosts`:
```
127.0.0.1   registry.local
127.0.0.1   kibana.local
127.0.0.1   wordpress.local
127.0.0.1   vote.local
127.0.0.1   result.local
127.0.0.1   portainer.local
```

---

## خلاصه‌ی یادگیری

این پروژه صرفاً اجرای دستورات نبود؛ بخش عمده‌ی یادگیری از **حل مشکلات واقعی** به دست آمد:

- درک تفاوت `INPUT` و `FORWARD` در iptables هنگام کار با داکر
- تصادم پورت هاست و راه‌حل معماری صحیح آن (nginx یکپارچه با Virtual Hosting)
- مدیریت بحران فضای دیسک (چه از build cache داکر، چه از انباشت لاگ در Elasticsearch)
- محدودیت‌های امنیتی سرویس‌های واقعی (کاربر `elastic` ممنوع برای Kibana، هاردکد بودن کانفیگ دیتابیس در Vote App)
- تفاوت بنیادین بین اجرای تک‌سروری (Compose) و Orchestration واقعی (Swarm)
