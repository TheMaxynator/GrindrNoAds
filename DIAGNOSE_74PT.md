# Diagnose van resterende lege bannerstrook (v1.1.2 beta3)

## Bron: rapport v1.1.1 beta2

- Scherm: 390 x 844 punten.
- Zichtbare tabbar: `UITabBar x0 y687 w390 h49`.
- Verdachte view: `UIView x0 y736 w390 h74 hidden a0.0 children0`.
- Onderste safe area: circa 34 pt (`844 - 810`).
- Het hit-test-pad begon echter bij `tapped x0 y0`, niet bij de onderste strook. **Dit is geen bevestiging van de verantwoordelijke parent constraint.**

De verborgen UIView is dus een **sterke kandidaat**, maar er is nog geen bewijs dat zijn eigen constraint verantwoordelijk is voor het gereserveerde gebied.

## Optionele wijziging

`GNBottomGap.m` draait alleen binnen Grindr, alleen wanneer *Lege advertentieruimte* en *Onderste 74pt-ruimte corrigeren (test)* aanstaan. De correctie zoekt precies één onzichtbare, lege UIView van 72-76 pt, praktisch schermbreed, direct onder de tabbar, met de onderkant gelijk aan de bovenzijde van de onderste safe area. Als die ene view zelf een actieve, expliciete 72-76pt-hoogteconstraint heeft, wordt uitsluitend die constraint op nul gezet. Anders doet de code niets. Er worden geen tabbarframes, safe-area-insets, scroll-insets, rootframes of navigatiehoogtes veranderd.

## Aanpak op het toestel

1. Maak eventueel een backup van de werkende v1.1.1 beta2 `.deb`.
2. Build deze beta3 via GitHub Actions en installeer de nieuwe `.deb` met Sileo.
3. Controleer eerst stabiliteit en dat het instellingenmenu nog opent.
4. Schakel **Onderste 74pt-ruimte corrigeren (test)** in en herstart Grindr volledig.
5. Als de ruimte blijft: schakel de experimentele optie weer **UIT**, herstart Grindr en gebruik **Diagnoseer lege bannerruimte** om een nieuw rapport te kopiëren.
6. Controleer of het nieuwe rapport `Hidden bottom-slot owners` en `all direct geometry constraints` bevat. Hiermee kan vervolgens de echte eigenaar van de hoogte bepaald worden.

De experimentfunctie is standaard uitgeschakeld en nog niet op een iPhone getest. De 55 broncodechecks zijn geen vervanging voor een iOS-compilatie.
