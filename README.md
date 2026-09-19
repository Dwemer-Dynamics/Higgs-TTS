# Dwemer Higgs TTS service

Local Higgs TTS 3 integration for CHIM, Stobe and Dialectic. Uses a pinned
audio.cpp CUDA runtime and the official Boson model weights. No weights, voice
samples, binaries or credentials are stored in this repository.

This is an optional, experimental service. Public distribution is pending
licensing clearance; see [NOTICE.md](NOTICE.md). Installing the service does not
select it in a game server or replace another TTS installation.

## Installation

The DwemerDistro launcher is the intended installation surface. For development,
install the distro's CUDA dependencies first, clone this repository to
`/home/dwemer/higgs-tts` as `dwemer`, then run `bash install.sh` as that user.
Dependencies: Git, CMake, a C++ compiler, the selected NVIDIA CUDA toolkit,
Python 3, curl and util-linux. Python is used for setup/status only.

The installer verifies model size and upstream Git/LFS hashes and pins both
source and model revisions in `runtime.json`. Interrupted downloads may be
retried. Existing voices and server configuration are retained. Stop the service
before reinstalling. Keep the previous runtime revision until the new one has
passed validation.

## Service controls

Run these through the distro launcher, or as root during development:

```sh
/home/dwemer/higgs-tts/service.sh start
/home/dwemer/higgs-tts/service.sh status
/home/dwemer/higgs-tts/service.sh stop
/home/dwemer/higgs-tts/service.sh enable
/home/dwemer/higgs-tts/service.sh disable
```

Enable/disable controls the distro startup marker. Start/stop controls the
current process. Stop releases model GPU allocations; it does not remove files.
Startup is lazy: a healthy HTTP server does not mean the model is already loaded.
Logs are in `server.log`.

The full-precision development test on an RTX 4090 used roughly 9–10 GB additional
VRAM (estimated, not an isolated peak measurement). Short CHIM requests took
1.5–1.9 seconds warm and 15–31 seconds after restart. These are observations, not
minimum requirements or performance guarantees. Allow room for the game and
other GPU services. Q8 is not yet the validated installer default.

## API and voices

Default address: `http://127.0.0.1:8025`.

- `GET /health`: runtime readiness.
- `GET /v1/models`: model `higgs-v3`, family `higgs_audio_tts`.
- `GET /v1/audio/voices?model=higgs-v3`: configured voice names.
- `POST /v1/audio/speech`: WAV synthesis.

```json
{"model":"higgs-v3","input":"Welcome to Whiterun.","voice":"malenord"}
```

Put reference WAV files in `voices/` to use named voices. A local connector may
instead pass `voice_ref` with an accessible reference path. Optional
`reference_text` must match that recording. Cloning does not train a new model.
Missing samples should be reported by the connector or use its explicit fallback;
the service does not substitute a built-in PocketTTS voice.

`server.json` controls binding, port, voice directory and generation limits. Keep
the default loopback binding. For a trusted remote deployment, provision voices
on the inference host and use their names; a path on a different host is not a
valid reference. The raw inference API is unauthenticated and must not be exposed
to the public internet. Do not enable upstream UI management for this service.

## Validation and rollback

Validate clean install and reinstall, content verification failures, repeated
start/stop, wrong-service port conflicts, permissions, and male/female reference
changes. Exercise each mod's connector and existing audio filters separately.
Source tests and API synthesis do not establish in-game playback.

Disable the service and select the previous TTS connector to roll back. Model
and voice deletion should be an explicit uninstall choice, not part of disabling
or updating the service.
