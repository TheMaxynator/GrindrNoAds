# Build- en teststatus (12 oktober 2026)

## Uitgevoerd
- Project opgezet met Theos rootless packaging, `control`, injectiefilter, vier hooks in modulaire Objective-C-code.
- Geen oorspronkelijke dylib, decompiled code dump, persoonlijke identifier of licentiecomponent in deze source-release opgenomen.
- XML- en binary-plistparsing geslaagd voor het filter en beide instellingenbestanden.
- 28 statische tests uitgevoerd: allemaal geslaagd.
- Buildscript daadwerkelijk gestart.

## Blokkade
- **Theos is niet geïnstalleerd** (`THEOS` is leeg en er is geen iOS SDK beschikbaar).
- Buildscript eindigt met exitcode **2** voordat compilatie begint.
- Daardoor is er **geen `.deb` of op het toestel geteste dylib**; de compileerbaarheid van de Objective-C-code is nog niet bevestigd.

## Volgende stap op een macOS/Linux-machine met Theos + iOS SDK
```sh
export THEOS=/path/to/theos
cd GrindrNoAds
./scripts/build.sh
```

Output na succes: `packages/*.deb` (rootless, arm64). Test daarna op een gejailbreakte iPhone met de bedoelde Grindr-versie. Zie README voor de volledige testmatrix, beperkte selector-dekking en de beperkingen van sandbox-toegang tot externe configuratiebestanden.
