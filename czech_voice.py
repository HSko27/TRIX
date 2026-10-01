"""Offline Czech Pocket TTS with a licensed female voice reference."""
import json
import re
import os
import sys
import tempfile
from pathlib import Path

os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
import numpy as np
import scipy.io.wavfile
import torch
import yaml
from pocket_tts import TTSModel


def main():
    request = json.load(sys.stdin)
    text = request["text"].strip()[:1000].replace("TRIX", "Triks").replace("Trix", "Triks")
    assets = Path(__file__).resolve().parent / "Voices/pocket-czech"
    config = yaml.safe_load((assets / "config.yaml").read_text())
    config["weights_path"] = str(assets / "model.safetensors")
    config["flow_lm"]["lookup_table"]["tokenizer_path"] = str(assets / "tokenizer.model")
    torch.set_num_threads(4)
    torch.manual_seed(17)
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as config_file:
        yaml.safe_dump(config, config_file)
        config_file.flush()
        model = TTSModel.load_model(config=config_file.name, temp=0.3)
        state = model.get_state_for_audio_prompt(str(assets / "female-reference.wav"), truncate=True)
        chunks = []
        for sentence in re.split(r"(?<=[.!?])\s+", text):
            if not sentence.strip():
                continue
            audio = model.generate_audio(state, sentence)
            if chunks:
                chunks.append(np.zeros(int(model.sample_rate * 0.18), dtype=np.float32))
            chunks.append(audio.detach().cpu().numpy())
    samples = np.concatenate(chunks)
    if samples.size == 0:
        raise ValueError("Hlas nevytvořil zvuk")
    scipy.io.wavfile.write(request["output"], model.sample_rate, (np.clip(samples, -1, 1) * 32767).astype(np.int16))


if __name__ == "__main__":
    main()
