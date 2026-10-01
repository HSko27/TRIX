# Instalace TRIX 0.6.0 beta

## Stažení

Otevři [nejnovější vydání](https://github.com/HSko27/TRIX/releases/latest) a v Assets vyber `TRIX-0.6.0-beta-macOS-arm64.zip`. Tlačítko Code → Download ZIP stahuje pouze zdrojový projekt, nikoli hotovou aplikaci.

Rozbal instalační ZIP a přetáhni `TRIX AI.app` do Aplikací. Velké runtimy jsou přibalené; aplikaci můžeš používat bez vývojového projektu.

## První spuštění

1. Otevři TRIX z Aplikací.
2. Panel vyvolej najetím na notch; pokud jej displej nemá, použij horní střed obrazovky.
3. Zvol **Stáhnout a připravit model**. Model má přibližně 6–7 GB. Nech aplikaci otevřenou až do dokončení; stahování lze zastavit a zkusit znovu.
4. Vyber pracovní složku pro práci se soubory nebo kódem.
5. Mikrofon povol až při použití hlasového vstupu. Výběr hlasu a jeho ukázku najdeš v nabídce nastavení.

## macOS aplikaci zablokoval

Toto vydání má pouze ad hoc podpis a není notarizované Applem. macOS může spuštění stažené aplikace zablokovat. TRIX sama nevypíná ochrany systému. Nejde o vydání v App Storu ani software ověřený Applem. Pokud beta verzi nechceš spouštět, počkej na vydání s Developer ID a notarizací. Samotný SHA-256 nepotvrzuje důvěryhodnost autora.

## Kontrola ZIPu

Z téhož vydání stáhni `SHA256SUMS.txt` do stejné složky jako ZIP. V Terminálu přejdi do této složky a spusť:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Výsledek pro ZIP má být `OK`. Kontrola ověřuje shodu s vydaným souborem a pomůže odhalit neúplné stažení.

## Když model nebo hlas nereaguje

- Zkontroluj volné místo a internet při prvním stahování.
- Pokud už používáš Ollamu, TRIX se připojí na `127.0.0.1:11434`. Model `qwen3.5:9b` musí být v této službě dostupný.
- Vlastní backend zapisuje log do `~/Library/Application Support/TRIX AI/ollama-server.log`.
- Při problému s hlasem zkus jiný hlas v nastavení. Vlastní syntéza může být pomalejší podle výkonu a délky textu.
- V nastavení macOS ověř povolení mikrofonu pro TRIX AI.

## Aktualizace a ukončení

TRIX nemá automatický aktualizátor. Před výměnou aplikace ukonči starou verzi a nahraď ji novou. Stažený model se ukládá mimo aplikaci, takže ho běžná výměna `.app` neodstraní. Historie konverzace a vrácení zápisů se po ukončení neuchovává. Lokální backend může po zavření panelu nebo ukončení aplikace dále běžet.

Ověřená konfigurace: Mac M5, 24 GB RAM. Sestavení míří na Apple Silicon a macOS 14+, ale čistá instalace na druhém Macu zatím nebyla otestovaná.
