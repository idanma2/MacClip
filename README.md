# MacClip

A native macOS menu-bar utility: text-only clipboard history, summoned
anywhere with ⌥V.

See [ONBOARDING.md](ONBOARDING.md) for architecture, what's built vs. not,
and how to pick this up in a future session. See
[DevTools/README.md](DevTools/README.md) for how to run the test harnesses.

## Build

```
Scripts/build-dmg.sh
```

Produces `dist/MacClip.dmg` — ad-hoc signed, not notarized (see
ONBOARDING.md).
