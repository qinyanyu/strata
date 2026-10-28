# Community benchmark: DeepSeek V4.1-Flash on an RTX 4090 Laptop GPU (16 GB), 94 GiB RAM

Measured on 2026-10-27 and 28 by [30crows](https://github.com/30crows) on a Lenovo Legion notebook (model 82WQ). This tests
DeepSeek V4.1-Flash with Strata 0.2.7 and the release DeepSeek engine package 0.1.52 on an RTX 40 card.
[DEEPSEEK41.md](../../../docs/DEEPSEEK41.md) says that the package's sm_89 code was compiled but not yet run on one.
It ran here without errors in every test.

Tested:

- the IST-DAS 2.25 bpw set in the default mode (Faster, 5 of 6 experts), in Full quality (`--experts 6`) and with the
  DSpark drafter forced on
- the IST-DAS 2.00 bpw set in the default mode
- each with a 262,144-token context
- prompts from 4,096 to 250,000 tokens
- DeepSeek's quick tuner

Main results (medians):

- **2.25 bpw, default settings:**
  - decode 13.6 tokens/s on short chat, 16.0 in an agent session and 16.2 on code with thinking on
  - prompts read at 436 / 759 / 800 tokens/s at 4K / 16K / 32K
  - a 250,000-token prompt read at 664 tokens/s (377 s to the first token), then decoded at 13.9 tokens/s
- **2.00 bpw:** 2-19% faster than 2.25 on decode and on prompts up to 128K. At 250K the prompt was 6% slower (627
  against 664 tokens/s).
- **Full quality:** 15-18% slower decode than Faster, and 6-11% slower prompts.
- **DSpark forced on:** 76% of the drafted tokens were accepted on code, but decode did not change (15.9 against 16.0 and
  16.2 tokens/s). In the tuner's short test it was 31% slower. `--dspark auto`, which leaves the drafter unloaded on this
  card, was the right choice here.
- **Repeat:** the default 2.25 run repeated at the end of the night came within 4% of the first run on every speed. The
  agent turns' first-token time was 7% longer.

These are single-machine numbers with synthetic prompts. They do not establish answer quality (see
[Correctness and limitations](#correctness-and-limitations)).

## Hardware and software

- **GPU:** NVIDIA GeForce RTX 4090 Laptop GPU (AD103, compute capability 8.9), 16,376 MiB.
  - PCIe Gen 4 x16.
  - nvidia-smi reports a 175 W maximum power limit. GPU clocks were not fixed.
- **CPU:** Intel Core i9-13900HX, 8 P-cores and 16 E-cores (24 cores, 32 threads), no AVX-512.
  - Platform profile `performance`, turbo on, 5.2 GHz maximum.
- **RAM:** 2 x 48 GB DDR5 at 5,200 MT/s. Linux reports 94.0 GiB.
- **Swap:** 8 GiB zram (priority 100) and a 64 GiB swap file (priority 10).
- **Storage:** the model files are on a WD_BLACK SN850X 2 TB NVMe drive (LUKS, btrfs with `compress=zstd:3`).
- **Software:**
  - Gentoo Linux, kernel 6.18.57-gentoo-dist-bin, NVIDIA driver 615.78.08 (CUDA 13.4).
  - Strata source checkout at `main` 5e8a4cca (version 0.2.7), Python 3.14.7.
- **DeepSeek engine:** the release package `0.1.52-linux-x86_64-cuda-cuda13`, which setup fetched from the update feed.
  - Not a local build.
  - `BUILD.json`: source `f-027-rel a42cc3d7df70`, archs 86 / 89 / 120 plus PTX, CUDA 13.0.
  - `cuobjdump --list-elf` lists sm_86, sm_89 and sm_120 code in `strata-dsv41`.
  - SHA-256 of `strata-dsv41`: `5792fd39d3ea5ad2fd82fe4e88b5a4afd2edb15c051e87d05e1a01f17679692c`.
- **Background:** the runs were unattended (22:41 to 01:31 CET). No graphical session was running (X was never
  started). Besides system services, only the terminal session that drove the scripts was running.

## Model and configuration

DeepSeek-V4.1-Flash-1017, installed by the unmodified setup. Setup checks every file's SHA-256 against the pinned
revisions.

- **Experts:** `ISTA-DASLab/DeepSeek-V4.1-Flash-1017-GSQ-RCO-GGUF` at `cb02422c900df489cea5833e8a92171224059b3c`.
  - 2.25 bpw: `DeepSeek-V4.1-Flash-1017-GSQ-RCO-IQ2_XS-0000{1..4}-of-00004.gguf` (145 GiB)
  - 2.00 bpw: `DeepSeek-V4.1-Flash-1017-GSQ-RCO-IQ2_XXS-0000{1..4}-of-00004.gguf` (129 GiB)
- **Shared by both sets (112 GiB):**
  - `DeepSeek-V4.1-Flash-Engram-IQ4_NL.gguf`
  - `dspark-DeepSeek-V4.1-Flash-1017-Q8_0.gguf`
  - `mmproj-BF16.gguf`
  - the metadata shard `DeepSeek-V4.1-Flash-1017-UD-Q8_K_XL-00001-of-00009.gguf` from `unsloth/DeepSeek-V4.1-Flash-1017-GGUF`
    at `f924b94f19c1fea02c06a65c8475b0a45e2b88b1`
- **Packs:** made by setup with the shipped hot-expert profile.
- **Setup commands:**

  ```sh
  ./setup.sh --setup --yes --family deepseek41 --model IST-DAS-2.25bpw --context 262144 --no-start
  ./setup.sh --setup --yes --family deepseek41 --model IST-DAS-2.00bpw --context 262144 --no-start
  ```

  The 2.00 setup took 21 minutes, including its 138 GB download. The shared files were already there.

The engine command written by setup (paths shortened):

```text
strata-dsv41 --pack <data>/packs/deepseek-v4.1-flash-ist-das-2.25bpw --max-context 262144 --eos 1 --vision on --dspark auto --dspark-conf 0.65
```

The four configurations ([configs/](configs/)):

| Name | Set | Change to setup's command | Experts per token | DSpark |
| --- | --- | --- | ---: | --- |
| ds225-faster | 2.25 | none | 5 (`auto` picks Faster on a 16 GiB card) | not loaded (`auto`) |
| ds225-full | 2.25 | `--experts 6` | 6 | not loaded (`auto`) |
| ds225-dspark | 2.25 | `--dspark on` instead of `auto` | 5 | loaded, `--dspark-conf 0.65` |
| ds200-faster | 2.00 | none | 5 | not loaded (`auto`) |

**KV cache:** DeepSeek's own layout (window FP8, compressed KV FP4, index keys FP4). Strata has no switch for it.

**What the engine reported at start** ([logs/](logs/)):

- **2.25 set:**
  - The GPU held layers 0-39 and the head: 5.86 GB of weights and 642 of 15,360 experts (6.63 GB). 534 MiB was left free.
  - 14,718 routed experts (143 GB) were on the CPU lane with 24 threads, read in place from the model files.
  - The RAM store sized itself to 54 GB (about 4,740 slots of 11.4 MB) and read in the profile's hottest experts
    (43 GB) in 5.0-6.4 s.
  - The server reported ready 12-14 s after the start.
- **With `--dspark on`:** the drafter took VRAM, so only 309 experts fit on the GPU (5.84 GB).
- **2.00 set:** 731 experts on the GPU, and 5,235-5,296 RAM store slots of 10.3 MB.

## Method

All servers listened on 127.0.0.1 and ran one request at a time. The order of the night ([scripts/run-all.sh](scripts/run-all.sh)):

1. ds225-faster
2. ds225-full
3. ds225-dspark
4. the tuner
5. long prompts on ds225-faster
6. setup of 2.00
7. ds200-faster
8. long prompts on ds200-faster
9. ds225-faster again, as a drift check

Each configuration got three tests:

- **`tools/strata_bench.py --long`** (unchanged; it starts its own server):
  - short chat, 4K / 16K / 32K fresh prompts and a 5-turn agent session, 3 runs each
  - thinking off, temperature 0, one discarded warm-up
  - Its README, `results.json` and engine-log excerpt are in [strata-bench/](strata-bench/).
- **Coding with thinking on:** [scripts/ds-code.py](scripts/ds-code.py), run on a freshly started server.
  - Three tasks: merge intervals, an LRU cache without `OrderedDict`, and a POSIX script that lists the 10 largest files.
  - One request each, the model's default thinking and sampling, `max_tokens` 2048, a unique tag per prompt.
  - Answers, thinking and timings are in [coding/](coding/).
- **Long prompts** (the two default configurations only): the long-prompt script of the
  [2026-09-30 RTX 5090 report](../2026-09-30-community-rtx-5090/README.md) with a small patch for DeepSeek's tokenizer
  ([scripts/benchmark_ds.patch](scripts/benchmark_ds.patch)).
  - 4,096 / 32,768 / 128,000 / 250,000 prompt tokens, 3 runs each, one warm-up.
  - 256 new tokens, temperature 0, thinking off, streaming.
  - Each prompt is a fresh synthetic code listing. Nothing was reused from the cache (`cached_tokens` 0 in every run).
  - The patch makes the script use the pack's own pre-tokenizer and special-token ids, as `serve/server.py` does, and
    count the start token that the engine adds. Without it the script built a 3,098-token prompt when it asked for 4,096.
    With it, the server's count matched the target to within one token in every run.

Speeds are the engine's own timings (`prompt_per_second`, `predicted_per_second`). Decode counts thinking tokens too.
First-token times are measured by the client and include the prompt.

- **Telemetry:** RAM, swap and GPU, once a second ([scripts/monitor.py](scripts/monitor.py)).
- **Snapshots** of the power profile, turbo and memory before and after each test.
- **Model loading is not timed.**
- **Page cache:** warm from the earlier tests, except before ds200-faster, which came straight after its download. It
  held 16-42 GiB of file data before each test. The final drift check started with the least (16 GiB) and still matched
  the first run.

## Results

### Speed suite (`tools/strata_bench.py --long`): medians, with the range of the runs in brackets

| Test | ds225-faster | ds225-full | ds225-dspark | ds200-faster | ds225-faster again |
| --- | --- | --- | --- | --- | --- |
| chat decode tok/s (n=9) | 13.6 (13.0-15.3) | 11.2 (10.8-12.6) | 14.5 (12.7-17.6) | 14.9 (13.7-16.8) | 14.1 (12.9-15.3) |
| chat first token s | 2.07 (1.18-2.36) | 2.79 (2.01-3.17) | 2.50 (1.58-2.83) | 1.17 (1.06-1.39) | 2.06 (1.19-2.38) |
| 4K prompt tok/s (4,125 tokens) | 436 (392-443) | 387 (365-394) | 392 (365-394) | 463 (444-469) | 440 (429-450) |
| 16K prompt tok/s (16,562) | 759 (694-760) | 699 (620-700) | 708 (606-710) | 771 (747-777) | 763 (761-768) |
| 32K prompt tok/s (33,126) | 800 (794-816) | 755 (753-783) | 787 (753-803) | 833 (819-862) | 816 (802-820) |
| 32K first token s | 41.5 (40.6-41.8) | 44.0 (42.3-44.0) | 42.1 (41.3-44.0) | 39.8 (38.5-40.5) | 40.7 (40.5-41.4) |
| agent decode tok/s (n=15) | 16.0 (14.3-19.3) | 13.5 (11.2-16.0) | 15.4 (13.0-17.6) | 16.4 (14.5-19.1) | 16.1 (14.3-19.0) |
| agent turn first token s (n=15) | 11.0 (10.2-11.9) | 11.6 (11.1-12.9) | 11.5 (10.8-12.5) | 9.1 (8.1-10.1) | 11.8 (10.7-12.4) |
| agent cache hit % | 69.7 | 69.7 | 69.6 | 69.6 | 69.6 |

**Agent turns:** each turn adds 1,450-3,050 new tokens, and every turn took 8-13 s to the first token. The first
turn, 602 tokens with nothing cached, already took 9.5 s (2.25) or 7.5 s (2.00). Prompts of 96 tokens or more take the
engine's chunked path ("prompt path: the chunked pass from 96 tokens" in the log). We did not measure what sets this
floor.

### Coding with thinking on: one request per task, 2,048-token cap

| Configuration | Decode tok/s, task 1 / 2 / 3 | Decode, all tokens | Tokens | Wall time, 3 tasks | Drafted tokens accepted |
| --- | --- | ---: | ---: | ---: | --- |
| ds225-faster | 14.6 / 16.3 / 16.8 | 16.2 | 4,489 | 292 s | - |
| ds225-full | 12.8 / 14.0 / 13.8 | 13.7 | 4,554 | 350 s | - |
| ds225-dspark | 15.2 / 16.6 / 15.4 | 15.9 | 4,313 | 304 s | 2,605 of 3,427 (76%) |
| ds200-faster | 15.6 / 17.4 / 18.0 | 17.3 | 3,979 | 242 s | - |
| ds225-faster again | 14.1 / 16.5 / 16.1 | 16.0 | 4,386 | 291 s | - |

"Decode, all tokens" is the generated tokens of the three tasks divided by their summed decode time. Sampling was on, so
the answers and their lengths differ between runs.

### Long prompts: 3 fresh runs each, 256 new tokens, medians with the range of the runs in brackets

| Set | Prompt tokens | Prompt tok/s | First token s | Decode tok/s |
| --- | ---: | --- | --- | --- |
| 2.25 | 4,095 | 421 (326-422) | 9.7 (9.7-12.6) | 13.6 (12.8-13.8) |
| 2.25 | 32,767 | 690 (674-692) | 47.5 (47.4-48.7) | 13.9 (13.8-13.9) |
| 2.25 | 128,000 | 685 (632-801) | 187.0 (159.9-202.9) | 13.8 (12.5-14.6) |
| 2.25 | 250,000 | 664 (658-682) | 377.0 (367.2-380.2) | 13.9 (13.9-15.0) |
| 2.00 | 4,095 | 500 (364-503) | 8.2 (8.2-11.3) | 15.7 (14.2-15.9) |
| 2.00 | 32,767 | 781 (764-787) | 42.0 (41.7-42.9) | 15.4 (15.1-15.7) |
| 2.00 | 128,000 | 750 (697-807) | 170.9 (158.8-183.9) | 14.8 (14.6-15.2) |
| 2.00 | 250,000 | 627 (616-631) | 398.9 (396.4-406.0) | 14.7 (14.4-14.8) |

- **Decode at long context:** after a 250,000-token prompt, decode was 2% faster (2.25) and 6% slower (2.00) than at 4K.
- **First run at 4K:** in both sets the first 4K run was the slow one (326 and 364 tok/s); the warm-up request had
  been shorter.
- **32K, two scripts:** at 32K this script measured 690 tok/s on 2.25, and the speed suite measured 800. The two scripts
  use different prompt text (a code listing against a word list) and were run at different times. We did not look further.

### Tuner (`tools/dsv41/tune.py --mode quick`, on a copy of the 2.25 configuration)

The tuner times a 48-token answer to a fixed short question in a fresh engine process:

| Setting | tok/s |
| --- | ---: |
| standard | 11.9 |
| DSpark on | 8.2 |
| 24 CPU threads (one per physical core) | 12.1 |

It kept nothing ("already runs DeepSeek best with the standard settings"), because a setting needs a gain of more than
5%. With DSpark off it did not try the shorter draft block. Output: [logs/tune.txt](logs/tune.txt).

### Memory, swap and GPU (telemetry, once a second)

- **RAM:** with the server loaded, `MemAvailable` was about 45 GiB. The lowest values during the tests:
  - 33-34 GiB in the short suites and the coding runs
  - 13.6 GiB (2.25) and 15.5 GiB (2.00) during the 128K and 250K prompts
- **Swap:** the 2.25 long-prompt run moved up to 4.8 GiB to zram, during its first 128K request. The 64 GiB swap file was not
  used in any test.
- **VRAM:** at most 15,614 of 16,376 MiB.
- **GPU (nvidia-smi):**
  - utilisation median 99-100%
  - power median 82-96 W in the short suites and 144-147 W during the long prompts; single readings up to 228 W
  - temperature at most 78 °C

## Correctness and limitations

Checks on the answers:

- **Merge intervals:** in all five coding runs the answer's own tests pass (run with `python3 -I`).
- **LRU cache:** the answer was cut off by the 2,048-token cap in the four 2.25 runs (thinking used about 4,800 to
  6,000 characters), so it was not tested. The 2.00 run finished, and its code and tests pass. The cap was too low for this
  task with thinking on. That is a flaw in this test, not in the model.
- **Shell script:** all five pass `sh -n` and refuse to run without an argument. On a folder with spaces in its names:
  - Four list the files correctly.
  - The ds225-dspark answer used `find ... -exec wc -c {} +`, which also prints a `total` line.
  - This is one sampled answer. DSpark verifies every drafted token with the full model, so this difference is not
    evidence about the drafter.
- **Long prompts:** every answer opened with a coherent description of the listing. In all three 2.25 runs that we
  checked (4K, 128K and 250K), the answer named the last function of the listing correctly (`task_00149`, `task_04604`,
  `task_08962`). This is a check of the end of the prompt only. No needle test was run.
- **Faster against Full quality:** three tasks are too few to show a quality difference. We have no measurement of what
  Faster mode costs in answer quality.

Not tested:

- the 1.75 bpw set
- 2.00 in Full quality
- `--dspark on` on 2.00
- `strata bench run`: its standard protocol is for Qwen only
- recall at depth (`tools/needle_bench.py`)
- thinking on with long prompts
- concurrent requests, and pictures
- battery power and other power profiles
- Windows
- a cold page cache after a reboot

All results come from one machine on one night. No other build was compared on the same day: the drift check is the
same build again.

## Files

- [strata-bench/](strata-bench/): the five suites, each with its own README, `results.json` and engine-log excerpt.
  Those READMEs are written by the tool. They give "project 0.1.52" (the engine version, not Strata 0.2.7) and list the
  model without its set.
- [long-prompts/](long-prompts/): `summary.json` and `results.json` for both sets (per-run timings, engine timings,
  output text).
- [coding/](coding/): the coding answers with thinking and timings.
- [configs/](configs/): the server configurations used, including the tuner's copy before and after.
- [logs/](logs/): the engine logs of each test, and the tuner output.
- [scripts/](scripts/): the driver script, the coding script, the patch to the long-prompt script, and the telemetry
  script. Home folders are replaced by `<strata>`, `<data>` and `~`.
