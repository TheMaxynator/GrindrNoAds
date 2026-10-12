# GrindrNoAds v1.1.1 beta2 – sourceproject (rootless Theos)

Een **nieuw geschreven** jailbreak-tweak die de *advertentieblokkerende* werking van een onderzocht pakket probeert te reproduceren, zonder de oude code/binary of diens licentie- en apparaatidentificatiesysteem over te nemen. De bron is een ontwikkelbaar uitgangspunt, **niet op een toestel gevalideerd installatiepakket**.

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


## Nieuwe werking (v1.1.0 beta1)

- **Instellingen in Grindr:** houd met **twee vingers 1,2 seconde** je vinger op een leeg deel van het scherm. Een `GrindrNoAds`-dialoog opent de vijf schakelopties. Deze waarden worden via `NSUserDefaults standardUserDefaults` opgeslagen binnen Grindrs eigen appcontainer, onder sleutels `GNA.<key>`. Dit heeft geen PreferenceLoader of libSandy nodig.
- Instellingen via de oorspronkelijke `settings.plist` zijn een **fallback**; op sandboxed toestellen zijn ze mogelijk onleesbaar. De nieuwe UI-opties hebben voorrang.
- Schakelopties zijn grotendeels direct bruikbaar, maar **sluit Grindr volledig af en open opnieuw** om alle UI-veranderingen te zien. Reeds verwijderde banner-views worden niet gereconstrueerd zonder nieuwe layout.
- Herhaalde root hooks op `viewDidLayoutSubviews` en `viewDidAppear:` pakken advertentiecontainers op die pas na `viewDidLoad` worden opgebouwd. Er wordt uitsluitend een expliciete `adContainerView` verborgen en de *eigen hoogtebeperkingen* worden naar nul gezet. Er worden **geen** generieke safe-area-/tabbar-/scrollinsets veranderd.
- De ruimte onder de profielgrid kan app-intern uit een ander mechanisme komen. Dit is een **gerichte, ongeteste fix**, geen garantie op volledige opheffing. Als de ruimte blijft bestaan, is een screenshot of UI-hiërarchie noodzakelijk.

## Compilatie via GitHub Actions

Upload de volledige mapinhoud (inclusief `.github/workflows/build-rootless.yml`) naar de repository; de workflow draait de statische tests en bouwt daarna een `.deb` op macOS. Deze beta is **nog niet gecompileerd op iOS**. Installeer pas nadat GitHub Actions succesvol heeft gecompileerd en maak een herstelmogelijkheid via Sileo.



## Wijzigingen in v1.1.1 beta2: leeg bannervak

De eerste praktijktest van v1.1.0 beta1 bevestigde: geen advertentiepop-ups, stabiele profielen/chats, werkend instellingenmenu, **maar nog wel een lege strook onder de profielgrid**.

Deze versie probeert de strook **conservatief** te verwijderen:

- Beide waargenomen Swift-varianten (`GrindrAdsImpl.AdView`, `GrindrAds.AdView`) worden nu bij zowel `didMoveToWindow` als `layoutSubviews` behandeld.
- **Vóór** het verwijderen van een bekende advertentieview controleert de nieuwe `GNAdHost.m` of haar onmiddellijke parent een afzonderlijke wrapper is die uitsluitend deze advertentie als child heeft.
- Alleen voor zo'n specifieke wrapper, met een geloofwaardige bannerhoogte (8–180 punten), voldoende breedte en positie onderaan het scherm, wordt de wrapper verborgen en de eigen expliciete hoogte naar nul gezet. Bestaande scrollviews, tabbars, rootviews en navigatiebalken worden niet generiek aangepast.
- Dit pad respecteert de bestaande schakelaars **Advertentieviews** en **Lege advertentieruimte**. Je kunt de correctie uitschakelen door de laatste optie uit te zetten en Grindr volledig opnieuw te starten.

**Onzekerheid:** als de lege ruimte wordt gereserveerd door een andere controller, een scroll-inset of een layout guide, herkent deze veilige wrapperheuristiek de bron niet. Er worden bewust geen willekeurige view- of safe-area-aanpassingen gedaan.

### Nieuwe diagnoseoptie

Als de strook blijft staan:

1. Open Grindr en ga naar de profielgrid.
2. Open het tweakmenu: **twee vingers gedurende 1,2 seconde vasthouden**.
3. Kies **Diagnoseer lege bannerruimte**, daarna **Start meting**.
4. Tik eenmaal midden in de lege strook. Er opent een rapportvenster.
5. Kies **Kopieer rapport** en plak de tekst in ChatGPT.

Het rapport bevat **alleen view-classnamen, posities, afmetingen, aantallen subviews en relevante constraintwaarden**. Er worden geen profielfoto's, berichten, namen, UDID's of netwerkgegevens opgenomen. Het wordt niet naar een externe server verstuurd; alleen de expliciete kopieeractie schrijft naar het iOS-klembord. De eenmalige tikmeting vervalt automatisch na 30 seconden.

### Status en installatie

- Statische broncode-/configuratietests zijn geslaagd, maar deze wijziging is **nog niet op een iPhone gecompileerd of gevalideerd**.
- Bouw opnieuw via GitHub Actions; pak het `GrindrNoAds-rootless-deb`-artifact uit en installeer de `.deb` via Sileo over de bestaande versie.
- Bewaar de eerder werkende **v1.1.0 beta1** als terugvalmogelijkheid.
- Blijft de ruimte zichtbaar? **Niet** `AggressiveManagerResetEnabled` aanzetten als alternatief voor layoutdiagnose; dit is een afzonderlijke, risicovolle codeweg.
