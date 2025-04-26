# Local Google Ads Strategy for Profile + YouTube Promotion

_Last updated: 2025‑04‑25_

## 1  Why a "Profile Feed"?

* **Scale** – advertise dozens/hundreds of fractional‑CFO profiles without hand‑writing ads.
* **Automation** – new/edited profiles flow into ads automatically.
* **Control** – enable/disable per‑profile with a simple boolean (`active_for_ads`).
* **Re‑use** – same feed powers Dynamic Search Ads, Performance Max feeds, and even free "Surfaces across Google".

---

## 2  Feed Specification

| Column (Google) | Populate with… | Notes |
|-----------------|----------------|-------|
| id | `profile.id` | Stable, unique |
| name | `profile.name` | Used in ad headlines |
| final_url | `https://<host>/profiles/#{slug}?utm_source=googleads` | Add UTM params |
| image_url | ActiveStorage headshot URL | 1:1 or 4:3 ratio |
| city | `profile.city` | Used for geo filtering |
| country | `profile.country` | Two‑letter ISO |
| specialization | comma‑list (`profile.specializations.pluck(:name)`) | For dynamic `{=specialization}` insertion |
| short_bio | first 120 chars of bio | Optional headline asset |
| youtube_url | full YouTube URL (primary episode) | For YouTube ad formats |
| active_for_ads | boolean | Marketing toggle (ignored by Google) |
| ranking_score | numeric | Your internal bidding weight |

Generate nightly as `/profiles/ad_feed.csv` or push to Google Sheets.

---

## 3  Low‑Cost Campaign Types

### 3.1  Dynamic Search Ads (Search Network)

* Feed linked via "Business Data" → page feeds.
* Google builds headlines like **"Fractional CFO – Dublin | Jane Doe"**.
* Maintain only 2‑3 generic descriptions.
* Bid strategy: _Maximise Clicks_ with CPC cap (e.g. €0.50).

### 3.2  Performance Max (Leads)

* Import feed in Merchant Center as a **Custom** feed.
* Asset group = **Finance Professionals**.
* Bonus: free placement across Discover, Gmail, Maps.

### 3.3  Local YouTube Ads (TrueView / In‑feed)

Use the same feed but reference the `youtube_url` field.

1. **Video Action Campaign (VAC)** – URL points back to profile; skippable in‑stream
   * Target radius ≈ 50 km around `city`.
   * Bidding: Target CPV €0.02‑€0.05.
2. **In‑Feed Video Ads** – appear in YouTube search for local queries
   * Headline "Hire a Fractional CFO in {{city}}".
   * Description from `short_bio`.

Tip: add **location extensions** so users see "Serves Dublin and nearby".

---

## 4  Geo & Budget Plan

| Region | Profiles | Daily Budget | CPC/CPV Cap |
|--------|----------|--------------|-------------|
| Ireland (Dublin) | 15 | €3 | €0.50 search / €0.03 video |
| UK (London + Manchester) | 30 | €5 | €0.60 / €0.04 |
| South Africa (Cape Town, Johannesburg) | 20 | €3 | €0.40 / €0.02 |

Start small, expand winners after 2–3 weeks.

---

## 5  Tracking & Optimisation

1. **Conversion events**
   * `guest_message_submitted` (contact form)
   * `email_click` on profile
   * Import into Google Ads via GA4/GTAG.
2. **UTM parameters** auto‑appended in feed.
3. **Automated negatives** – weekly script pulls Search‑Terms report, adds common non‑buyer queries (`salary`, `jobs`, `template`, etc.).
4. **ranking_score** field can feed bidding rules (e.g. raise 20 % for scores > 80).

---

## 6  Implementation Checklist

- [x] **DB Change** – add `active_for_ads:boolean` default false.
- [x] **Feed Endpoint** – `GET /admin/ads_feed.csv` (auth‑protected).
- [ ] **Cron/Job** – nightly regenerate feed & push to Google Cloud Storage.
- [ ] **Merchant Center / Business Data** – create feed, schedule daily fetch.
- [ ] **Campaigns**
  * DSA (Search), one per region.
  * VAC (YouTube) using `youtube_url` assets.
- [ ] **GTAG Conversions** wired & tested.
- [ ] **Report Automation** – weekly BigQuery dump → Slack summary.

---

## 7  Nice‑to‑Haves

* Auto‑generate **callout extensions** from `specialization` (e.g. "SaaS Finance", "E‑Commerce").
* Retarget site visitors with Display remarketing capped at €1/day.
* Expand to Microsoft Ads – same feed format works.

---

## 8  Estimated Results (per €150/month trial)

| Metric | Search Ads | YouTube Ads |
|--------|------------|-------------|
| Avg. CPC / CPV | €0.45 | €0.03 |
| Clicks / Views | ~250 | ~3 000 |
| CTR / View‑Rate | 4‑5 % | 18‑25 % |
| Form conversions (2 % CR) | ~5 | n/a (awareness) |

A quick, data‑driven way to get local eyeballs on each profile _and_ its episode video without heavy creative work.

---

## 9  Implementation Progress

### Completed
- ✅ Added database fields: `active_for_ads` boolean and `ranking_score` integer
- ✅ Added model methods to Profile:
  - `active_for_ads` scope for filtering
  - `ad_image_url` with fallbacks (ActiveStorage → headshot_url → placeholder)
  - `ad_final_url` with proper UTM parameters
  - `ad_specializations` for formatted specialization string
- ✅ Created Admin::AdsFeedController for CSV generation
- ✅ Added route for `/admin/ads_feed.csv` (authenticated)
- ✅ Created comprehensive test suite:
  - Unit tests for Profile model methods
  - Controller tests for AdsFeedController
  - Integration tests for the full feed workflow

### Next Steps
- Add scheduled job for nightly feed generation in recurring.yml
- Create storage integration for Google Cloud or external service
- Set up Google Merchant Center / Business Data feed
- Configure conversion tracking in GA4/GTAG