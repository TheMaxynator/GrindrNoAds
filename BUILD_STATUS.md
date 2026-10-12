# Buildstatus – GrindrNoAds 1.1.2 beta3

- Gebaseerd op de succesvol door de gebruiker gecompileerde en geteste v1.1.1 beta2.
- Nieuwe module GNBottomGap.m: standaard uitgeschakelde, strikt geometrisch begrensde placeholderfix.
- Verbeterde on-device-diagnose: hidden 74pt-view wordt onafhankelijk van tap-hit-testing gevonden en de eigenaar/constraints worden gerapporteerd.
- Statische controles: uit te voeren met `python3 tests/validate_project.py`.
- Compiler-/runtime-status: NIET getest op iOS/Theos in deze omgeving. Gebruik GitHub Actions voor de echte build.
- Geen generieke tabbar-, safe-area- of scroll-inset-aanpassingen.
