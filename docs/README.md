# confix web demo

The interactive demo served at the project's GitHub Pages site. It runs entirely
in the browser — no server, no build — over the **same code the npm package
ships**.

## Files

- `index.html` — the page ("the tool" + "playground").
- `theme.css` — styling (dark theme).
- `confix.js` — **generated, do not edit by hand.** It is a byte-identical vendor
  of [`js/src/confix.js`](../js/src/confix.js) (the canonical library core), which
  attaches to the page as the `confix` global. The demo calls `confix.apply(...)`
  and `confix.parseCommandBlock(...)` directly.

## Updating

After changing the library core, regenerate the vendored copy:

```bash
cd js && npm run build:docs
```

CI fails if `docs/confix.js` drifts from `js/src/confix.js`, so the demo can
never run stale logic.
