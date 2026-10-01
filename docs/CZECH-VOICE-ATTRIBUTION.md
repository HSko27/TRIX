# Czech Pocket TTS — attribution

Czech model by Václav Volhejn: https://huggingface.co/vvolhejn/pocket-tts-czech
Weights and Czech tokenizer revision: b7eead893ec18b1f493c1c044e1b3e8b2a46b863. Model trained on ParCzech4Speech, ÚFAL, Charles University corpus authors; https://huggingface.co/datasets/ufal/ParCzech4Speech. Model and corpus: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/.

Female Czech voice reference: cs_f_vahalova.wav from the model author's held-out ParCzech samples, https://huggingface.co/vvolhejn/pocket-tts-czech/tree/main/voices. Source https://huggingface.co/vvolhejn/pocket-tts-czech/resolve/main/voices/cs_f_vahalova.wav. Distributed with the Czech model under CC BY 4.0; attribution to Václav Volhejn and the ParCzech4Speech corpus authors at ÚFAL, Charles University. Used as a generic Czech assistant voice, not to present TRIX as the original speaker.

An earlier test used Alba MacKenna's licensed Casual reference from Kyutai (CC BY 4.0), but it is no longer the active reference.

Runtime: Pocket TTS 3.3.0 by Kyutai, installed from PyPI in work/pocket-env. All runtime model paths are local, with HF_HUB_OFFLINE=1. Configuration copied from the Czech model and local asset paths substituted at load time. No model training or weight modification; voice is generated separately per sentence to avoid omitted endings.
