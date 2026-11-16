# JAYHUN TAXI — Kegeyli dispetcherlik tizimi

Professional taksi operatorlari va haydovchilari uchun mobil-first **React + TypeScript PWA**. Dizayn: oq ish maydoni, grafit navigatsiya, sariq faqat asosiy amallar uchun. **Demo yoki soxta akkaunt yo‘q.**

## Mijozning ish jarayoni

1. Mijoz operatorga telefon qiladi.
2. Operator yo‘nalish, telefon, yo‘lovchi soni, narx va izohni haqiqiy Supabase bazasiga yozadi.
3. Operator LiveKit umumiy ovoz xonasida buyurtmani e'lon qiladi.
4. ONLINE haydovchi ovoz orqali javob beradi yoki **OLAMAN** bosadi.
5. Operator haydovchini tanlaydi (bir vaqtda ikki operator bir buyurtmani taqsimlay olmaydi).
6. Haydovchi holatni yangilaydi: qabul qilindi → yo‘lda → mijoz olindi → bajarildi.
7. Buyurtma tarixi audit jadvallarida saqlanadi.

## Ilovada mavjud

- Faqat **haqiqiy Supabase email/parol autentifikatsiyasi**; xodimlarni admin yaratadi, roli/aktivligi bazadan tekshiriladi.
- Haydovchi: online/offline, ovoz, kelgan buyurtmalar va qabul qilish, o‘ziga biriktirilgan ishlar.
- Operator: joriy navbat, buyurtma yaratish, ovozli e'lon, haydovchilar, taqsimlash, bekor qilish va tarix.
- Admin: xodimlarni qo‘shish/bloklash, avtomobil ma’lumotlari, tarif va statistika.
- RLS himoyasi: haydovchi uchun mijoz telefoni yashiringan, rollar bo‘yicha server ruxsati.
- LiveKit WebRTC ovoz xonasi uchun kod va Supabase token Edge Function.
- Telefonda moslashuvchan PWA, mikrofon push-to-talk boshqaruvi.

## Ishlayotgan infratuzilma

**GitHub:** https://github.com/keta-comp/kegeyli-taxi  
**Vercel production:** https://kegeyli-taxi.vercel.app  
**Supabase:** project `duzeimbkgyjtgclwfstf` (real database, active Edge Functions).

GitHub Actions `npm run build` ni har commitda tekshiradi. Vercel GitHub `main` branchidan avtomatik deploy qiladi.

### Database migratsiyalari

Ushbu SQL fayllar ulangan Supabase loyihasiga o‘rnatilgan. Boshqa Supabase loyihaga o‘tkazilganda ketma-ket qo‘llang:

- `202611170001_initial.sql`
- `202611170002_security.sql`
- `202611170003_announcements.sql`
- `202611170004_hardening.sql`
- `202611170005_sanitized_driver_orders.sql`
- `202611170006_order_audit.sql`

3 Edge Function: `livekit-token`, `create-user`, `set-user-active`. Bular ulangan Supabase loyihasiga joylangan.

## Birinchi administrator — muhim yakuniy sozlama

Hozir Supabase Auth’da **birorta ham haqiqiy user yo‘q**. Tizim anonim kirishga ruxsat bermaydi; bu xavfsizlik talabidir.

1. Supabase Dashboard → Authentication → Users → Add user orqali faqat o‘zingizga tegishli email va kuchli maxfiy parol bilan birinchi administratorni yarating. Parolni chatga yubormang.
2. O‘sha foydalanuvchi **Auth UUID** sini oling.
3. SQL Editor’da quyidagi kodni haqiqiy UUID bilan ishga tushiring:

```sql
insert into public.profiles (id, name, role, active)
values ('PASTE_REAL_AUTH_USER_UUID', 'Administrator', 'admin', true)
on conflict (id) do update set role='admin', active=true;
```

4. JAYHUN TAXI saytidagi Login maydoniga shu emailni va parolni kiriting.
5. Admin panel orqali operatorlar va haydovchilarni yarating. Ularning loginlari `login@jayhun.local` ko‘rinishida Auth’da saqlanadi, UI’da loginning o‘zini kiritish mumkin.

Ushbu bootstrap **faqat ishonchli administrator tomonidan** bajarilishi kerak.

## LiveKit — mikrofonni haqiqiy ishlatish

LiveKit Cloud loyihasini yoki o‘zingizning LiveKit serveringizni yarating. Supabase Edge Functions Secrets’da quyidagi maxfiy o‘zgaruvchilarni yozing (repo yoki frontendga emas):

```text
LIVEKIT_URL=wss://YOUR-LIVEKIT-SERVER
LIVEKIT_API_KEY=...
LIVEKIT_API_SECRET=...
```

Token faqat login qilgan va faol foydalanuvchiga `JAYHUN_TAXI_MAIN_ROOM` uchun beriladi. Haydovchi xona uchun ONLINE bo‘lishi shart.

**Android ogohlantirish:** sof browser PWA’da ekran qulflanganda mikrofon/ovoz uzilmasligini kafolatlab bo‘lmaydi. Taksistlarga tarqatishdan avval ekran o‘chganda va tarmoq almashganda test qiling. Kafolatlangan background audio kerak bo‘lsa Android native foreground service/Capacitor integratsiyasi bilan alohida versiya kerak bo‘ladi.

## Lokal ishga tushirish

```bash
npm install
cp .env.example .env.local
npm run dev
npm run build
```

Windows PowerShell: `Copy-Item .env.example .env.local`.

`.env.local`da faqat public browser environment: `VITE_SUPABASE_URL` va `VITE_SUPABASE_ANON_KEY` (publishable key). **Hech qachon** `service_role` yoki LiveKit secretni `VITE_` orqali bermang.

## Production release mezonlari

- [x] Demo va soxta buyurtmalar olib tashlangan
- [x] Real bazaga ulangan login, xodim va buyurtma kodlari
- [x] Mobil-first oq/grafit/sariq dizayn
- [x] Audit log, RLS va role-check
- [x] GitHub build hamda Vercel deploy
- [ ] Birinchi haqiqiy admin Auth akkauntini yaratish
- [ ] LiveKit Cloud/hosted hisobini va server-side secretlarni sozlash
- [ ] Real operator/haydovchi bilan end-to-end buyurtma sinovi
- [ ] Real Android qurilmalarda mikrofonga ruxsat, qulf ekran, reconnect, Bluetooth testlari
- [ ] Security advisor’dagi 5 autentifikatsiyalangan SECURITY DEFINER RPCni mustaqil audit qilish
- [ ] Accessibility, monitoring, parolni tiklash, trafik va stress test

**Bu demo emas, lekin hali to‘liq production sertifikatsiyasidan o‘tgan taksi xizmati ham emas.** Hisoblar va LiveKit bog‘lanmaguncha real taksi amaliyotiga chiqarilmaydi.
