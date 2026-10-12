# GrindrNoAds v1.0.0 – sourceproject (rootless Theos)

Een **nieuw geschreven** jailbreak-tweak die de *advertentieblokkerende* werking van een onderzocht pakket probeert te reproduceren, zonder de oude code/binary of diens licentie- en apparaatidentificatiesysteem over te nemen. De bron is een ontwikkelbaar uitgangspunt, **geen getest of reeds gecompileerd installatiepakket**.

## Functies

- Substrate-hook op `NSURLSession -dataTaskWithRequest:completionHandler:` die requests naar de tien onderzochte advertentiedomeinen omzet naar synthetische, lege HTTP-204-antwoorden.
- Hooks op `GrindrAdsImpl.AdView -didMoveToWindow` (verwijderen) en `GrindrAds.AdView -layoutSubviews` (verbergen).
- Hook op `grindrx.RootContainerViewController -viewDidLoad` om bekende advertentieviews weg te halen en zichtbare NSLayoutConstraint-hoogtes van advertentiecontainers op nul te zetten, **uitsluitend wanneer types veilig herkenbaar zijn**.
- Bewuste veiligheidsverbetering: hostnames matchen exact of op een `.`-subdomeingrens. `notapplovin.com` wordt dus niet geraakt door een regel voor `applovin.com`.
- Optioneel, standaard **uitgeschakeld**: manager-ivar-reset. Versieafhankelijke Swift-objecten blind wissen is riskant.
- De synthetische taak is een gewone `NSURLSessionDataTask` van dezelfde sessie; callbacks lopen pas na `resume`, en `cancel`-fouten blijven herkenbaar. Dit vervangt het directe callback-gedrag van de oorspronkelijke tweak.

**Niet aanwezig:** UDID-opslag, libSandy, `noads.plist`, YouRepo, externe licentieserver, `exit(0)`, SpringBoard-injectie, of aanpassingen aan accounts/abonnementen.

## Huidige status

| Onderdeel | Status |
|---|---|
| Vier originele hook-selectors opgenomen | **Gerealiseerd (broncode)** |
| Rootless `.plist`, `control`, `layout/` en Makefile | **Gerealiseerd** |
| Statische controles op configuratie/privacy | **Uitvoerbaar met Python** |
| Compileerbaar op een correcte Theos-installatie | **Ontworpen, nog niet geverifieerd** |
| Werkende `.deb` | **Niet beschikbaar zonder iOS SDK + Theos** |
| Gedrag op actuele Grindr | **Niet getest op jailbreak/iPhone** |

## Build

Vereisten: Theos, iOS SDK, Objective-C/Logos-toolchain, Substrate-compatibele hook runtime, rootless jailbreak (iOS 15 of later). Zie [Theos rootless documentation](https://theos.dev/docs/rootless).

```bash
export THEOS=/pad/naar/theos
cd GrindrNoAds
python3 tests/validate_project.py
./scripts/build.sh
# pakket na succesvolle build: packages/*.deb
```

Theos installeert de tweak-dylib en `GrindrNoAds.plist` onder de rootless MobileSubstrate-directory. De installatielayout (`layout/`) wordt eveneens rootless geprefixt door Theos. Het Theos `control`-bestand declareert een **conflict met de oorspronkelijke tweak**, zodat beide niet tegelijk worden geladen.

Na installatie: Grindr volledig afsluiten en opnieuw starten. Bij injectieproblemen de appversie en daadwerkelijk geladen classnamen controleren. De instructie `INSTALL_TARGET_PROCESSES = Grindr` is de **verwachte procesnaam** en moet bij een afwijkende procesnaam mogelijk worden aangepast; de bundlefilter is leidend.

## Instellingen

`layout/Library/Application Support/GrindrNoAds/settings.plist` en `blocked-domains.plist` komen na installatie onder de rootless prefix, doorgaans `/var/jb/Library/Application Support/GrindrNoAds/`.

Instellingen (alleen bij appstart ingelezen):

- `NetworkBlockingEnabled`: `true`
- `ViewRemovalEnabled`: `true`
- `ContainerCleanupEnabled`: `true`
- `AggressiveManagerResetEnabled`: `false` (risicovol, niet zonder apparaatversiecontrole aanzetten)
- `DebugLoggingEnabled`: `false` (logt alleen domeinen, geen volledige URLs)

De domeinlijst bevat de tien oorspronkelijk waargenomen domeinen. `onelink.me` kan voor gewone deep links worden gebruikt; verwijder dat domein uit de lijst als legitieme links stoppen met werken. **Let op:** in een sterk gesandboxte app kunnen bestanden buiten de appcontainer onleesbaar zijn. In dat geval gebruikt deze code standaardwaarden in de dylib; de externe instellingen zijn dan mogelijk niet effectief. Een voorkeurenmechanisme met gegarandeerde sandboxtoegang vereist tests op het toestel.

## Technische afwijkingen / beperkingen

1. Het netwerkfilter is beperkt tot de onderzochte `NSURLSession`-selector. Andere API's en server-side ingevoegde advertenties kunnen alsnog zichtbaar zijn.
2. De lege `about:blank`-task is bedoeld om geen netwerkverkeer te maken en de `resume`/`cancel`-levenscyclus te respecteren, maar iOS-runtimegedrag en appchecks moeten op het toestel worden gevalideerd. De `currentRequest` op zo'n taak zal de neutrale URL tonen, niet de originele ad-URL.
3. Swift-module/classnamen en interne ivars kunnen bij een Grindr-update veranderen. Ontbrekende classes worden overgeslagen en opnieuw gezocht bij `UIApplicationDidFinishLaunching` en `UIApplicationDidBecomeActive`, zodat later geladen Swift-modules alsnog kunnen worden gehaakt. Na die momenten pas geregistreerde classes kunnen nog steeds gemist worden.
4. Verwijderen/verbergen garandeert niet dat elke gereserveerde layout-ruimte automatisch verdwijnt. In sommige appversies ontstaan containers pas ná `viewDidLoad`.
5. Containeropschoning slaat scalar/opaque Swift-ivars over. Dat is veiliger dan onvoorwaardelijk `object_setIvar`, maar kan minder ingrijpend zijn dan de oude tweak.
6. Test de tweak met de oorspronkelijke tweak verwijderd; de pakketconflictregel is bedoeld om botsingen te voorkomen.
7. Werking is niet bevestigd op een actuele Grindr-build; geen beweringen over premium-, aankoop- of abonnementsfuncties.

## Handmatige testmatrix op een jailbreaktoestel

1. Installeer via Sileo een zelf gecompileerde `.deb`; controleer dat het oude pakket is verwijderd.
2. Start Grindr opnieuw, controleer dat aanmelden, chats, profiel en afbeeldingsweergave normaal blijven.
3. Vergelijk zichtbare advertenties, bannerhoogtes en de feed met dezelfde app zonder deze tweak.
4. Test alle tien domeinregels met logregels; test ook `notapplovin.com` als negatieve grenscase.
5. Test met/zonder netwerkconnectiviteit, met app op achtergrond en na herstart.
6. Test URL/deep links (bijv. OneLink), en verwijder eventueel `onelink.me` uit de regels.
7. Zet alleen voor diagnostiek `DebugLoggingEnabled` aan en controleer crashlogs/hanggedrag.
8. Schakel modules afzonderlijk uit in `settings.plist` om een incompatibele hook te isoleren.
9. Voer een versie-upgrade van Grindr uit en bevestig alle Swift-classnamen opnieuw.

## Projectonderdelen

```
GrindrNoAds/
├── Makefile, control, GrindrNoAds.plist, Tweak.xm
├── Includes/GNCommon.h
├── Sources/{GNConfig,NetworkHooks,AdViewHooks,ContainerHooks}.m
├── layout/Library/Application Support/GrindrNoAds/{settings,blocked-domains}.plist
├── tests/validate_project.py
└── scripts/build.sh
```

Dit project hergebruikt geen licentiecode, UDID, apparaat-ID of oorspronkelijke dylib. Het is een functioneel vergelijkbare, onafhankelijke herimplementatie; de daadwerkelijke werking blijft afhankelijk van compilatie, de lokale jailbreak en de Grindr-build.

## Vanaf Windows zonder WSL/Ubuntu: GitHub Actions

Dit project bevat een kant-en-klare cloud-buildworkflow in `.github/workflows/build-rootless.yml`. Beheer de broncode op Windows en laat GitHub een macOS-runner met Theos en iOS SDK starten. Download na een geslaagde build het `.deb`-bestand uit de workflow-artifacts. Zie [WINDOWS_GITHUB_ACTIONS.md](WINDOWS_GITHUB_ACTIONS.md) voor stappen. Deze methode compileert **niet lokaal** op Windows; GitHub compileert extern en levert het installatiebestand terug.
