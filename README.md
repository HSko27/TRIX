<div align="center">

# trix ·

**Tvoje česká asistentka. Přímo v notchi.**

macOS 14+ · Apple Silicon · lokální modely · 0.6.0 beta

[Stažení aplikace](https://github.com/HSko27/TRIX/releases/tag/v0.6.0-beta) · [Instalace](#instalace) · [Co TRIX umí](#co-trix-umí) · [Pro vývojáře](docs/DEVELOPMENT.md)

![Ilustrační produktový vizuál MacBooku s fialovou září kolem notche](docs/assets/trix-hero.png)

<sub>Ilustrační vizuál, nikoli screenshot aplikace.</sub>

</div>

TRIX je nenápadná česká asistentka pro Mac. Při běžné práci zůstává schovaná; fialová záře kolem notche ukazuje, že je připravená. Přejeď kurzorem na notch a otevře se panel. Napiš jí, nebo začni mluvit.

Chat, přepis řeči i hlas běží na tvém Macu. Po prvním stažení modelu nepotřebují cloudovou AI službu ani API klíč.

## Co TRIX umí

| Funkce | Jak ji využiješ |
| :--- | :--- |
| **Český chat** | Ptej se, plánuj nebo si nech vysvětlit kód. TRIX odpovídá v ženském rodě. |
| **Hlasový rozhovor** | Mluv přes mikrofon a poslouchej český ženský hlas. Přepis i syntéza jsou lokální. |
| **Práce s kódem** | Vyber projekt. TRIX může vypsat, přečíst, vytvořit nebo upravit jeho textové soubory. |
| **Spouštění příkazů** | Nech ji spustit testy nebo příkaz v pracovní složce; platí limit 60 sekund. |
| **Weby a aplikace** | Otevře požadovanou stránku ve výchozím prohlížeči nebo aplikaci podle jejího bundle ID. |
| **Vrácení úpravy** | V panelu vrať poslední vlastní zápis TRIX, pokud se soubor mezitím nezměnil. |
| **Ovládání z notche** | Skrytý panel, jemné fialové halo, rychlé psaní a hlas. Na displeji bez notche funguje horní střed obrazovky. |

Zkus například:

> „Otevři https://github.com.“
>
> „Prohlédni můj projekt a vysvětli, kde se vykresluje hlavní obrazovka.“
>
> „Uprav tento soubor a spusť odpovídající testy.“

![Ilustrační pracovní prostředí pro kódování a hlasový rozhovor s TRIX](docs/assets/trix-workspace.png)

<sub>Ilustrační fotografie vytvořená pomocí imagegen; nejde o skutečný screenshot.</sub>

## Instalace

1. V [Releases](https://github.com/HSko27/TRIX/releases/tag/v0.6.0-beta) stáhni **TRIX-0.6.0-beta-macOS-arm64.zip**. ZIP má přibližně **1,2 GB**.
2. Rozbal ho a přetáhni **TRIX AI.app** do složky **Aplikace**.
3. Spusť TRIX. Tato beta má **ad hoc podpis, bez Apple Developer ID a notarizace**. macOS ji může zablokovat jako software neověřeného vývojáře. Pokud se nespustí, podívej se na [řešení potíží](docs/INSTALLATION.md#macos-aplikaci-zablokoval).
4. Přejeď kurzorem na notch a zvol **Stáhnout a připravit model**. První nastavení vyžaduje internet a stáhne Qwen3.5:9b, přibližně **6–7 GB**. Průběh uvidíš v panelu.
5. Pro práci s kódem vyber vlastní projekt. Pro hlasový vstup povol mikrofon při prvním použití.

Python, Ollama, Whisper a české hlasy jsou součástí aplikace. Pro běžné používání nepotřebuješ Xcode, terminál ani původní projekt.

### Co potřebuješ

| | Požadavek |
| :--- | :--- |
| Mac | **Apple Silicon**, M1 a novější; Intel a Windows toto vydání nepodporuje |
| Systém | **macOS 14+**; fyzicky ověřeno na M5, nikoli na všech podporovaných Macích |
| Paměť | Doporučeno **24 GB RAM**; výkon na jiných konfiguracích se může lišit |
| Disk | Alespoň **18 GB volného místa** pro ZIP, rozbalení aplikace a model |
| Internet | Pro první stažení modelu a činnosti, které samy používají síť |

[Podrobný návod, kontrola staženého souboru a řešení potíží →](docs/INSTALLATION.md)

## Soukromí a hranice aplikace

TRIX používá **Qwen3.5:9b přes lokální Ollamu**, **Whisper small** pro přepis a **Pocket TTS Czech** pro výchozí ženský hlas. Obsah chatu, přepis ani hlasová syntéza se neposílají cloudové AI službě. Stažení modelů, otevírané weby a některé zadané příkazy mohou používat internet.

Modely a log vlastní služby se ukládají do `~/Library/Application Support/TRIX AI`. Pokud už běží Ollama na `127.0.0.1:11434`, aplikace použije tuto službu a její modely. Konverzace a historie vrácení úprav jsou pouze pro aktuální spuštění. Po ukončení aplikace může vlastní backend zůstat spuštěný.

Akce probíhají bez opakovaného klikání na potvrzení. **Shellové příkazy běží s oprávněními přihlášeného uživatele a nejsou omezené na vybranou složku.** Ochrana cest souborových nástrojů není sandbox pro shell. Pracuj s verzovaným projektem a zadávej konkrétní úkoly. Vrácení zápisu nevrací účinky shellových příkazů.

TRIX zatím neovládá libovolná tlačítka ostatních aplikací ani nečte obrazovku. Hlas může mít chyby výslovnosti a model se může mýlit. Jde o beta verzi; čistá instalace na druhém Macu zatím nebyla ověřená.

## V tomto vydání

- Opravené ořezávání odpovědí zaoblenou bublinou.
- Přenositelná aplikace s přibalenými runtimy a hlasy.
- Stažení modelu přímo v panelu, včetně průběhu a možnosti zastavení.
- Český ženský rod, čisté černošedé rozhraní a fialové halo.
- Ochrana před opakovaným provedením stejné akce v jednom úkolu; samotné otevření webu úkol dokončí.

## Zdrojový projekt

Repozitář obsahuje Swift/SwiftUI zdroje, hlasové skripty, regresní testy a dokumentaci. Velké runtimy a modely jsou v instalačním vydání, nikoli v Git historii. [Postup sestavení a testů](docs/DEVELOPMENT.md).

Licence třetích stran najdeš v [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) a přímo v aplikaci. Zdrojový kód TRIX je zveřejněný k nahlédnutí; samostatná open-source licence TRIX zatím není udělena.

Nalezený problém popiš v [Issues](https://github.com/HSko27/TRIX/issues). Přidej verzi macOS, typ Macu, verzi TRIX a postup, kterým se chyba dá zopakovat. Nesdílej soukromý obsah projektu ani přístupové údaje.
