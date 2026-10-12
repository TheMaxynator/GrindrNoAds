# Build- en teststatus – 1.1.1~beta2

- De eerdere **v1.1.0 beta1** werd op het toestel als stabiel bevestigd, met werkende advertentieblokkering en instellingenmenu. De lege bannerruimte bleef bestaan.
- Nieuwe gerichte correctie: herken een exclusieve wrapper rond een bevestigde Swift-advertentieview en collapse de wrapper zelf; geen globale safe-area/scroll-inset-wijzigingen.
- Nieuwe, optionele on-device layoutdiagnose; gebruikers moeten de resultaten zelf kopiëren en delen.
- `python3 tests/validate_project.py`: geslaagd.
- **Geen iOS build uitgevoerd in deze omgeving:** geen Theos en iOS SDK beschikbaar; compilatie op GitHub Actions nog vereist.
- **Geen runtime-validatie uitgevoerd:** resultaat van de aangepaste wrapperhook en de diagnosefunctie is nog onzeker.

Bij regressie: verwijder v1.1.1 beta2 en installeer eerder geteste v1.1.0 beta1 via Sileo.
