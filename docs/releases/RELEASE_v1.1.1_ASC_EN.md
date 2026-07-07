# おてつだいコイン v1.1.1 — App Store Connect English Localization Draft

This document collects the **English-locale text drafts** for the v1.1.1 ASC listing (Issue [#50](https://github.com/es0612/OtetsudaiCoin/issues/50) Phase 1). All copy is **draft only** — author/PO should spot-review and adjust tone before pasting into ASC.

- **Target audience (per #50 decision, 2026-05-23)**: Japanese-speaking families abroad / bilingual households. The app's currency is fixed to ¥ (JPY), so the English copy intentionally signals "Japanese-speaking household tool" rather than positioning as a generic English-market chores app.
- **Ship gate**: App build is unaffected; only ASC localization metadata is added. The English locale can be saved on ASC without resubmitting v1.1.1.
- **Scope**: Sections 1.2 / 1.3 / 1.4 / 1.6 from #50 Phase 1, plus App Name / Subtitle that ASC requires when adding a new locale. Section 1.5 (English-locale screenshots) is deferred to a follow-up using [[ios-simulator-locale-testing]].
- **No emojis in the en locale** (Issue #85): ASC's automated review rejects emojis in the English Description / What's New text fields. All en drafts in this document use plain text only. The Japanese locale (`RELEASE_v1.1.1.md`) is unaffected and keeps its emoji conventions.

## 1. App Name (アプリ名)

ASC field: **App Name** — up to 30 characters. Required when adding a new locale.

```text
Otetsudai Coin
```

Character count: **14 chars** (within 30). 16 chars headroom.

### Notes / review points

- Keeps the romanized product name. Matches "Otetsudai Coin" used throughout the Description and What's New copy below.
- Alternative options if the PO prefers a more descriptive name:
  - `Otetsudai Coin: Family Chores` (29 chars) — explicit category hint
  - `OtetsudaiCoin` (13 chars) — matches the Bundle ID style (`com.asapapalab.OtetsudaiCoin`)
- Decision should be **made before pasting** because Apple makes App Name changes painful (requires new version submission to alter).

## 2. Subtitle (サブタイトル)

Source: Japanese subtitle `子どもとつくる、お手伝い習慣` (RELEASE_v1.1.1.md § 1.3).

ASC field: **Subtitle** — up to 30 characters. Required when adding a new locale.

```text
Build chore habits with kids
```

Character count: **28 chars** (within 30). 2 chars headroom.

### Notes / review points

- Mirrors the action-oriented framing of the Japanese ("つくる" → "Build") and the inclusivity of the relationship ("子どもとつくる" → "with kids").
- Alternative subtitles, all within 30 chars:
  - `Family chores, made together` (28) — emphasizes family
  - `Track chores, build allowance` (29) — emphasizes the allowance loop
  - `Chores & allowance for kids` (27) — most descriptive, least emotive
- "kids" is plural intentionally; the app supports multiple children.

## 3. Description (説明文)

Source: Japanese version in `RELEASE_v1.1.0.md` § 2.3 (still current for v1.1.1).

ASC field: **Description** — up to 4000 characters.

```text
A fun way to support your child's chores at home — together as a family.

[Main features]
- Record chores with a single tap and earn coins
- Register multiple children, each with a personal theme color
- Customize the list of chores to match your home
- Monthly history view with automatic allowance calculation
- Monthly Retrospective screen — celebrate effort as a family
- Backdate entries when you forget to log right away

[What makes it different]
- Simple, child-friendly design
- Coin animations and sound effects to keep kids motivated
- Fully offline — no internet connection required
- All data stays on your device only

Note for international users:
Otetsudai Coin is designed primarily for Japanese-speaking families.
The user interface is available in English, but the allowance amount
is displayed in Japanese yen (¥) only. The app is well suited for
Japanese families living abroad and bilingual households who want to
maintain a Japanese-style chores-and-allowance routine.

Help your child build great habits and bring your family closer — one chore at a time!
```

### Notes / review points

- **Currency disclosure** is placed near the end so the value props land first. Trade-off: moving it to the top reduces "wrong-currency" review complaints but pushes the value props down. PO call.
- Uses the App Name decided in § 1 (`Otetsudai Coin`). Swap if § 1 changes.
- **Emojis are removed in the en locale** — ASC's automated check rejects emojis in the English Description / What's New text (Issue #85, confirmed 2026-05-23). The Japanese locale still accepts emojis, so `RELEASE_v1.1.1.md` の日本語 draft は触らない。

## 4. Keywords (キーワード)

Source: Japanese keywords `おてつだい,お小遣い,記録,子供,家事,習慣,しつけ,家族` (RELEASE_v1.1.1.md § 1.3).

ASC field: **Keywords** — up to 100 characters, comma-separated, **no spaces after commas** (ASC strips them anyway — packing more keywords).

```text
chores,allowance,kids,family,habit,routine,Japanese,bilingual,record,parenting
```

Character count: **78 chars** (within 100). 22 chars headroom.

### Notes / review points

- App name "Otetsudai Coin" is auto-indexed by Apple — **do not** include it as a keyword (waste of slot).
- `Japanese` + `bilingual` deliberately signal the target audience (per #50 decision: in-search hits from Japanese-speaking families abroad searching for "Japanese chores app" or "bilingual household").
- `parenting` is the broadest catch-all; could be dropped for `homeschool` if homeschool families are a known segment.
- Avoid trademark keywords (e.g. competitors' app names).

## 5. Promotional Text (プロモーションテキスト)

Source: Japanese v1.1.1 promo (RELEASE_v1.1.1.md § 2.2).

ASC field: **Promotional Text** — up to 170 characters. Editable after submission without re-review.

```text
Stable home screen + English UI support. A great fit for Japanese-speaking families abroad and bilingual households building chores-and-allowance habits together.
```

Character count: **162 chars** (within 170). 8 chars headroom.

### Notes / review points

- Front-loads the v1.1.1 value props ("stable home screen + English UI") so existing users see the update reason in the App Store update tab.
- Mirrors the Japanese tone of "海外暮らしのご家族や英語で育児するご家庭でも" by spelling out the target families explicitly.

## 6. What's New for v1.1.1 (このバージョンの新機能)

Source: Japanese **Draft A — emoji-friendly version** from RELEASE_v1.1.1.md § 2.1.

ASC field: **What's New in This Version** — up to 4000 characters. The first ~170 characters show in the App Store update tab before the "more" toggle, so the value summary is up top.

```text
Version 1.1.1 brings a more stable home screen and improved English support.

Bug fixes
- Fixed an issue where your children's cards and stats sometimes failed to appear the first time the Home screen opened.
- Fixed the "Version" row on the Settings screen so it now shows the current version (1.1.1) correctly instead of an outdated number.

Improved English support
- Tab labels (Home / Record / Settings), the Retrospective screen, each section of the Settings screen, notification settings, and the body text of reminder notifications now display naturally in English.

Thank you for using Otetsudai Coin — we hope you keep enjoying it together with your family!
```

Leading summary line is **76 chars** — fits comfortably in the App Store "before more" window (~170 chars).

### Notes / review points

- **Section headers are plain text (no emojis)** in the en locale per Issue #85. The Japanese version keeps the 🐛 / 🌍 emoji ordering; the en draft mirrors only the ordering, not the emojis.
- Mentioning `1.1.1` in the Settings bug fix mirrors the Japanese text and helps users verify after updating.
- For v1.1.2 onward, follow the **Phase 2** pattern in #50: append a `## What's New (English)` section to the new `RELEASE_v1.1.2.md` and run the same draft → spot-review → ASC paste flow.

## 7. ASC paste-in checklist (Phase 1 wrap-up)

This is the work the **author/PO must do in the ASC UI** to finish Phase 1 (#50 § 1.1, 1.7).

- [ ] ASC → My Apps → おてつだいコイン → Localizations → **Add Language: English (U.S.)**
- [ ] Paste § 1 (App Name) into the new English locale
- [ ] Paste § 2 (Subtitle) into the new English locale
- [ ] Paste § 3 (Description) into the new English locale
- [ ] Paste § 4 (Keywords) into the new English locale
- [ ] Paste § 5 (Promotional Text) into the new English locale
- [ ] Paste § 6 (What's New for v1.1.1) into the new English locale
- [ ] Save the English locale (no version resubmission needed — locale add is metadata)
- [ ] Capture English-locale screenshots and upload to ASC
  - Source PNGs (撮影済み、Issue #50 Phase 1 § 1.5):
    - [`docs/screenshots/asc/v1.1.x/en/01-home.png`](../screenshots/asc/v1.1.x/en/01-home.png)
    - [`docs/screenshots/asc/v1.1.x/en/02-record.png`](../screenshots/asc/v1.1.x/en/02-record.png)
    - [`docs/screenshots/asc/v1.1.x/en/03-settings.png`](../screenshots/asc/v1.1.x/en/03-settings.png)
  - Reference (ja 同条件撮影): `docs/screenshots/asc/v1.1.x/ja/` 配下 3 枚
  - 撮影手順: `./scripts/capture-asc-screenshots.sh` (再撮影時)

## 8. Related

- Issue: [#50](https://github.com/es0612/OtetsudaiCoin/issues/50)
- Source Japanese drafts: [`RELEASE_v1.1.1.md`](./RELEASE_v1.1.1.md) § 1.3 / § 2.1 / § 2.2 / § 2.3
- Skill: [[ios-simulator-locale-testing]] (for § 1.5 screenshot deferred task)
- Future integration: Phase 2 of #50 — incorporate the English What's New draft step into `RELEASE_v1.1.2.md` and subsequent release docs.
