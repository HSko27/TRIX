# Third-party components in TRIX 0.6.0 beta

TRIX is distributed as a binary beta with source available for inspection in this repository. No separate open-source license to TRIX's own code has been granted.

- CPython 3.10.21, Python Software Foundation license; standalone distribution by Astral, 20260929, https://github.com/astral-sh/python-build-standalone. Licenses included with the runtime and native dependencies.
- Ollama 0.35.0, MIT, https://github.com/ollama/ollama. MIT license and vendor license notices included in Licenses and runtime/ollama.
- whisper.cpp 1.9.4, MIT, Georgi Gerganov, https://github.com/ggml-org/whisper.cpp. OpenAI Whisper small model, MIT, https://github.com/openai/whisper. Licenses in Licenses.
- Pocket TTS 3.3.0 by Kyutai, MIT, https://github.com/kyutai-labs/pocket-tts. Python package metadata and license included.
- Czech Pocket model and tokenizer by Václav Volhejn, CC BY 4.0; https://huggingface.co/vvolhejn/pocket-tts-czech. Derived from ParCzech4Speech, ÚFAL, Charles University corpus authors. Czech female reference cs_f_vahalova distributed with that model. Attribution and source in Voice/Voices/pocket-czech/ATTRIBUTION.md. License https://creativecommons.org/licenses/by/4.0/.
- Czech Coqui VITS model (optional older voice), @NeonGeckoCom, BSD-3-Clause according to the official Coqui model registry, https://github.com/coqui-ai/TTS/blob/dev/TTS/.models.json. ONNX export by csukuangfj; https://huggingface.co/csukuangfj/vits-coqui-cs-cv.
- Piper Czech Jirka model (optional male voice), CC0 dataset/model terms as provided in Voice/Voices/vits-piper-cs_CZ-jirka-medium/MODEL_CARD.
- sherpa-onnx 1.13.8, Apache 2.0, https://github.com/k2-fsa/sherpa-onnx. License in Licenses.
- PyTorch, NumPy, SciPy and other Python dependencies: licenses and notices in runtime/python/lib/python3.10/site-packages/*dist-info and each package's license directories. Those are retained in the distributed app.
- Qwen3.5:9b is downloaded on first setup by Ollama, not included in this ZIP. Model page https://ollama.com/library/qwen3.5; its own model terms apply.

Offline runtime voice synthesis points only to bundled weights and tokenizer. Per-sentence synthesis and licensed Czech speaker conditioning are the application-side modifications; model weights are not modified.
