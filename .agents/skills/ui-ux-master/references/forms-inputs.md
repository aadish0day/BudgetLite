# Forms & Inputs Mastery

Forms are where most conversion is won or lost. Every extra field, every unclear error, every mistimed validation costs users. Design forms as flows, not fields.

## First principles

- **Ask for the minimum.** Every field is friction. Defer non-essential input (progressive profiling). If you don't act on the data now, don't ask for it now.
- **One column.** Single-column forms complete faster than multi-column; the eye follows one clear path.
- **Label above the field.** Never placeholder-as-label (it disappears on focus and fails accessibility). Placeholders show *examples* (`jane@example.com`), ending with `…` for patterns.
- **Group logically** with clear section headings when long (Miller's law — chunk into ~5–7).
- **Smart defaults & pre-selection** beat empty inputs. Remember the last choice.

## Validation UX (timing is everything)

- **Validate on blur, not on keystroke.** Interrupting someone mid-typing with a red error is hostile. Accept free text, validate after they leave the field.
- **Re-validate on input *after* the first error** — once a field is invalid, give live positive feedback as they fix it.
- **Errors inline, next to the field,** with color + icon + text (never color alone). Link programmatically with `aria-describedby` + `aria-invalid`.
- **On submit, focus the first error** and scroll it into view.
- **Allow submitting an incomplete form** to surface all validation at once — don't hard-block the button so users can't discover what's wrong.
- **Positive, specific messages:** "Enter a valid email like jane@example.com", not "Invalid input."

## The submit button

- Keep it **enabled until the request starts**; then disable + show a spinner while **keeping the original label** (don't swap to "Loading…" that shifts width — or reserve the width).
- Never double-submit: block re-clicks during the request.
- `Enter` submits a focused single-line input; in `<textarea>`, `⌘/Ctrl+Enter` submits.
- Confirm destructive submits or offer Undo.

## Input types & attributes (get these right)

- Correct `type` and `inputmode`: `type="email" inputmode="email"`, `type="tel" inputmode="tel"`, `inputmode="numeric"` for codes, `type="url"`, etc. — this changes the mobile keyboard.
- `autocomplete` with meaningful `name` (`autocomplete="email"`, `"current-password"`, `"one-time-code"`) — huge for speed and password managers.
- `font-size ≥ 16px` on mobile inputs to prevent iOS auto-zoom.
- Disable spellcheck on emails/codes/usernames (`spellcheck="false"`).
- **Never block paste** in any input — especially passwords and OTP codes.
- Trim trailing/leading whitespace on submit (copy-paste artifacts).

## Specialized inputs

- **Password:** show/hide toggle; strength meter; allow paste; support password managers; don't enforce hostile composition rules — length beats complexity.
- **OTP / verification code:** individual boxes or one field, `autocomplete="one-time-code"`, `inputmode="numeric"`, auto-advance, allow pasting the whole code.
- **Date:** prefer a native picker on mobile; for ranges, show both ends and validate order; locale-aware format (`Intl.DateTimeFormat`).
- **Search:** debounce (~200–300ms), show recent/suggested, clear button, results count, empty-search state.
- **File upload:** drag-and-drop zone + click fallback, show accepted types/size limits up front, per-file progress, remove/retry, thumbnail previews.
- **Select vs radio vs combobox:** ≤5 options → radios (all visible); 5–15 → select; >15 or searchable → combobox with autocomplete.
- **Toggle vs checkbox:** toggle = immediate effect (setting); checkbox = staged choice submitted later.

## Multi-step forms & wizards

- Show a **stepper / progress indicator** — visible ends raise completion.
- **Save progress** between steps (don't lose data on back/refresh).
- Allow going **back** without losing entered data.
- Validate each step before advancing; summarize before final submit.
- **Warn on unsaved changes** before navigation away.

## Accessibility must-haves

- Every control has a programmatic `<label>` (or `aria-label`).
- No dead zones: label + control share one hit target for checkboxes/radios.
- Fieldset/legend for radio & checkbox groups.
- Errors announced via `aria-live="polite"`.
- Full keyboard operability; visible `:focus-visible` rings.
- Hydration-safe inputs (no lost focus/value); `value` needs `onChange` or use `defaultValue`.

## Checklist

- [ ] Minimum fields; non-essential deferred
- [ ] Single column, labels above fields
- [ ] Validate on blur, re-validate on input after error, focus first error on submit
- [ ] Errors inline with color + icon + text, `aria-describedby`
- [ ] Correct `type`/`inputmode`/`autocomplete`; 16px mobile font; paste never blocked
- [ ] Submit stays enabled until request; spinner keeps label; no double-submit
- [ ] Multi-step shows progress, saves state, allows back
- [ ] Every field labeled; groups use fieldset/legend; keyboard + focus rings
