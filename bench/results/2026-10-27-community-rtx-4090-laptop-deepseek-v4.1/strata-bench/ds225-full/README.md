# Community benchmark on NVIDIA GeForce RTX 4090 Laptop GPU

Measured on 2026-10-27 with `tools/strata_bench.py` (suite 1, 3 runs per test, medians with ranges). Speeds are the engine's own timings; first-token times are measured by the client over HTTP. Speed only: no correctness check was run.

## Hardware and software

- GPU and VRAM: NVIDIA GeForce RTX 4090 Laptop GPU, 16 GiB VRAM
- CPU: 13th Gen Intel(R) Core(TM) i9-13900HX (24 cores, 32 threads); installed RAM: 94.0 GiB; storage: zram0; nvme1n1 WD_BLACK SN850X 2000GB nvme; nvme0n1 WD_BLACK SN850X 4000GB nvme
- OS: Linux 6.18.57-gentoo-dist-bin; GPU driver: 615.78.08; CUDA (driver supports up to): 13.4; engine built for CUDA 13.0
- Strata: project 0.1.52, commit 5e8a4cca; engine ds4-0.1
- GPU detail (after the run, near idle): power_limit_w=[N/A], power_draw_w=78.03, pcie=gen4 x16, pstate=P0, temp_c=66
- Background workloads: not recorded (GPU power limit/draw read above)

## Model and configuration

- Model and quantization: deepseek-v4.1-flash
- Context: 262144 tokens; parallel slots: 1
- Settings: the install's own configuration, unchanged; thinking off for the suite; temperature 0

```text
strata-dsv41 --pack deepseek-v4.1-flash-ist-das-2.25bpw --max-context 262144 --eos 1 --vision on --dspark auto --dspark-conf 0.65 --experts 6
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
| short chat | 32 (29-38) | 0 | 100 (100-100) | 9 | not measured | 11.2 (10.8-12.6) | 2.79 (2.01-3.17) |
| 4K prompt, fresh | 4125 (4125-4125) | 0 (0-0) | 24 cap | 3 | 387.0 (364.6-394.2) | not measured | 10.67 (10.47-11.32) |
| 16K prompt, fresh | 16562 (16562-16562) | 0 (0-0) | 24 cap | 3 | 698.5 (619.8-700.0) | not measured | 23.74 (23.69-26.75) |
| 32K prompt, fresh | 33126 (33126-33126) | 0 (0-0) | 24 cap | 3 | 754.6 (753.1-783.4) | not measured | 43.95 (42.33-44.03) |
| agent session, follow-up turns | 12559 (12540-12574) at the last turn | see below | up to 64 | 3 | see below | 13.5 (11.2-16.0) | 11.63 (11.05-12.94) |

Ranges are the lowest and highest of the runs; `Runs` counts requests that returned a token.

### Agent session (conversation cache)

Cache hit over the follow-up turns: 69.7 % (69.6-69.7); earlier-turn tokens read again per session: 5 (5-5) (earlier turns that the cache did not hold; the 11682 (11680-11682) new tokens of the files are read once); first turn (nothing cached) first token: 10.55 s (10.48-11.21).

| Turn (run 1) | Prompt tokens | Reused | Read | Prompt tok/s | First token (s) | Decode tok/s |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 602 | 0 | 602 | 53.7 | 11.209 | 11.6 |
| 1 | 3289 | 643 | 2646 | 204.7 | 12.942 | 11.2 |
| 2 | 4807 | 3352 | 1455 | 126.3 | 11.538 | 12.6 |
| 3 | 7919 | 4870 | 3049 | 244.7 | 12.478 | 13.8 |
| 4 | 9960 | 7980 | 1980 | 174.2 | 11.385 | 14.6 |
| 5 | 12574 | 10017 | 2557 | 213.3 | 12.009 | 13.4 |

Per-request data: `results.json`. Engine log lines from the start: `engine-log-excerpt.txt` (when this run started the server).

## Correctness and limitations

Not measured: this is a speed suite. The conversation uses the model's own replies, so token counts differ a little between runs. Machine details come from the server, `nvidia-smi`/`rocm-smi` and the OS; background load is not recorded. Total time of the suite: 660 s.
