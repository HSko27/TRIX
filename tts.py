"""Local Czech neural speech. Input JSON arrives on stdin, never in shell arguments."""
import json
import re
import unicodedata
import sys
import wave
from pathlib import Path

import numpy as np
import sherpa_onnx


def prepare_czech(text):
    text = unicodedata.normalize("NFC", text)
    # Spoken forms are separate from the written reply shown in the panel.
    replacements = {
        "trix": "Triks", "qwen": "Kven", "macbook": "Mekbuk",
        "python": "Pajton", "github": "Git hab", "google": "Gůgl",
        "ai": "umělá inteligence", "ui": "rozhraní", "ux": "ovládání",
    }
    for word, spoken in replacements.items():
        text = re.sub(r"\b" + word + r"\b", spoken, text, flags=re.I)
    for word, spoken in [("např.", "například"), ("atd.", "a tak dále"), ("tzn.", "to znamená")]:
        text = text.replace(word, spoken)
    text = text.replace("…", ". ").replace("—", ", ").replace("–", ", ")
    return re.sub(r"\s+", " ", text).strip()


def main():
    request = json.load(sys.stdin)
    text = prepare_czech(request["text"].strip()[:1000])
    if not text:
        raise ValueError("Prázdný text")
    project = Path(__file__).resolve().parents[2]
    female = request.get("engine", "coqui") == "coqui"
    local_piper = Path(__file__).resolve().parent / "Voices/vits-piper-cs_CZ-jirka-medium"
    model = Path(__file__).resolve().parent / "Voices/vits-coqui-cs-cv" if female else local_piper if local_piper.exists() else project / "work/runtime/vits-piper-cs_CZ-jirka-medium"
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=str(model / ("model.onnx" if female else "cs_CZ-jirka-medium.onnx")),
                tokens=str(model / "tokens.txt"),
                data_dir="" if female else str(model / "espeak-ng-data"),
                noise_scale=0.35 if female else 0.5,
                noise_scale_w=0.4 if female else 0.6,
                length_scale=1.0,
            ),
            num_threads=2,
            provider="cpu",
            debug=False,
        ),
        max_num_sentences=2,
    )
    if not config.validate():
        raise ValueError("Neplatný hlasový model")
    tts = sherpa_onnx.OfflineTts(config)
    # Generate sentences independently so the voice does not run clauses together.
    sentences = re.split(r"(?<=[.!?])\s+", text)
    chunks = []
    sample_rate = None
    for sentence in sentences:
        if not sentence.strip():
            continue
        audio = tts.generate(sentence, sid=0, speed=0.92 if female else 0.97)
        if len(audio.samples) == 0:
            raise ValueError("Hlasový model nevytvořil zvuk")
        sample_rate = audio.sample_rate
        if chunks:
            chunks.append(np.zeros(int(sample_rate * 0.18), dtype=np.float32))
        chunks.append(np.asarray(audio.samples, dtype=np.float32))
    samples = (np.clip(np.concatenate(chunks), -1, 1) * 32767).astype("<i2")
    with wave.open(request["output"], "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(samples.tobytes())


if __name__ == "__main__":
    main()
