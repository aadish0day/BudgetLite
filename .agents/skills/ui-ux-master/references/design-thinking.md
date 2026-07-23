# Design Thinking

The problem-solving process that sits *before* pixels. Design thinking keeps you building the right thing, not just building the thing right. Use it at the start of any non-trivial feature or product, and return to it whenever you're unsure what to design.

## The five modes (non-linear, iterative)

Design thinking isn't a waterfall — you loop back constantly. But the modes are:

1. **Empathize** — understand the user, their context, and their real problem.
2. **Define** — frame a sharp, actionable problem statement.
3. **Ideate** — generate many possible solutions before committing.
4. **Prototype** — make the idea tangible cheaply.
5. **Test** — put it in front of users, learn, iterate.

## 1. Empathize — understand before solving

- **Who is the user?** Build a concrete persona: their goal, context, constraints, level of expertise, emotional state.
- **What is the job to be done?** People "hire" a product to make progress in a situation. Frame it as: *"When [situation], I want to [motivation], so I can [expected outcome]."*
- **Observe, don't assume.** What do users actually do vs what they say? Watch for workarounds, friction, and abandonment.
- **Map the journey:** the steps, thoughts, and emotions a user goes through — highlight pain points and moments that matter.

Techniques: user interviews, journey maps, empathy maps, "5 whys" to reach the root problem.

## 2. Define — frame the real problem

- Turn observations into a **point-of-view statement:** *"[User] needs [need] because [insight]."*
- Or a **"How might we…"** question that's neither too broad ("HMW redesign the app") nor too narrow ("HMW make the button blue"): *"How might we help first-time users reach their first success without reading docs?"*
- A good problem statement is **human-centered, specific, and actionable** — and doesn't smuggle in a solution.
- **Prioritize:** which problem, for which user, matters most to the business *and* the user right now? (See `ux-business-logic.md`.)

## 3. Ideate — quantity before quality

- **Diverge first, converge later.** Generate many options; defer judgment. The first idea is rarely the best.
- Techniques: brainstorm, "Crazy 8s" (8 sketches in 8 minutes), SCAMPER, worst-possible-idea (invert to find insights), analogies from other domains.
- For interfaces, explore **structurally different** directions, not variations of one — different layouts, different primary actions, different mental models.
- **Then converge:** cluster ideas, pick with intent (impact vs effort), and commit to one direction to prototype. State *why* this one.

## 4. Prototype — make it tangible, cheaply

- **Match fidelity to the question.** Testing flow/logic → low-fi wireframes or ASCII/paper. Testing look/feel → hi-fi mockup. Testing interaction → clickable/coded prototype.
- **Prototype the risky part first** — the assumption most likely to be wrong.
- Cheap and disposable beats polished and precious; you'll throw most of these away.
- Wireframe order: content and hierarchy first, then layout, then visual design. Don't pick colors before you know the structure.

## 5. Test — learn and iterate

- **Watch real users** attempt real tasks; don't lead them. Note where they hesitate, misread, or fail.
- Ask *why*, not "do you like it" — preference isn't behavior.
- **Usability heuristics** (Nielsen) as a quick self-test: visibility of system status, match to real world, user control/freedom, consistency, error prevention, recognition over recall, flexibility, minimalist design, help users recover from errors, help/docs.
- Feed learnings back — redefine the problem, re-ideate, re-prototype. Iteration *is* the process.

## Applying it fast (when you can't run full research)

Even solo and time-boxed, do a compressed pass:
1. **State the user + job + success metric** in one sentence before designing.
2. **List 3 structurally different approaches**, pick one with a reason.
3. **Sketch the risky flow** (even as ASCII wireframes) before coding.
4. **Self-test against heuristics** and the critique framework (`design-critique.md`).
5. **Ship, then watch/measure** and iterate.

## Double Diamond (a useful mental model)

- **Discover** (diverge: explore the problem space) → **Define** (converge: one problem) → **Develop** (diverge: many solutions) → **Deliver** (converge: one refined solution).
- The first diamond is about **doing the right thing**; the second about **doing the thing right**. Most failures come from skipping the first diamond.

## Checklist

- [ ] Real user + job-to-be-done articulated (not assumed)
- [ ] Sharp, solution-free problem statement / HMW question
- [ ] Multiple structurally different ideas generated before committing
- [ ] Chosen direction justified against impact/effort and the problem
- [ ] Risky assumption prototyped first, at appropriate fidelity
- [ ] Tested with (or self-tested against) real tasks and heuristics
- [ ] Learnings fed back into another iteration
