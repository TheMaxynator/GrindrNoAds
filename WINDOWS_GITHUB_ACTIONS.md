# Compileren vanaf Windows zonder Ubuntu of WSL

Dit project gebruikt **GitHub Actions** om een Theos-build op een **externe macOS-runner** uit te voeren. Je beheert en downloadt alles vanaf Windows. Er wordt dus niet lokaal op Windows gecompileerd; de build zelf loopt bij GitHub.

## 1. Maak een repository

1. Log in op https://github.com/ en maak via **New repository** een repository `GrindrNoAds`.
2. Kies **Private** wanneer je de broncode niet openbaar wilt delen. Let op: macOS-runners in privé-repositories kunnen Actions-verbruik in rekening brengen. Bekijk je eigen limieten.
3. Maak een standaardbranch `main` aan (bij een lege repository kan dat bijvoorbeeld door een README aan te maken).

## 2. Upload de bestanden

1. Pak `GrindrNoAds_v1.0.1_GitHub_BuildFix.zip` uit op Windows.
2. Open in GitHub de repository en kies **Add file > Upload files**.
3. Sleep de **inhoud van de map `GrindrNoAds`** (niet een map extra niveau erboven) naar het uploadvenster. GitHub kan mappen en hun structuur bij slepen overnemen.
4. Controleer vooral of in de repository de volgende paden rechtstreeks zichtbaar zijn:
   - `Makefile`
   - `Tweak.xm`
   - `control`
   - `.github/workflows/build-rootless.yml`
   - `Sources/NetworkHooks.m`
   - `layout/Library/Application Support/GrindrNoAds/settings.plist`
5. Commit de bestanden. Als het verborgen `.github`-pad niet is overgenomen, maak `.github/workflows/build-rootless.yml` handmatig aan op de GitHub-website.

## 3. Build starten

1. Open het tabblad **Actions** van je GitHub-repository.
2. Kies **Build GrindrNoAds (rootless)**.
3. Klik op **Run workflow** (branch `main`). De eerste upload naar `main` kan de build ook al automatisch starten.
4. Bekijk het resultaat van de run. Een groene check betekent dat het compile- en packaging-script zonder fouten eindigde; dit **bewijst nog niet** dat de hooks op Grindr werken.

## 4. Het .deb-bestand downloaden

Open de voltooide workflow-run en download onder **Artifacts** het bestand **GrindrNoAds-rootless-deb**. Als GitHub een ZIP aanbiedt, pak die uit; binnenin staat `*.deb`. Zet dit bestand over naar de gejailbreakte iPhone en installeer via Sileo. Verwijder eerst het oorspronkelijke `com.0xkuj.grindruntuckednoads`-pakket.

## Fouten oplossen

- Rode workflow-run: klik de mislukte stap open en controleer de eerste compilerfout, niet alleen de laatste foutregel.
- `No such file` voor Theos: controleer de stap **Install Theos and iOS SDK** en de Runner-output.
- Geen artifact: er is mogelijk geen `.deb` gegenereerd; bekijk de build logs.
- `The workflow is not valid`: controleer exacte locatie `.github/workflows/build-rootless.yml` en dat de YAML volledig is overgenomen.
- Als `Theos` een Objective-C-compileerfout rapporteert, moet de broncode worden aangepast. Dit project is nog niet op iOS gecompileerd of runtime-getest.

## Privacy

Upload *niet* `com.gdx.dd`, de oorspronkelijke `.dylib` of licentiegegevens naar GitHub. Het ZIP-pakket bevat alleen onze nieuwe tweakbroncode, instellingen en buildconfiguratie.

Officiële referenties:
- https://theos.dev/docs/rootless
- https://github.com/Randomblock1/theos-action
- https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository
- https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts


## v1.1.0 beta1

Upload de nieuwe bestanden `Tweak.xm`, `Makefile`, `control`, `Includes/GNCommon.h`, `Sources/GNConfig.m`, `Sources/NetworkHooks.m`, `Sources/AdViewHooks.m`, `Sources/ContainerHooks.m` en `Sources/GNSettingsUI.m`. Het bestaande build-workflowbestand kan blijven staan. Na een geslaagde build test je eerst de advertentieblokkering; daarna houd je met twee vingers minstens 1,2 seconden het Grindr-scherm ingedrukt voor het nieuwe instellingenmenu.


## v1.1.1 beta2

Bijwerken vanaf beta1: vervang de gewijzigde bestanden uit de meegeleverde Hotfix ZIP (inclusief nieuwe `Sources/GNAdHost.m` en `Sources/GNDiagnostics.m`). Commit daarna de wijzigingen op `main`. Ga naar **Actions → Build GrindrNoAds (rootless) → Run workflow** en download het nieuwe `.deb`-artifact. Het is **niet** nodig om Ubuntu of Theos lokaal op Windows te installeren.
