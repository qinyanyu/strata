# Community benchmark on NVIDIA GeForce RTX 4090 Laptop GPU

Measured on 2026-10-27 with `tools/strata_bench.py` (suite 1, 3 runs per test, medians with ranges). Speeds are the engine's own timings; first-token times are measured by the client over HTTP. Speed only: no correctness check was run.

## Hardware and software

- GPU and VRAM: NVIDIA GeForce RTX 4090 Laptop GPU, 16 GiB VRAM
- CPU: 13th Gen Intel(R) Core(TM) i9-13900HX (24 cores, 32 threads); installed RAM: 94.0 GiB; storage: zram0; nvme1n1 WD_BLACK SN850X 2000GB nvme; nvme0n1 WD_BLACK SN850X 4000GB nvme
- OS: Linux 6.18.57-gentoo-dist-bin; GPU driver: 615.78.08; CUDA (driver supports up to): 13.4; engine built for CUDA 13.0
- Strata: project 0.1.52, commit 5e8a4cca; engine ds4-0.1
- GPU detail (after the run, near idle): power_limit_w=[N/A], power_draw_w=81.57, pcie=gen4 x16, pstate=P0, temp_c=66
- Background workloads: not recorded (GPU power limit/draw read above)

## Model and configuration

- Model and quantization: deepseek-v4.1-flash
- Context: 262144 tokens; parallel slots: 1
- Settings: the install's own configuration, unchanged; thinking off for the suite; temperature 0

```text
strata-dsv41 --pack deepseek-v4.1-flash-ist-das-2.25bpw --max-context 262144 --eos 1 --vision on --dspark auto --dspark-conf 0.65
```

## Method

Run by `python tools/strata_bench.py --long` against the HTTP API of a Strata server (started by the benchmark from the install configuration); model loading is not timed. One warm-up chat and a 1K prompt are discarded first. Every prompt starts with a unique tag, so the conversation cache cannot help the fresh-prompt tests.

- short chat: the three questions of `tools/ab_engine.py`, up to 100 new tokens, 3 runs
- 4K / 16K prompts: generated word lists sized by a calibration request, 24 new tokens, 3 fresh prompts each
- agent session: system prompt and four tools, then 5 turns that each add about 1500 words of a project file and continue from the model's own earlier answers (the way agent clients resend a conversation), 64 new tokens per turn, 3 sessions; the cache numbers come from the answer's usage (`cached_tokens`) and timings (`prompt_n`)
- concurrency (when run): N requests sent at the same moment, total tokens over the wall time of the burst, latency over all requests

## Results

| Configuration | Actual prompt tokens | Reused tokens | Generated tokens | Runs | Prompt tok/s median and range | Decode tok/s median and range | TTFT seconds median and range |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- |
| short chat | 32 (29-38) | 0 | 100 (100-100) | 9 | not measured | 13.6 (13.0-15.3) | 2.07 (1.18-2.36) |
| 4K prompt, fresh | 4125 (4125-4125) | 0 (0-0) | 24 cap | 3 | 436.2 (391.8-442.6) | not measured | 9.46 (9.33-10.54) |
| 16K prompt, fresh | 16562 (16562-16562) | 0 (0-0) | 24 cap | 3 | 758.7 (694.2-759.6) | not measured | 21.86 (21.83-23.88) |
| 32K prompt, fresh | 33126 (33126-33126) | 0 (0-0) | 24 cap | 3 | 799.6 (794.3-816.0) | not measured | 41.48 (40.64-41.75) |
| agent session, follow-up turns | 12556 (12555-12557) at the last turn | see below | up to 64 | 3 | see below | 16.0 (14.3-19.3) | 10.96 (10.20-11.85) |

Ranges are the lowest and highest of the runs; `Runs` counts requests that returned a token.

### Agent session (conversation cache)

Cache hit over the follow-up turns: 69.7 % (69.6-69.7); earlier-turn tokens read again per session: 5 (5-5) (earlier turns that the cache did not hold; the 11681 (11681-11681) new tokens of the files are read once); first turn (nothing cached) first token: 9.48 s (8.65-9.51).

| Turn (run 1) | Prompt tokens | Reused | Read | Prompt tok/s | First token (s) | Decode tok/s |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 602 | 0 | 602 | 63.5 | 9.483 | 14.7 |
| 1 | 3284 | 638 | 2646 | 225.4 | 11.758 | 14.3 |
| 2 | 4800 | 3346 | 1454 | 141.5 | 10.288 | 15.7 |
| 3 | 7898 | 4850 | 3048 | 265.6 | 11.497 | 16.3 |
| 4 | 9942 | 7961 | 1981 | 193.2 | 10.276 | 19.2 |
| 5 | 12557 | 10000 | 2557 | 233.9 | 10.955 | 16.3 |

Per-request data: `results.json`. Engine log lines from the start: `engine-log-excerpt.txt` (when this run started the server).

## Correctness and limitations

Not measured: this is a speed suite. The conversation uses the model's own replies, so token counts differ a little between runs. Machine details come from the server, `nvidia-smi`/`rocm-smi` and the OS; background load is not recorded. Total time of the suite: 587 s.
