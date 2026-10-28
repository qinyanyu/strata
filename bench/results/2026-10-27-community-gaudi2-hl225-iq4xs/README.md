# 2026-10-27 — community: one Intel Gaudi2 (HL-225, 96 GB), Qwen3.8-Flash-Next-Uncensored IQ4_XS, 262K context

A first datapoint for Strata on an Intel Gaudi2 accelerator. This is **not** the CUDA/HIP/SYCL engine: it is a
separate native backend (`hpu/`) in a fork,
[JChen-318/gaudi2-single-card-strata](https://github.com/JChen-318/gaudi2-single-card-strata). The fork is based
on Strata `296b59d` and keeps Strata's server (`serve/`), which this run talks to through the normal HTTP API. Each
model layer is a SynapseAI graph on the MME (matrix) and TPC (vector) engines, with about 110 custom TPC kernels. The
whole model is resident on the card: 512 experts × 48 layers as IQ4 codes plus scales, about 76 GB of HBM.

## Machine
- 1 × Intel Gaudi2 HL-225, 98,304 MiB HBM; habanalabs driver / SynapseAI 1.24.1
- Xeon E5-2696 v3 (18c/36t, AVX2, no AVX-512), 251.6 GiB RAM, Ubuntu 24.04.4 (kernel 6.8.0-136)
- Model files on a CIFS network share; their pages were already in the host page cache, and model load is not timed.
- Other light containers (web services) were running on the host. None of them uses the Gaudi card.

## Engine / config
- Fork commit `2745775`. The server ran in the fork's Docker image (`hpu/docker/Dockerfile`, on Habana's 1.24.1 Ubuntu 24.04 base).
- Model: [orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF](https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF) IQ4_XS (3 shards).
- Speculative decoding: [incoai/Qwen3.8-Flash-Next-DFlash2](https://huggingface.co/incoai/Qwen3.8-Flash-Next-DFlash2) drafter, block 4.
  Each draft step is verified as one 4-row window of the target model. Greedy for these runs.
- Engine flags: `--max-context 262144 --prefill 8192 --spec-prob --hbm-limit-mib 94208 --vram-reserve-mib 2048`.
  - The performance environment switches are in `engine-config.json`: the container's config template with the
    model, drafter and tokenizer paths as placeholders.
  - Every `STRATA_HPU_*` switch is documented in the fork's `hpu/include/strata/hpu/performance_modes.hpp`.
- One request at a time (`parallel slots: 1`). After start, the container warms the prompt-tail graphs with three
  prompts, so first-use graph compiles do not land in the measured runs. Compiles for a context size the server has
  not seen yet do still happen; see "Limits".

## 1. `tools/strata_bench.py --long` (suite 1, thinking off, temperature 0)

| test | runs | prompt tok/s | decode tok/s | TTFT |
|---|---:|---:|---:|---:|
| short chat (43-51 tok, 100 new) | 9 | — | **126.8** (107.7-190.8) | 0.28 s (0.27-0.47) |
| 4,019 tok fresh | 3 | **2058.9** (2050.4-2067.6) | — | 1.98 s |
| 16,058 tok fresh | 3 | **3101.5** (1340.4 / 3101.5 / 3102.6) | — | 5.23 s (5.22-12.23) |
| 32,049 tok fresh | 3 | **3181.3** (2370.6 / 3181.3 / 3183.6) | — | 10.15 s (10.14-13.80) |
| agent session, follow-up turns | 15 | cache hit 65.8 % | 110.0 (94.9-129.9) | 1.53 s (1.09-3.01) |

The first 16K and 32K runs include compiling the graphs for a context size this server had not seen before (see
"Limits"). The tool's own report is `strata-bench-report.md`, and every request is in `results.json`.

## 2. Prompt sweep, 256-token cap (3 fresh prompts each; medians, all values)

This sweep uses the same prompt builder, request and timing code as `tools/strata_bench.py` (`Suite.prompt_for`,
`chat`, `digest`), with thinking off and temperature 0. The values come from the engine's own `timings`.

| fresh tokens | prompt tok/s | TTFT | decode tok/s | generated | drafts accepted |
|---:|---:|---:|---:|---:|---:|
| 4,019 | **2085.8** (2083.4 / 2085.8 / 2088.1) | 1.96 s | **105.2** (115.2 / 105.2 / 98.6) | 144 / 136 / 147 | 237 / 561 (42 %) |
| 32,049 | **3179.4** (3188.1 / 3179.4 / 3177.7) | 10.15 s | **114.0** (112.5 / 114.3 / 114.0) | 163 / 164 / 151 | 286 / 573 (50 %) |
| 124,989 | **2915.2** (2585.7 / 2918.0 / 2915.2) | 43.08 s (48.53 / 43.00 / 43.08) | **106.0** (104.1 / 106.0 / 111.3) | 164 / 185 / 151 | 292 / 618 (47 %) |

- Every answer ended before the 256-token cap.
- The 128K run 1 includes first-use compiles.
- The per-request data, including draft counts, is in `sweep.json`, written by `sweep.py` in this folder. Run it as
  `python3 sweep.py http://127.0.0.1:8080 sweep.json` with the repository's `tools/` on the import path.
- Its fields are `tools/strata_bench.py`'s `digest()`:
  - `prompt_tps` and `decode_tps` in tokens per second, `prompt_tps_source`/`decode_tps_source` saying where each came from;
  - `ttft_s` and `total_s` in seconds;
  - `prompt_ms` and `decode_ms` in milliseconds;
  - `drafts_offered` and `drafts_accepted` in tokens.

## 3. Needle recall (`tools/needle_bench.py --lengths 32k,128k --depths 10,50,90`)
**6/6** correct: three depths at 32,778-32,779 tokens (10-11 s each) and three at 125,044-125,046 tokens (44 s each).
The data is in `needles.json`.

## Limits
- **This is a fork's backend, not an upstream build.** The fork is based on `296b59d`; upstream `main` was `5e8a4cc`
  on this date. No CUDA/HIP/SYCL build was involved.
- **First-use compiles.** The Gaudi backend compiles one graph set per prefill window size and per context key bucket.
  The first request that reaches a new size pays for the compile. Here that was the slower first run at 16K (12.2 s
  TTFT instead of 5.2 s), at 32K and at 128K. Later requests at the same size reuse the graphs. During decode,
  crossing a bucket boundary costs a one-off pause of about 0.2 s.
- **One request at a time.** One request's prefill pauses another request's decode. The concurrency test was not run.
- **Not recorded:** power and clocks, run-to-run variation across server restarts, and the `--clients` test.
  The needle runs are one pass per length and depth.
- All files are from one server session on 2026-10-27; `run-logs.txt` holds the three tools' console output.
