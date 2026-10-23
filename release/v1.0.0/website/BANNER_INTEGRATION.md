# Responsive Nyx PC Checkup hero — web deployment guidance

Version **1.0.0**. These SVGs are **original decorative marketing graphics**, not literal application screenshots. All promises, titles and download actions belong in accessible live HTML rather than baked into a raster screenshot.

## Responsive assets

- `hero-mobile.svg`: scalable mobile-first portrait art, **viewBox 720 × 960**, reserved dark space at top for live title/buttons
- `hero-desktop.svg`: scalable desktop-wide art, **viewBox 1440 × 720**, empty left area for live title/buttons
- Both include no scripts, network dependencies, fonts, external URLs, or text that could become inaccurate.
- SVG is resolution-independent, crisp on Retina displays. Serve with `Content-Type: image/svg+xml`. Cache versioned paths (e.g. `/assets/nyx-pc-checkup/v1.0.0/hero-mobile.svg`) and preserve the prior asset if an equivalent acceptable hero is already live.

## Embed in existing site hero (not a second duplicate hero)

Use the existing site heading/download-button components if already present. Otherwise, a semantic implementation can use:

```html
<section class="nyx-pc-hero" aria-labelledby="nyx-pc-heading">
  <picture class="nyx-pc-hero__art" aria-hidden="true">
    <source media="(max-width: 700px)" srcset="/assets/nyx-pc-checkup/v1.0.0/hero-mobile.svg" type="image/svg+xml">
    <img src="/assets/nyx-pc-checkup/v1.0.0/hero-desktop.svg" alt="" width="1440" height="720" fetchpriority="high">
  </picture>
  <div class="nyx-pc-hero__content">
    <span class="nyx-pc-hero__eyebrow">DIETRICH AI LABS · FREE WINDOWS UTILITY</span>
    <h1 id="nyx-pc-heading">Nyx PC Checkup</h1>
    <p>Know your PC. Stay in control.</p>
    <p class="nyx-pc-hero__description">Local-first diagnostics, clear results, and safe, user-controlled actions. Free for Windows 10 and 11.</p>
    <div class="nyx-pc-hero__actions">
      <a class="nyx-pc-hero__primary" href="https://www.dietrichailabs.com/downloads/nyx-pc-checkup/1.0.0/Nyx_PC_Checkup_1.0.0_Setup.exe">Download for Windows</a>
      <a class="nyx-pc-hero__secondary" href="https://www.dietrichailabs.com/downloads/nyx-pc-checkup/1.0.0/Nyx_PC_Checkup_1.0.0_Portable.zip">Portable ZIP</a>
    </div>
    <p class="nyx-pc-hero__fine">Version 1.0.0 · Windows 10/11, 64-bit · No account required</p>
  </div>
</section>
```

```css
.nyx-pc-hero {position:relative; isolation:isolate; overflow:hidden; color:#f5faff; background:#050c1b; border:1px solid #183b68; border-radius:24px; min-height:480px; display:flex; align-items:center; box-sizing:border-box;}
.nyx-pc-hero__art,.nyx-pc-hero__art img {position:absolute; inset:0; width:100%; height:100%; display:block; object-fit:cover;}
.nyx-pc-hero::before {content:""; position:absolute; inset:0; z-index:0; background:linear-gradient(90deg,rgba(2,7,20,.96) 0%,rgba(2,7,20,.88) 35%,rgba(2,7,20,.14) 78%,rgba(2,7,20,.05) 100%);}
.nyx-pc-hero__content {position:relative; z-index:1; padding:clamp(24px,4vw,60px); max-width:650px; width:100%; box-sizing:border-box;}
.nyx-pc-hero__eyebrow {font:700 .78rem/1.5 system-ui,sans-serif; color:#56d5ff; letter-spacing:.14em;}
.nyx-pc-hero h1 {font:750 clamp(2.25rem,4.8vw,4.5rem)/1.07 system-ui,sans-serif; letter-spacing:-.035em; margin:12px 0;}
.nyx-pc-hero__content>p {font:500 clamp(1.1rem,2.1vw,1.5rem)/1.4 system-ui,sans-serif; margin:12px 0;}
.nyx-pc-hero__content .nyx-pc-hero__description {font-size:1rem; color:#c7dcf3; line-height:1.6; max-width:38ch;}
.nyx-pc-hero__actions {display:flex; flex-wrap:wrap; gap:12px; margin:26px 0 18px;}
.nyx-pc-hero__actions a {min-height:48px; display:inline-flex; align-items:center; justify-content:center; border-radius:12px; padding:0 20px; font:700 1rem system-ui,sans-serif; text-decoration:none; box-sizing:border-box;}
.nyx-pc-hero__primary {background:#12a6ef; color:#00152b;}
.nyx-pc-hero__secondary {background:rgba(13,39,74,.84); color:#f2faff; border:1px solid #5598dd;}
.nyx-pc-hero__actions a:focus-visible {outline:3px solid white; outline-offset:3px;}
.nyx-pc-hero__content .nyx-pc-hero__fine {font-size:.8rem; color:#a8c9e6;}
@media(max-width:700px) {
  .nyx-pc-hero {min-height:725px; border-radius:18px; align-items:flex-start;}
  .nyx-pc-hero::before {background:linear-gradient(180deg,rgba(2,7,20,.96) 0%,rgba(2,7,20,.9) 31%,rgba(2,7,20,.43) 57%,rgba(2,7,20,.05) 100%);}
  .nyx-pc-hero__content {padding:30px 22px 38px; max-width:100%;}
  .nyx-pc-hero h1 {font-size:clamp(2.05rem,9vw,3rem);}
  .nyx-pc-hero__actions {flex-direction:column; align-items:stretch; margin:21px 0 12px;}
  .nyx-pc-hero__actions a {width:100%; min-height:50px;}
  .nyx-pc-hero__content .nyx-pc-hero__description {max-width:34ch;}
}
@media(prefers-reduced-motion:reduce) {.nyx-pc-hero * {animation:none!important; transition:none!important;}}
```

## Deployment and verification

The canonical public app page is `https://www.dietrichailabs.com/apps/nyx-pc-checkup/`, deployed via the existing Website Worker. This private GitHub repository does **not** have that Worker application source, so this commit stages responsive assets and exact integration guidance rather than falsely claiming the live website was edited.

Before deployment, read the live page code and prefer improving its **existing** hero instead of adding a duplicate. Avoid changing the published 1.0.0 binaries, update JSON feed, or tag. Keep existing website rollback deployment available. Verify real desktop 1440 px, tablet 768 px and mobile 390 px / 320 px viewports; text not clipped; both actual public binary links download their released sizes/hashes; no horizontal overflow and no fake download buttons embedded in images. Check display in light/dark OS modes, keyboard focus, and accessibility labels.

The owner-authorized release still does **not** imply Independent QA/security PASS.