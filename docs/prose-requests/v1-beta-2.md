# Prose request: website spots touched by 1.0.0-beta.2

> How this works: each "##" heading is one piece of text Sable needs.
> Write your version under "Your text" and leave the heading alone. The
> drafts are deliberately over the top so they can never ship by accident.
> Claude uses only what's under "Your text", exactly as you wrote it.
>
> There are no PROSE-TODO markers in the site for this request: the line
> below is still true as written (just incomplete), so nothing blocks the
> release or a merge. Answer whenever you like; Claude swaps your text in and
> deletes this file. (Two older requests, `v1-beta-1.md` and
> `standalone-markdown.md`, are still waiting too.)

## Website · Home · First-launch step
- Where: website/index.html, "Opening Sable for the first time", step 4 of
  the table (the second cell of the last row). It currently reads: "Sable
  opens and asks you to choose or create a writing folder, or to just open a
  file. A folder is optional." The next cell, "From now on it opens like any
  other app. Updates arrive inside Sable, verified with the project's signing
  key.", is still accurate.
- Length: 1–2 sentences, about the same as now
- Must get across: the first-launch window now has a third choice, a sample
  project to look around in, beside choosing a folder and just opening a file;
  a folder is still optional
- Verified facts: the setup window's buttons are **Just Open a File**,
  **Explore a Sample Project**, **Not Now**, and **Choose or Create Folder…**.
  The sample is *Northwatch*, a short finished story (three chapters, four
  character cards, two locations, a world note, a Concept note, an Outline).
  It is copied into Documents as "Sable Sample Project", so writers can change
  anything. It doesn't set a writing folder. **Not Now** closes the window
  and Sable asks again next time. Help → Open Sample Project opens it later.
  Not true yet: nothing about the sample appears anywhere else on the home
  page.

Draft (rewrite me):
> BEHOLD!!! A WHOLE PRE-WRITTEN NOVEL AWAITS YOUR EXPLORATION!!! Folders are
> for the WEAK!!! Peek inside the sample and TREMBLE!!!

Your text:
>

## Website · Home · Accessibility (optional, only if you want it mentioned)
- Where: nowhere yet. Nothing on the home page is wrong; this is only a
  suggestion if you'd like the site to say so. The tour in `<section>`s
  around `id="writing"` and `id="projects"` is the natural neighbor; the
  FAQ is another.
- Length: 1–2 sentences, or skip this item
- Must get across: Sable works with VoiceOver and the keyboard alone, and
  respects Increase Contrast, Reduce Transparency, and Reduce Motion
- Verified facts: every control has a spoken name; hover-only buttons are
  VoiceOver actions; drag-only reordering (Customize Tools, the Manuscript
  tab) has keyboard equivalents; Escape closes every sheet; with VoiceOver or
  Keyboard navigation on, the toolbar stays in view instead of hiding. Every
  theme's text, dimmed Markdown symbols, paragraph-focus dimming, and name and
  sentence colors are measured against WCAG contrast limits by a check that
  runs with every change. Not claimed: a formal accessibility audit or
  certification.

Draft (rewrite me):
> EVERY PIXEL, EVERY KEYSTROKE, EVERY VOICE-OVER-ED WORD: SABLE IS FOR
> ABSOLUTELY EVERYONE!!! (Certified by nobody, but FEEL the inclusion!!!)

Your text:
>
