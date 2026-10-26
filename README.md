# Glint: AI Search Browser

An iPhone browser built to catch Arc Search users when its AI features shut off on
**November 23, 2026**. Search for Me answers and page summaries are written by Apple's
on-device model, so each answer costs nothing to serve and a $4.99 one-time price works.

## What's in here

```
project.yml                 XcodeGen spec (generates Glint.xcodeproj)
Glint/App/                  App entry point, settings
Glint/Browser/              Tabs, auto-archive, web view, home, search bar, ad blocking
Glint/AI/                   Search for Me pipeline, page reader, on-device generation, answer UI
Glint/Store/                $4.99 lifetime unlock (StoreKit 2), 5 free AI uses a day, paywall
Glint/Settings/             Settings, Arc tab import, archive
Glint/Resources/            Icon, accent color, ad/tracker blocklist, privacy manifest
marketing/AppStoreListing.md  Name, subtitle, description, keywords, IAP setup, screenshot plan
landing/                    Landing page + privacy policy (host on GitHub Pages)
```

## How Search for Me works

1. `WebSearch` loads DuckDuckGo's HTML results page in an off-screen web view and pulls out the organic links.
2. `PageReader` loads the top 4 pages at once (8-second limit each) and extracts the article text.
3. `Excerpt` keeps the paragraphs that match the question, within a character budget. The on-device
   model's context is about 4,000 tokens, so this step decides answer quality.
4. `AI.answer` asks the model for a structured `BrowseAnswer` (headline, cited points, follow-ups).
   If the prompt is too long it retries with shorter excerpts.

Phones without Apple Intelligence still get the browser, ad blocking and the source list.

## Get it running (about 15 minutes)

You need a Mac with **Xcode 26 or later** and an **Apple Developer Program** membership.

```bash
brew install xcodegen
cd Glint
xcodegen            # creates Glint.xcodeproj
open Glint.xcodeproj
```

1. Target **Glint → Signing & Capabilities**: pick your team. Change the bundle ID
   (`com.example.glint`) to your own, in `project.yml` too.
2. Change `Purchases.proProductID` to `<your bundle ID>.pro.lifetime`.
3. Test the purchase locally: **File → New → File → StoreKit Configuration File**, add a
   non-consumable with that product ID at $4.99, then **Product → Scheme → Edit Scheme → Run →
   Options → StoreKit Configuration** and select it.
4. Run on an iPhone 15 Pro or newer with Apple Intelligence on. The Simulator also runs the
   on-device model if your Mac runs macOS 26 with Apple Intelligence turned on.

This code was written without a compiler at hand, so expect a handful of small fixes on the
first build (typically SDK signature details). Paste the errors into Claude and they're quick.

## Ship plan to beat November 23

| When | What |
|---|---|
| **Today, Oct 26** | Enroll in the Apple Developer Program if you aren't (approval can take 1–2 days). Publish `landing/` on GitHub Pages so AI assistants can start finding it. |
| Oct 27 | App Store Connect: create the app record and the $4.99 non-consumable (see `marketing/AppStoreListing.md`). |
| Oct 27–31 | First build, fix compile errors, test on a real iPhone: answers, summaries, purchase, restore, import. |
| Nov 2–6 | TestFlight with a few friends. Take the five screenshots. |
| **Nov 9** | Submit for review. The IAP must be submitted together with this first build. |
| Nov 10–16 | Fix any rejection and resubmit. Release as soon as it's approved. |
| Nov 16–23 | Post in r/ArcBrowser and Arc threads on X and Mastodon: "Lost Browse for Me? Here's an on-device replacement." Update the landing page's App Store link. |

## Known limits and the next things to add

- **Search source.** DuckDuckGo's HTML page isn't an official API and could rate-limit or
  change its markup. Everything lives in `WebSearch.swift`; swap in a paid search API there if needed.
- **Default browser.** Becoming the default browser needs Apple's `com.apple.developer.web-browser`
  entitlement, which you request from Apple. Worth doing after launch.
- **Pinch to summarize.** Summarize is the sparkles button for now; a pinch gesture would fight the
  page's own zoom.
- **Tab thumbnails** (`WKWebView.takeSnapshot`) would make the home grid look closer to Arc's.
