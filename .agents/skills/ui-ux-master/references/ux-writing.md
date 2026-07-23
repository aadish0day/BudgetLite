# UX Writing & Micro-copy

Words are interface, not decoration. Copy can make a design feel as templated — or as polished — as the visuals. Bring the same intentionality to text that you bring to spacing and color.

## First principles

- **Clarity beats cleverness.** Specific is always better than witty. If a joke costs comprehension, cut it.
- **Write from the user's side of the screen.** Name things by what people control and recognize, never by how the system is built. A person "manages notifications", not "webhook config".
- **Say what it does, plainly.** Describe function, don't sell it.
- **Every word earns its place.** No filler, no "please note that", no "in order to". Cut ~50% of a first draft.
- **One job per element.** A label labels, an example demonstrates, an error explains — nothing does double duty.

## Voice & tone

- **Voice is constant** (the brand's personality); **tone flexes** with context (celebratory on success, calm and direct on error).
- **Conversational and human,** sentence case, plain verbs. Match register to the brand and audience.
- Consistent vocabulary: pick one term per concept and never vary it ("Delete" everywhere, not "Delete" / "Remove" / "Trash" for the same action). This is the signposting people learn the product by.

## Buttons & actions

- **Verb-first, specific:** "Save changes", "Create project", "Send invite" — not "Submit", "OK", "Yes".
- **Action keeps its name through the flow:** the button that says "Publish" produces a toast that says "Published."
- **Match the user's intent,** not the system event. "Cancel subscription", not "Deactivate account record."
- Ellipsis (`…`) when the action opens a follow-up ("Rename…", "Move to…") or is loading ("Saving…").
- Destructive buttons are labeled by what they destroy ("Delete 3 files"), never a bare "Delete" when consequences are ambiguous.

## Labels, help & placeholders

- **Labels above fields,** short, in the user's words.
- **Inline help first** (a short hint under the field); tooltips are a last resort for genuinely secondary detail.
- **Placeholders show examples** (`jane@example.com`), not instructions or the label — they vanish on focus.
- Don't restate the obvious ("Email" field labeled "Email" needs no "Enter your email" helper).

## Errors & empty states

- **Errors don't apologize and aren't vague.** State what happened + how to fix it, in the interface's voice: "That email is already registered. Sign in instead?" not "Error: invalid input."
- **Blame the situation, not the user.** Avoid "You entered an invalid…"; prefer "Enter a valid…".
- **Empty states are an invitation to act,** not a mood: "No projects yet — create your first to get started" + the action. Distinguish first-run empty from filter-empty from all-done.
- **Recovery always offered** — no dead ends. Give the next step (retry, go back, contact).

## Notifications, toasts & confirmations

- **Actionable and timely.** A toast says what happened + optionally "Undo". Auto-dismiss non-critical ones.
- **Prefer Undo over confirm** for reversible actions (less friction). Reserve confirmation dialogs for truly destructive, irreversible ones — and state the consequence + make the confirm button name the action ("Delete forever").
- **No confirm-shaming.** The decline option is neutral ("Not now"), never "No, I don't want to save money."

## Numbers, dates & i18n-safe copy

- Locale-aware dates/times/numbers (`Intl.DateTimeFormat`, `Intl.NumberFormat`).
- Use the real ellipsis character `…` (not `...`) and curly quotes (" ").
- Non-breaking spaces to avoid awkward breaks: `10&nbsp;MB`, `⌘&nbsp;K`.
- **Design for text expansion:** other languages run ~30% longer — don't hard-code widths around English strings.
- `translate="no"` on brand names, code tokens, and identifiers so auto-translate doesn't mangle them.
- Avoid idioms and culture-specific jokes that don't translate.

## Accessibility of copy

- Accessible names exist even when the visual omits a label (icon-only buttons need a descriptive `aria-label`).
- Link text is meaningful out of context ("View pricing", not "click here").
- Reading level: aim for plain, scannable language; short sentences; front-load the key info.

## Quick before/after

| Before | After |
| --- | --- |
| "Submit" | "Create account" |
| "Error: invalid input" | "Enter a valid email like jane@example.com" |
| "Are you sure?" | "Delete this project? This can't be undone." |
| "No data" | "No invoices yet — create your first invoice" |
| "click here" | "View the pricing page" |
| "No, I don't want to save" | "Not now" |

## Checklist

- [ ] Buttons are verb-first and specific; consistent naming through the flow
- [ ] Labels in the user's words, above fields; help inline before tooltips
- [ ] Errors say what + how to fix, blame the situation not the user
- [ ] Empty states invite action and distinguish their kind
- [ ] Undo preferred over confirm; no confirm-shaming
- [ ] `…` and curly quotes; non-breaking spaces; locale-aware formatting
- [ ] Copy survives ~30% text expansion; brand/code marked `translate="no"`
- [ ] Icon-only controls have accessible names; link text meaningful alone
