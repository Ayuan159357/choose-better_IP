# CF 优选 IP 自动转换器

自动获取 Cloudflare 优选 IP，转换为 `IP:端口#备注` 格式，并通过 GitHub Actions 定时更新。

数据来源：[api.uouin.com/cloudflare.html](https://api.uouin.com/cloudflare.html)

## 目录

- [主要功能](#主要功能)
- [工作原理](#工作原理)
- [输出格式](#输出格式)
- [快速使用](#快速使用)
- [本地运行](#本地运行)
- [自动更新](#自动更新)
- [项目结构](#项目结构)
- [配置说明](#配置说明)
- [常见问题](#常见问题)
- [更新日志](#更新日志)
- [注意事项](#注意事项)

## 主要功能

- 使用 Playwright 和无头 Chromium 加载数据源页面。
- 捕获页面自身发起的动态 JSON 数据请求，不依赖静态 HTML 表格。
- 按源站顺序读取前 40 条有效数据。
- 按线路分组，并按延迟从低到高排序。
- 每条线路最多保留 6 个地址。
- 自动兼容 IPv4 与 IPv6 的 `host:port` 写法。
- 源站请求失败时最多尝试 3 次。
- 抓取结果为空时终止运行，避免覆盖已有文件。
- 支持 GitHub Actions 定时运行和手动触发。

## 工作原理

源站数据由 JavaScript 异步加载。直接使用 `requests` 或 `curl` 获取页面时，通常只能得到“正在加载”的占位内容。

本项目的处理流程如下：

```text
打开源站页面
    ↓
等待并捕获动态 JSON 响应
    ↓
读取前 40 条有效数据
    ↓
按线路分组、按延迟排序
    ↓
每条线路保留前 6 条
    ↓
写入 output/uouin.txt
```

当前线路顺序为：

```text
电信 → 联通 → 移动 → 多线 → IPv6
```

源站目前每组返回 10 条数据，因此读取前 40 条时通常会得到电信、联通、移动和多线数据，最终最多输出 `4 × 6 = 24` 条。IPv6 位于第 41 条之后，如需包含 IPv6，可适当提高 `MAX_SOURCE_ROWS`。

## 输出格式

每行一个地址：

```text
IP:端口#线路优选 | 延迟 | 速度
```

IPv4 示例：

```text
104.18.41.216:443#电信优选 | 43.35ms | 38.63mb/s
```

IPv6 示例：

```text
[2606:4700::1]:443#IPV6优选 | 42.00ms | 10.20mb/s
```

## 快速使用

本仓库生成文件的 Raw 地址：

```text
https://raw.githubusercontent.com/Ayuan159357/choose-better_IP/main/output/uouin.txt
```

其他仓库可按以下格式替换用户名、仓库名和默认分支：

```text
https://raw.githubusercontent.com/<用户名>/<仓库名>/<默认分支>/output/uouin.txt
```

该地址可用于 edgetunnel，以及其他支持同类“优选 API”格式的面板。

## 本地运行

### 环境要求

- Python 3.10 或更高版本
- Git
- 可访问数据源和 Playwright 下载服务的网络环境

### 安装与运行

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m playwright install chromium
python scrape_uouin.py
```

成功后会生成或更新：

```text
output/uouin.txt
```

退出虚拟环境：

```bash
deactivate
```

## 自动更新

工作流文件位于：

```text
.github/workflows/update_ip_list.yml
```

GitHub Actions 会完成以下操作：

1. 检出仓库代码；
2. 安装 Python 3.11；
3. 安装 Playwright、Chromium 及系统依赖；
4. 运行 `scrape_uouin.py`；
5. 在结果发生变化时自动提交并推送 `output/uouin.txt`。

工作流支持：

- Cron 定时触发：每 10 分钟尝试运行一次；
- `workflow_dispatch`：在 GitHub Actions 页面手动运行。

定时任务安排在每小时第 `6、16、26、36、46、56` 分钟，尽量避开整点附近的 GitHub Actions 调度高峰，并与源站约 10 分钟一次的刷新周期保持一致。相比每 5 分钟运行一次，理论任务次数和运行时间约减少 50%。

工作流使用以下写入权限提交结果：

```yaml
permissions:
  contents: write
```

> GitHub Actions 的 Cron 不是严格的实时调度。源站刷新、GitHub 调度延迟和 Raw CDN 缓存都会影响最终更新时间。

## 项目结构

```text
.
├── .github/
│   └── workflows/
│       └── update_ip_list.yml
├── output/
│   └── uouin.txt
├── .gitignore
├── README.md
├── requirements.txt
└── scrape_uouin.py
```

| 文件 | 用途 |
| --- | --- |
| `scrape_uouin.py` | 捕获动态数据、筛选 IP 并生成输出文件 |
| `requirements.txt` | Python 依赖清单 |
| `.github/workflows/update_ip_list.yml` | GitHub Actions 自动更新工作流 |
| `output/uouin.txt` | 自动生成的优选 IP 列表，请勿手动编辑 |
| `.gitignore` | 排除虚拟环境、缓存和本地配置文件 |

## 配置说明

可在 `scrape_uouin.py` 顶部修改以下常量：

| 常量 | 默认值 | 说明 |
| --- | ---: | --- |
| `SOURCE_URL` | `https://api.uouin.com/cloudflare.html` | 数据源页面 |
| `OUTPUT_PATH` | `output/uouin.txt` | 输出文件路径 |
| `DEFAULT_PORT` | `443` | 为地址补充的端口 |
| `MAX_SOURCE_ROWS` | `40` | 读取的最大有效数据条数 |
| `MAX_PER_LINE` | `6` | 每条线路最多保留的地址数 |
| `PAGE_TIMEOUT_MS` | `30000` | 页面主体加载超时，单位为毫秒 |
| `DATA_TIMEOUT_MS` | `60000` | 动态数据响应超时，单位为毫秒 |
| `MAX_ATTEMPTS` | `3` | 抓取失败时的最大尝试次数 |

除 `443` 外，常用 TLS 端口还包括：

```text
2053、2083、2087、2096、8443
```

## 常见问题

### GitHub Actions 页面没有显示工作流

确认工作流文件位于：

```text
.github/workflows/update_ip_list.yml
```

只有放在 `.github/workflows/` 目录中的 YAML 文件才会被识别为工作流。

### 工作流无法推送生成结果

确认工作流包含：

```yaml
permissions:
  contents: write
```

如果仍然失败，请检查仓库的：

```text
Settings → Actions → General → Workflow permissions
```

### 抓取超时

源站动态接口偶尔响应较慢。脚本会自动尝试 3 次，每次最多等待 60 秒。若连续失败，工作流会停止，并保留已有的 `output/uouin.txt`。

### 本地提示找不到 Chromium

在已激活的虚拟环境中执行：

```bash
python -m playwright install chromium
```

### 推送时出现 `non-fast-forward`

远程仓库存在本地尚未取得的提交。先同步并检查变更：

```bash
git pull
```

本项目的 GitHub Actions 会自动提交输出文件，因此开始本地修改前建议先运行 `git pull`。

## 更新日志

### 2026-08-12

- 创建 Cloudflare 优选 IP 抓取与格式转换脚本。
- 改为捕获页面动态 JSON 响应，减少对页面 DOM 结构的依赖。
- 限制为读取源站前 40 条有效数据。
- 增加按线路分组、延迟排序和每线路最多 6 条的规则。
- 增加最多 3 次抓取尝试和空结果保护。
- 增加 IPv4、IPv6 地址格式处理。
- 增加 GitHub Actions 定时更新及自动提交功能。
- 将 `actions/checkout` 与 `actions/setup-python` 升级到 v6。
- 将自动更新周期从每 5 分钟调整为每 10 分钟，并避开整点调度高峰。
- 完善项目文档、配置说明和常见问题。

## 注意事项

- 本项目依赖第三方数据源，其可用性、准确性和接口结构不受本项目控制。
- 本项目只负责获取和转换公开页面展示的数据，不提供 CDN、代理或网络接入服务。
- 使用第三方优选 IP 前，请自行确认 Cloudflare、数据源及相关服务的使用条款，并评估合规性、安全性和稳定性风险。
- 开源许可证仅能覆盖项目作者拥有版权的代码和文档，不代表第三方数据获得了重新授权。
- 如有侵权，请立即联系删除。
