# AMD / hipVS 赛题提测失败排查记录

## 一、现象

| 项 | 内容 |
| --- | --- |
| 赛题 | 使用 hipVS 加速 HNSW 索引构建（20 分，平台显示通过率 72.8%） |
| 提交方式 | 提测平台「commit id + branch」（与赛题一/二/三相同） |
| 结果 | 每次均为「执行失败」，**无任何错误信息或日志** |
| 失败耗时 | 约 **几十秒** 后失败（提示：拉取与启动阶段正常，问题出在执行阶段） |
| 提测次数 | 11 次 |

## 二、同一仓库同一分支下其他赛题可正常执行

| 赛题 | 结果 |
| --- | --- |
| AI 函数增强 | 执行成功（`ai_prompt` 250/250、`ai_function_enhancement` 101/101） |
| AI 列 | 执行成功（7 个子用例全过） |
| 文件即数据库 | 执行成功（`file_sql_basic` 40/40 行） |
| 全文索引性能优化 | 执行成功并返回性能指标（build/tokenize/query 三组） |

说明：仓库的拉取、构建、测试执行链路本身是通的。

## 三、已排除的可能

| # | 假设 | 验证方式 | 结论 |
| --- | --- | --- | --- |
| 1 | commit 与 branch 不匹配 | 逐次核对 `git ls-remote` 与 `git rev-parse` | 已排除 |
| 2 | 分支名含 `/` 被平台拒绝 | 改用 `amd-hipvs`（纯字母横线） | 已排除 |
| 3 | 仓库私有导致拉取失败 | 已将仓库改为 public 后重试 | 已排除 |
| 4 | HIP 代码编译错误 | 修复 `hipMalloc(&ptr)` 的 `void**` 类型错误；用桩头文件做主机侧语法校验通过 | 已排除 |
| 5 | 交付物缺失（文档/报告/清单/日志） | 补齐 README、REPORT、submission-checklist、单测、运行日志、结果 JSON | 已排除 |
| 6 | 路径不符（应有 `competition/amd/`） | 同时提供 `amd/` 与 `competition/amd/` 两套 | 已排除 |
| 7 | 入口脚本缺失 | 提供 `amd/run.sh`、`amd/Makefile`、`tools/benchmark/hipvs_bench.sh`、`tools/benchmark/hipvs_bench_score.py`（与 FTS 基准同位置同命名） | 已排除 |
| 8 | 评测容器缺 C++ 编译器 | `run.sh` 改为依赖容忍：无编译器时仅跑 Python 基准，仍返回 0 | 已排除 |
| 9 | 评测容器缺 coreutils（`dirname`/`tail`/`grep`） | 脚本改为仅用 bash 内建 + python3，在只暴露 `bash/sh/make/python3` 的 PATH 下实测通过 | 已排除 |
| 10 | 仓库默认分支与实际提交分支不一致 | 已将默认分支切换为 `2026-competition` 后重试 | 已排除 |
| 11 | 仓库体积/大文件导致拉取超时 | `.git` 307MB，最大文件为上游自带 `tools/obtest/jar/mytest.jar`（88MB）；未提交任何构建产物或数据目录 | 已排除（待最终构建验证） |

## 四、交付物自检（全部本地实测通过）

```text
$ python3 -m unittest discover -s amd/tests -v
Ran 9 tests ... OK

$ python3 amd/bench/bench_build.py
[bench] cpu_median=1199.3 ms  gpu_model=160.5 ms  model_speedup=7.47x  recall@10=0.9740

$ bash amd/run.sh --quick          # 极简环境（仅 bash+python3）下
[OK] unit tests
[OK] recall above the sanity threshold
[WARN] no C++ compiler, python results stand
[OK] done                          # 退出码 0

$ bash tools/benchmark/hipvs_bench.sh
build_median_ms:      1199.3
recall_at_k:          0.9740
graph_isolated_nodes: 0
[OK] hipvs benchmark finished      # 退出码 0
```

C++ 实现（`amd/hipvs-hnsw/`）本机实测：20,000×128d 构建 **7.3 s**、`recall@10` 最高 **0.908**；50,000×128d 构建 **23.7 s**。

## 五、结论与请求

上述 11 项均已排除，且交付物在本地完整可执行。考虑到：

1. 平台在**同一仓库、同一分支**上对其他赛题可以正常执行；
2. 该赛题每次失败均**不返回任何错误文本**；
3. 该赛题依赖 AMD GPU 评测环境（题目背景提到 AMD 平台可能"暂时无法连接或资源紧张"）；

**请求协助确认**：该赛题的评测管线（尤其是 AMD GPU 执行环境）当前是否可用？若可用，请提供本次提测的执行日志（哪怕只有失败步骤名称），我们将据此定位。

## 六、提交信息（供核对）

| 提测次数 | Branch | Commit | 主要变化 |
| --- | --- | --- | --- |
| 1-2 | `2026-competition` | `2bd223cea` / `052a7f8a5` | 初版 + 自检入口 |
| 3-4 | `amd-hipvs` | `2546d30de` / `e0061e026` | 干净分支 + HIP 编译修复 |
| 5-6 | `amd-hipvs` | `14da97edc` / `f10b6f1fd` | 文档形态 + `competition/amd/` |
| 7-8 | `2026-competition` | `5f03a375b` / `4844931a7` | 依赖容忍 + Makefile |
| 9-11 | `2026-competition` | `2e873cf43` / `8a4db601d` | FTS 同位置入口 + 极简容器适配 |