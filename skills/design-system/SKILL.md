---
name: design-system
description: Use whenever building UI, designing components, creating frontends, prototyping interfaces, or when the user mentions "design system", "make it look like", "style it like", or any visual design task. Also trigger when creating new projects with a frontend, building landing pages, dashboards, or any component that needs consistent visual styling. This skill ensures every UI Claude builds has a cohesive, professional design language instead of generic defaults.
---

# Design System Skill

Apply a curated design system to any frontend work. Instead of generic Tailwind defaults or ad-hoc styling, this skill gives you access to four production-grade design systems extracted from real products — each with specific colors, typography, spacing, shadows, component patterns, and do's/don'ts.

## Available Design Systems

| System | Vibe | Best For |
|--------|------|----------|
| **Stripe** | Light, premium, financial-grade polish | Admin panels, dashboards, data-heavy UIs, SaaS products, anything that needs to feel trustworthy and precise |
| **Supabase** | Dark, emerald-accented, developer-native | Developer tools, CLI companions, dark-mode-first apps, technical products |
| **Resend** | Pure black void, editorial typography, frost borders | Marketing sites, product showcases, minimalist apps, anything that needs to feel cinematic |
| **Spotify** | Dark immersive, pill geometry, content-first | Media apps, content browsers, playlist/feed UIs, touch-optimized interfaces |

## How to Use

### Step 1: Pick a system

If the user hasn't specified one, recommend based on the project:
- Light mode admin/dashboard → **Stripe**
- Dark mode dev tool → **Supabase**
- Dark marketing/showcase page → **Resend**
- Dark content/media app → **Spotify**

If the project already has a DESIGN.md in its root, use that instead of these references.

### Step 2: Read the reference

Read the full reference file for the chosen system — it contains everything you need:

```
references/stripe.md    — Light, blue-tinted shadows, sohne-var, weight 300 headlines
references/supabase.md  — Dark, emerald green, Circular font, border-defined depth
references/resend.md    — Black void, frost borders, 3-font editorial hierarchy
references/spotify.md   — Near-black, pill geometry, uppercase buttons, heavy shadows
```

Each reference has 9 sections: Visual Theme, Color Palette, Typography, Components, Layout, Depth, Do's/Don'ts, Responsive, and Agent Prompt Guide. The Agent Prompt Guide at the end has quick color references and ready-to-use component specifications.

### Step 3: Apply consistently

When building components:

1. **Colors** — Use the exact hex values from the reference. Don't approximate or use Tailwind color classes that are "close enough." If using Tailwind, define custom colors in the config or use arbitrary values (`bg-[#533afd]`).

2. **Typography** — Match the font family, weight, size, line-height, and letter-spacing from the reference hierarchy table. For web fonts that aren't available (sohne-var, Circular, Domaine Display, SpotifyMixUI), use the system font fallbacks listed in the reference. For prototypes, Inter works as a universal stand-in — but call out the intended font in comments.

3. **Shadows & Depth** — Each system has a distinct depth philosophy. Stripe uses blue-tinted multi-layer shadows. Supabase uses border contrast (no shadows). Resend uses frost borders. Spotify uses heavy black shadows. Follow the system's approach, don't mix.

4. **Border Radius** — Each system has a specific radius scale. Stripe is conservative (4-8px). Supabase mixes pills (9999px) and standard (6-8px). Resend goes from 4px to 9999px. Spotify is all pills and circles. Match the scale.

5. **Components** — Build buttons, cards, inputs, badges, and nav using the exact specs in section 4 of the reference. Don't improvise component styles.

6. **Do's and Don'ts** — Section 7 of each reference lists specific things to avoid. Read it. Common mistakes: using pure black instead of the system's dark color, wrong shadow style, wrong font weight, wrong border radius.

## Dropping a DESIGN.md Into a Project

When starting a new project or the user wants to adopt a system permanently:

1. Copy the chosen reference file to the project root as `DESIGN.md`
2. Add a note in the project's CLAUDE.md pointing to it:
   ```
   ## Design System
   This project uses the [Stripe/Supabase/Resend/Spotify] design system.
   See DESIGN.md for colors, typography, components, and guidelines.
   ```
3. If using Tailwind, generate a tailwind config snippet with the system's colors, fonts, and radius scale

## Combining Systems

Sometimes a project needs elements from multiple systems (e.g., Stripe's light admin panel with Supabase's dark sidebar). This is fine, but:

- Pick one system as primary (drives the overall feel)
- The secondary system only applies to a specific, contained region (sidebar, modal, embedded widget)
- Never mix shadow philosophies in the same visual plane
- Keep typography consistent — one font stack for the whole app, even if colors change per region

## Customization

The references are starting points. The user has a good eye for design and may want to tweak things. Common customizations:

- Swap the primary accent color while keeping the rest of the system intact
- Adjust the radius scale (e.g., make Stripe slightly more rounded)
- Combine a system's color palette with a different typography approach
- Add the project's own brand colors as accent overrides

When customizing, document changes in the project's DESIGN.md so they persist.
