# App Store Connect — Notes for Review (English)

Paste the **Reviewer Summary** and **Test Account** sections into App Store Connect → App Review Information → Notes.

## Reviewer summary

**DAHA** is a **daily habit and action-tracking app**, not a quote-only reader. Motivational content is the trigger; **core utility** is logging **what the user did that day** (“daily action”), maintaining **streaks/chains**, **badges/social points**, **home screen widget**, and optional **scheduled notifications** (iOS via APNs). **Sign in with Apple** and **Google** are optional and unlock sync, comments, and server-backed progress.

**User-generated content:** Comments are optional. Users can **report** comments (spam, abuse, inappropriate, other) and **block** authors from the **⋮** menu on each comment. Reports are stored server-side for moderation.

**Account deletion:** **Profile → Hesabı sil (Delete account)** performs in-app account deletion (server soft-delete) and signs the user out, per Apple’s account deletion requirement.

**First launch:** A short **3-page onboarding** explains action logging, streaks/badges, and community safety.

---

## Demo / test account

Replace with your real reviewer credentials before submit:

- **Email:** `reviewer@yourdomain.com`  
- **Password:** `(set in your backend / OAuth — if using Sign in with Apple, prefer providing a Google test account or a backend test user as documented in your setup)`  

If you only support Sign in with Apple / Google, state clearly:

- **“Please use Sign in with Apple on device; test Apple ID: …”** or  
- **“Please use Google sign-in; test Google account: …”**

---

## Step-by-step for reviewer

1. **Launch app** — complete or skip onboarding (Skip = “Geç”). Land on **Home**.
2. **Without login:** Browse **Home** (“Günün İçeriği”), open an item, scroll to comments.
3. **Home — core flow:** On Home, scroll to **“Bugünkü alışkanlığın”** — enter text under **“Bugün bu sözle ne yaptın?”** and tap **Aksiyon Ekle** (may prompt login / sync consent when signed in).
4. **Sign in:** **Profile → Giriş Yap** — **Sign in with Apple** (preferred on iOS) or Google.
5. **After login:** Repeat action logging; open **Profile → Zincir** (chain icon in top bar) or **“Zincir ve rozetlerini gör”** on Home; open **badges/social points** from Profile.
6. **Comments / UGC:** Open any content with comments. **Long-press or use ⋮** on another user’s comment → **Raporla** or **Kullanıcıyı engelle**.
7. **Account deletion:** **Profile → Hesabı sil** — confirm twice; user is signed out.
8. **Widget:** Add **DAHA** home screen widget; confirm it shows daily content after app has loaded data.
9. **Notifications:** Allow notifications when prompted; confirm a daily reminder can be scheduled from app settings if applicable.

---

## Technical notes

- Backend: REST API (Go + PostgreSQL). App is configured with `API_BASE_URL` at build/run time.
- Push on iOS: **APNs** (not FCM inside the app). Android may not mirror all push behavior; reviewer focus is typically iOS for push.
- If review environment needs a **specific API base URL**, document it here for your team (do not expose secrets in public repos).
