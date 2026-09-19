# Upstream components and distribution status

This repository maintains service integration. It contains no model weights,
voice samples or vendored inference implementation.

The installer retrieves a pinned revision of audio.cpp from its upstream GitHub
repository. Its license and notices remain in the installed source directory.

Higgs TTS 3 weights are governed by the Boson Higgs TTS 3 Research and
Non-Commercial License, not the audio.cpp license. The downloader retains the
upstream LICENSE alongside the model. See:
https://huggingface.co/bosonai/higgs-tts-3-4b/blob/main/LICENSE

Public product distribution is pending confirmation of appropriate rights from
Boson AI. Downloading weights separately is not a substitute for that clearance.
