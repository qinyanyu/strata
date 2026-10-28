# Community benchmark on HL-225

Measured on 2026-10-27 with `tools/strata_bench.py` (suite 1, 3 runs per test, medians with ranges). Speeds are the engine's own timings; first-token times are measured by the client over HTTP. Speed only: no correctness check was run.

## Hardware and software

- GPU and VRAM: HL-225, 96 GiB VRAM
- CPU: Intel(R) Xeon(R) CPU E5-2696 v3 @ 2.30GHz (18 cores, 36 threads); installed RAM: 251.6 GiB; storage: not measured
- OS: Linux 6.8.0-136-generic; GPU driver: not read; CUDA: not read
- Strata: project 0.1.44.1, commit not a git checkout; engine strata-hpu-0.1.0
- Background workloads and power limits: not recorded

## Model and configuration

- Model and quantization: qwen3.8-flash-next-uncensored-iq4_xs
- Context: 262144 tokens; parallel slots: 1
- Settings: the install's own configuration, unchanged; thinking off for the suite; temperature 0

## Method

Run by `python tools/strata_bench.py --long` against the HTTP API of a Strata server (already running); model loading is not timed. One warm-up chat and a 1K prompt are discarded first. Every prompt starts with a unique tag, so the conversation cache cannot help the fresh-prompt tests.

- short chat: the three questions of `tools/ab_engine.py`, up to 100 new tokens, 3 runs
- 4K / 16K prompts: generated word lists sized by a calibration request, 24 new tokens, 3 fresh prompts each
- agent session: system prompt and four tools, then 5 turns that each add about 1500 words of a project file and continue from the model's own earlier answers (the way agent clients resend a conversation), 64 new tokens per turn, 3 sessions; the cache numbers come from the answer's usage (`cached_tokens`) and timings (`prompt_n`)
- concurrency (when run): N requests sent at the same moment, total tokens over the wall time of the burst, latency over all requests

## Results

| Configuration | Actual prompt tokens | Reused tokens | Generated tokens | Runs | Prompt tok/s median and range | Decode tok/s median and range | TTFT seconds median and range |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- |
| short chat | 46 (43-51) | 0 | 100 (100-100) | 9 | not measured | 126.8 (107.7-190.8) | 0.28 (0.27-0.47) |
| 4K prompt, fresh | 4019 (4019-4019) | 0 (0-0) | 24 cap | 3 | 2058.9 (2050.4-2067.6) | not measured | 1.98 (1.98-1.99) |
| 16K prompt, fresh | 16058 (16058-16058) | 0 (0-0) | 24 cap | 3 | 3101.5 (1340.4-3102.6) | not measured | 5.23 (5.22-12.23) |
| 32K prompt, fresh | 32049 (32049-32049) | 0 (0-0) | 24 cap | 3 | 3181.3 (2370.6-3183.6) | not measured | 10.15 (10.14-13.80) |
| agent session, follow-up turns | 15494 (15480-15546) at the last turn | see below | up to 64 | 3 | see below | 110.0 (94.9-129.9) | 1.53 (1.09-3.01) |

Ranges are the lowest and highest of the runs; `Runs` counts requests that returned a token.

### Agent session (conversation cache)

Cache hit over the follow-up turns: 65.8 % (65.8-65.9); earlier-turn tokens read again per session: 3 (2-4) (earlier turns that the cache did not hold; the 14679 (14679-14680) new tokens of the files are read once); first turn (nothing cached) first token: 0.63 s (0.62-1.50).

| Turn (run 1) | Prompt tokens | Reused | Read | Prompt tok/s | First token (s) | Decode tok/s |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 609 | 0 | 609 | 668.7 | 1.5 | 25.6 |
| 1 | 2095 | 626 | 1469 | 1003.4 | 1.5 | 113.6 |
| 2 | 5539 | 2158 | 3381 | 2216.0 | 1.569 | 101.6 |
| 3 | 8465 | 5603 | 2862 | 1221.8 | 2.39 | 120.4 |
| 4 | 11379 | 8480 | 2899 | 977.3 | 3.013 | 118.5 |
| 5 | 15494 | 11422 | 4072 | 1431.8 | 2.9 | 109.9 |

Per-request data: `results.json`. Engine log lines from the start: `engine-log-excerpt.txt` (when this run started the server).

## Correctness and limitations

Not measured: this is a speed suite. The conversation uses the model's own replies, so token counts differ a little between runs. Machine details come from the server, `nvidia-smi`/`rocm-smi` and the OS; background load and power limits are not recorded. Total time of the suite: 114 s.
