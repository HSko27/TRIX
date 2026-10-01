# Vývoj a sestavení

TRIX je nativní macOS aplikace v Swift/SwiftUI s AppKit panelem u notche. `Sources/` obsahuje také regresní a souborové self-testy. `czech_voice.py` a `tts.py` jsou skripty pro přibalené lokální hlasy.

## Požadavky

Apple Silicon, macOS 14+, Swift 5.9 nebo novější a Xcode Command Line Tools. Sestavení níže používá systémový `swiftc`, nemá závislosti ze Swift Package Registry.

## Testy bez velkých modelů

```sh
git clone https://github.com/HSko27/TRIX.git
cd TRIX
bash scripts/build.sh --test
```

Testy nepotřebují modely ani mikrofon. Ověřují například cestovou ochranu, práci se soubory, vracení změn, dokončení navigačních úkolů a potlačení duplicitních akcí. Testovací binárku najdeš v `work/build/TRIXAI`.

## Kompletní aplikace

Velké nativní runtimy a hlasové modely jsou součástí release ZIPu, ne repozitáře. Stáhni a rozbal vydání TRIX 0.6.0 beta. Pak sestav vlastní zdrojový kód s Resources z této aplikace:

```sh
bash scripts/build.sh "/cesta/k/rozbalené/TRIX AI.app"
```

Výsledkem je `dist/TRIX AI.app`. Skript kopíruje přibalené Resources, sestaví aktuální Swift kód, spustí self-testy a přidá ad hoc podpis. Můžeš znovu spustit `bash scripts/build.sh`, pokud už Resources existují ve `dist/`. Tento postup nepřipravuje notarizované vydání.

Pokud měníš hlasové skripty, sestavení aktualizuje jejich kopie v Resources/Voice. Neměň soubory uvnitř distribuované podepsané aplikace po dokončení podpisu.

## Runtimy vydání 0.6.0

- CPython 3.10.21, python-build-standalone (20260929).
- Ollama 0.35.0, Qwen3.5:9b se stahuje až při prvním nastavení.
- whisper.cpp 1.9.4, statická arm64 sestava s cílem macOS 14 a `GGML_NATIVE=OFF`; model Whisper small.
- Pocket TTS 3.3.0 a český model/tokenizer `vvolhejn/pocket-tts-czech`.
- sherpa-onnx 1.13.8 pro alternativní lokální hlasy.

Resources původního vydání obsahují licence závislostí a hlasových modelů. Převzetím Resources z release se jejich licence zachovají. Tento repozitář zatím neobsahuje automatizovaný postup ke znovuvytvoření všech nativních runtimů a vah od začátku.

## Ověření beta vydání

Prošly Swift self-testy a regresní testy, kontrola podpisu, kontrola ZIPu a přenos hlasové syntézy i Whisperu do jiné složky. Ověřeno na M5/24 GB. První příprava modelu byla ověřena proti již staženému modelu; čistý plný download na druhém Macu zatím nebyl ověřen.
