[1mdiff --git a/.github/workflows/update_ip_list.yml b/.github/workflows/update_ip_list.yml[m
[1mindex 9044f4a..2d45b45 100644[m
[1m--- a/.github/workflows/update_ip_list.yml[m
[1m+++ b/.github/workflows/update_ip_list.yml[m
[36m@@ -14,9 +14,9 @@[m [mjobs:[m
   scrape:[m
     runs-on: ubuntu-latest[m
     steps:[m
[31m-      - uses: actions/checkout@v4[m
[32m+[m[32m      - uses: actions/checkout@v6[m
 [m
[31m-      - uses: actions/setup-python@v5[m
[32m+[m[32m      - uses: actions/setup-python@v6[m
         with:[m
           python-version: '3.11'[m
 [m
[1mdiff --git a/README.md b/README.md[m
[1mindex e63d70c..74572e4 100644[m
[1m--- a/README.md[m
[1m+++ b/README.md[m
[36m@@ -1,102 +1,270 @@[m
 # CF 优选 IP 自动转换器[m
 [m
[31m-抓取 [api.uouin.com/cloudflare.html](https://api.uouin.com/cloudflare.html) 中由 JavaScript 动态加载的 Cloudflare 优选 IP 数据，将其转换为 `IP:端口#备注` 格式，并通过 GitHub Actions 定时更新。[m
[31m-[m
[31m-生成的纯文本文件可用于 edgetunnel，以及其他支持“优选 API”格式的 VLESS 面板。[m
[32m+[m[32m自动获取 Cloudflare 优选 IP，转换为 `IP:端口#备注` 格式，并通过 GitHub Actions 定时更新。[m
[32m+[m
[32m+[m[32m数据来源：[api.uouin.com/cloudflare.html](https://api.uouin.com/cloudflare.html)[m
[32m+[m
[32m+[m[32m## 目录[m
[32m+[m
[32m+[m[32m- [主要功能](#主要功能)[m
[32m+[m[32m- [工作原理](#工作原理)[m
[32m+[m[32m- [输出格式](#输出格式)[m
[32m+[m[32m- [快速使用](#快速使用)[m
[32m+[m[32m- [本地运行](#本地运行)[m
[32m+[m[32m- [自动更新](#自动更新)[m
[32m+[m[32m- [项目结构](#项目结构)[m
[32m+[m[32m- [配置说明](#配置说明)[m
[32m+[m[32m- [常见问题](#常见问题)[m
[32m+[m[32m- [更新日志](#更新日志)[m
[32m+[m[32m- [注意事项](#注意事项)[m
[32m+[m
[32m+[m[32m## 主要功能[m
[32m+[m
[32m+[m[32m- 使用 Playwright 和无头 Chromium 加载数据源页面。[m
[32m+[m[32m- 捕获页面自身发起的动态 JSON 数据请求，不依赖静态 HTML 表格。[m
[32m+[m[32m- 按源站顺序读取前 40 条有效数据。[m
[32m+[m[32m- 按线路分组，并按延迟从低到高排序。[m
[32m+[m[32m- 每条线路最多保留 6 个地址。[m
[32m+[m[32m- 自动兼容 IPv4 与 IPv6 的 `host:port` 写法。[m
[32m+[m[32m- 源站请求失败时最多尝试 3 次。[m
[32m+[m[32m- 抓取结果为空时终止运行，避免覆盖已有文件。[m
[32m+[m[32m- 支持 GitHub Actions 定时运行和手动触发。[m
 [m
 ## 工作原理[m
 [m
[31m-源站表格由前端 JavaScript 异步渲染，直接使用 `requests` 或 `curl` 只能取得加载中的占位内容。本项目使用 Playwright 启动无头 Chromium，让页面正常发起动态数据请求并捕获其 JSON 响应，然后：[m
[32m+[m[32m源站数据由 JavaScript 异步加载。直接使用 `requests` 或 `curl` 获取页面时，通常只能得到“正在加载”的占位内容。[m
[32m+[m
[32m+[m[32m本项目的处理流程如下：[m
 [m
[31m-1. 按源站展示顺序读取前 40 条有效结果的线路、IP、延迟和速度信息；[m
[31m-2. 按线路分组，并按延迟从低到高排序；[m
[31m-3. 每条线路最多保留延迟最低的 6 个地址；[m
[31m-4. 为地址补充端口和备注，写入 `output/uouin.txt`。[m
[32m+[m[32m```text[m
[32m+[m[32m打开源站页面[m
[32m+[m[32m    ↓[m
[32m+[m[32m等待并捕获动态 JSON 响应[m
[32m+[m[32m    ↓[m
[32m+[m[32m读取前 40 条有效数据[m
[32m+[m[32m    ↓[m
[32m+[m[32m按线路分组、按延迟排序[m
[32m+[m[32m    ↓[m
[32m+[m[32m每条线路保留前 6 条[m
[32m+[m[32m    ↓[m
[32m+[m[32m写入 output/uouin.txt[m
[32m+[m[32m```[m
 [m
[31m-输出示例：[m
[32m+[m[32m当前线路顺序为：[m
 [m
 ```text[m
[31m-104.16.0.1:443#电信优选 | 35 ms | 12.5 MB/s[m
[31m-[2606:4700::1]:443#IPv6优选 | 42 ms | 10.2 MB/s[m
[32m+[m[32m电信 → 联通 → 移动 → 多线 → IPv6[m
 ```[m
 [m
[31m-## 项目结构[m
[32m+[m[32m源站目前每组返回 10 条数据，因此读取前 40 条时通常会得到电信、联通、移动和多线数据，最终最多输出 `4 × 6 = 24` 条。IPv6 位于第 41 条之后，如需包含 IPv6，可适当提高 `MAX_SOURCE_ROWS`。[m
 [m
[31m-| 路径 | 说明 |[m
[31m-| --- | --- |[m
[31m-| `scrape_uouin.py` | Playwright 动态响应捕获及格式转换脚本 |[m
[31m-| `requirements.txt` | Python 依赖清单 |[m
[31m-| `.github/workflows/update_ip_list.yml` | GitHub Actions 定时更新工作流，已授予结果提交权限 |[m
[31m-| `output/uouin.txt` | 运行后生成的 IP 列表，请勿手动编辑 |[m
[32m+[m[32m## 输出格式[m
[32m+[m
[32m+[m[32m每行一个地址：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32mIP:端口#线路优选 | 延迟 | 速度[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32mIPv4 示例：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32m104.18.41.216:443#电信优选 | 43.35ms | 38.63mb/s[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32mIPv6 示例：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32m[2606:4700::1]:443#IPV6优选 | 42.00ms | 10.20mb/s[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m## 快速使用[m
[32m+[m
[32m+[m[32m本仓库生成文件的 Raw 地址：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32mhttps://raw.githubusercontent.com/Ayuan159357/choose-better_IP/main/output/uouin.txt[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m其他仓库可按以下格式替换用户名、仓库名和默认分支：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32mhttps://raw.githubusercontent.com/<用户名>/<仓库名>/<默认分支>/output/uouin.txt[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m该地址可用于 edgetunnel，以及其他支持同类“优选 API”格式的面板。[m
 [m
 ## 本地运行[m
 [m
[31m-需要 Python 3.9 或更高版本。[m
[32m+[m[32m### 环境要求[m
[32m+[m
[32m+[m[32m- Python 3.10 或更高版本[m
[32m+[m[32m- Git[m
[32m+[m[32m- 可访问数据源和 Playwright 下载服务的网络环境[m
[32m+[m
[32m+[m[32m### 安装与运行[m
 [m
 ```bash[m
[31m-python3 -m venv venv[m
[31m-source venv/bin/activate[m
[31m-pip install -r requirements.txt[m
[31m-playwright install --with-deps chromium[m
[32m+[m[32mpython3 -m venv .venv[m
[32m+[m[32msource .venv/bin/activate[m
[32m+[m[32mpython -m pip install -r requirements.txt[m
[32m+[m[32mpython -m playwright install chromium[m
 python scrape_uouin.py[m
 ```[m
 [m
[31m-成功后会生成 `output/uouin.txt`。[m
[32m+[m[32m成功后会生成或更新：[m
 [m
[31m-## GitHub Actions 自动更新[m
[32m+[m[32m```text[m
[32m+[m[32moutput/uouin.txt[m
[32m+[m[32m```[m
 [m
[31m-1. 将项目推送到 GitHub 仓库。[m
[31m-2. 在 **Actions** 页面手动运行一次工作流，确认抓取和推送正常。[m
[32m+[m[32m退出虚拟环境：[m
[32m+[m
[32m+[m[32m```bash[m
[32m+[m[32mdeactivate[m
[32m+[m[32m```[m
 [m
[31m-工作流当前配置为每 5 分钟尝试运行一次。GitHub Actions 的定时任务可能延迟，源站刷新及 Raw 文件 CDN 缓存也会进一步增加实际更新时间。[m
[32m+[m[32m## 自动更新[m
 [m
[31m-生成文件的 Raw 地址格式如下：[m
[32m+[m[32m工作流文件位于：[m
 [m
 ```text[m
[31m-https://raw.githubusercontent.com/<用户名>/<仓库名>/<默认分支>/output/uouin.txt[m
[32m+[m[32m.github/workflows/update_ip_list.yml[m
 ```[m
 [m
[31m-请将 `<默认分支>` 替换为仓库实际使用的分支，例如 `main` 或 `master`。[m
[32m+[m[32mGitHub Actions 会完成以下操作：[m
[32m+[m
[32m+[m[32m1. 检出仓库代码；[m
[32m+[m[32m2. 安装 Python 3.11；[m
[32m+[m[32m3. 安装 Playwright、Chromium 及系统依赖；[m
[32m+[m[32m4. 运行 `scrape_uouin.py`；[m
[32m+[m[32m5. 在结果发生变化时自动提交并推送 `output/uouin.txt`。[m
[32m+[m
[32m+[m[32m工作流支持：[m
[32m+[m
[32m+[m[32m- Cron 定时触发：每 5 分钟尝试运行一次；[m
[32m+[m[32m- `workflow_dispatch`：在 GitHub Actions 页面手动运行。[m
 [m
[31m-## 配置[m
[32m+[m[32m工作流使用以下写入权限提交结果：[m
[32m+[m
[32m+[m[32m```yaml[m
[32m+[m[32mpermissions:[m
[32m+[m[32m  contents: write[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m> GitHub Actions 的 Cron 不是严格的实时调度。源站刷新、GitHub 调度延迟和 Raw CDN 缓存都会影响最终更新时间。[m
[32m+[m
[32m+[m[32m## 项目结构[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32m.[m
[32m+[m[32m├── .github/[m
[32m+[m[32m│   └── workflows/[m
[32m+[m[32m│       └── update_ip_list.yml[m
[32m+[m[32m├── output/[m
[32m+[m[32m│   └── uouin.txt[m
[32m+[m[32m├── .gitignore[m
[32m+[m[32m├── README.md[m
[32m+[m[32m├── requirements.txt[m
[32m+[m[32m└── scrape_uouin.py[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m| 文件 | 用途 |[m
[32m+[m[32m| --- | --- |[m
[32m+[m[32m| `scrape_uouin.py` | 捕获动态数据、筛选 IP 并生成输出文件 |[m
[32m+[m[32m| `requirements.txt` | Python 依赖清单 |[m
[32m+[m[32m| `.github/workflows/update_ip_list.yml` | GitHub Actions 自动更新工作流 |[m
[32m+[m[32m| `output/uouin.txt` | 自动生成的优选 IP 列表，请勿手动编辑 |[m
[32m+[m[32m| `.gitignore` | 排除虚拟环境、缓存和本地配置文件 |[m
[32m+[m
[32m+[m[32m## 配置说明[m
 [m
 可在 `scrape_uouin.py` 顶部修改以下常量：[m
 [m
 | 常量 | 默认值 | 说明 |[m
[31m-| --- | --- | --- |[m
[32m+[m[32m| --- | ---: | --- |[m
 | `SOURCE_URL` | `https://api.uouin.com/cloudflare.html` | 数据源页面 |[m
 | `OUTPUT_PATH` | `output/uouin.txt` | 输出文件路径 |[m
[31m-| `DEFAULT_PORT` | `443` | 为所有地址补充的端口 |[m
[31m-| `MAX_SOURCE_ROWS` | `40` | 从源站表格读取的最大有效数据行数 |[m
[31m-| `MAX_PER_LINE` | `6` | 每条线路最多保留的地址数量 |[m
[32m+[m[32m| `DEFAULT_PORT` | `443` | 为地址补充的端口 |[m
[32m+[m[32m| `MAX_SOURCE_ROWS` | `40` | 读取的最大有效数据条数 |[m
[32m+[m[32m| `MAX_PER_LINE` | `6` | 每条线路最多保留的地址数 |[m
 | `PAGE_TIMEOUT_MS` | `30000` | 页面主体加载超时，单位为毫秒 |[m
[31m-| `DATA_TIMEOUT_MS` | `60000` | 等待动态 IP 数据的超时，单位为毫秒 |[m
[31m-| `MAX_ATTEMPTS` | `3` | 动态数据请求失败时的最大尝试次数 |[m
[32m+[m[32m| `DATA_TIMEOUT_MS` | `60000` | 动态数据响应超时，单位为毫秒 |[m
[32m+[m[32m| `MAX_ATTEMPTS` | `3` | 抓取失败时的最大尝试次数 |[m
 [m
[31m-除 `443` 外，edgetunnel 常用的 TLS 端口还包括 `2053`、`2083`、`2087`、`2096` 和 `8443`。[m
[32m+[m[32m除 `443` 外，常用 TLS 端口还包括：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32m2053、2083、2087、2096、8443[m
[32m+[m[32m```[m
 [m
 ## 常见问题[m
 [m
[31m-### GitHub Actions 没有出现工作流[m
[32m+[m[32m### GitHub Actions 页面没有显示工作流[m
[32m+[m
[32m+[m[32m确认工作流文件位于：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32m.github/workflows/update_ip_list.yml[m
[32m+[m[32m```[m
 [m
[31m-确认工作流文件位于 `.github/workflows/update_ip_list.yml`，而不是仓库根目录。[m
[32m+[m[32m只有放在 `.github/workflows/` 目录中的 YAML 文件才会被识别为工作流。[m
 [m
[31m-### 工作流在 `git push` 时返回权限错误[m
[32m+[m[32m### 工作流无法推送生成结果[m
 [m
[31m-工作流已经显式声明以下权限；如果仓库或组织策略仍然阻止写入，请检查 **Settings → Actions → General → Workflow permissions**：[m
[32m+[m[32m确认工作流包含：[m
 [m
 ```yaml[m
 permissions:[m
   contents: write[m
 ```[m
 [m
[31m-### 抓取超时或没有结果[m
[32m+[m[32m如果仍然失败，请检查仓库的：[m
[32m+[m
[32m+[m[32m```text[m
[32m+[m[32mSettings → Actions → General → Workflow permissions[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m### 抓取超时[m
[32m+[m
[32m+[m[32m源站动态接口偶尔响应较慢。脚本会自动尝试 3 次，每次最多等待 60 秒。若连续失败，工作流会停止，并保留已有的 `output/uouin.txt`。[m
[32m+[m
[32m+[m[32m### 本地提示找不到 Chromium[m
[32m+[m
[32m+[m[32m在已激活的虚拟环境中执行：[m
[32m+[m
[32m+[m[32m```bash[m
[32m+[m[32mpython -m playwright install chromium[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m### 推送时出现 `non-fast-forward`[m
[32m+[m
[32m+[m[32m远程仓库存在本地尚未取得的提交。先同步并检查变更：[m
[32m+[m
[32m+[m[32m```bash[m
[32m+[m[32mgit pull[m
[32m+[m[32m```[m
[32m+[m
[32m+[m[32m本项目的 GitHub Actions 会自动提交输出文件，因此开始本地修改前建议先运行 `git pull`。[m
[32m+[m
[32m+[m[32m## 更新日志[m
[32m+[m
[32m+[m[32m### 2026-08-12[m
 [m
[31m-可能是源站暂时不可访问、页面结构发生变化，或 Chromium 没有正确安装。脚本在结果为空时会终止运行并保留已有输出文件。先重新运行；若持续失败，请检查 Actions 日志以及源站表格的 DOM 结构。[m
[32m+[m[32m- 创建 Cloudflare 优选 IP 抓取与格式转换脚本。[m
[32m+[m[32m- 改为捕获页面动态 JSON 响应，减少对页面 DOM 结构的依赖。[m
[32m+[m[32m- 限制为读取源站前 40 条有效数据。[m
[32m+[m[32m- 增加按线路分组、延迟排序和每线路最多 6 条的规则。[m
[32m+[m[32m- 增加最多 3 次抓取尝试和空结果保护。[m
[32m+[m[32m- 增加 IPv4、IPv6 地址格式处理。[m
[32m+[m[32m- 增加 GitHub Actions 定时更新及自动提交功能。[m
[32m+[m[32m- 将 `actions/checkout` 与 `actions/setup-python` 升级到 v6。[m
[32m+[m[32m- 完善项目文档、配置说明和常见问题。[m
 [m
 ## 注意事项[m
 [m
[31m-- 该项目依赖第三方数据源，其可用性、准确性和页面结构不受本项目控制。[m
[31m-- 定时任务不是严格实时任务，实际更新时间可能晚于 Cron 配置。[m
[31m-- 使用第三方优选 IP 或代理服务前，请自行确认 Cloudflare 及相关服务的使用条款，并评估合规和稳定性风险。[m
[32m+[m[32m- 本项目依赖第三方数据源，其可用性、准确性和接口结构不受本项目控制。[m
[32m+[m[32m- 本项目只负责获取和转换公开页面展示的数据，不提供 CDN、代理或网络接入服务。[m
[32m+[m[32m- 使用第三方优选 IP 前，请自行确认 Cloudflare、数据源及相关服务的使用条款，并评估合规性、安全性和稳定性风险。[m
[32m+[m[32m- 开源许可证仅能覆盖项目作者拥有版权的代码和文档，不代表第三方数据获得了重新授权。[m
 - 如有侵权，请立即联系删除。[m
