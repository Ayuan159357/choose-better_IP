# CF 优选 IP 自动转换器

抓取 [api.uouin.com/cloudflare.html](https://api.uouin.com/cloudflare.html) 中由 JavaScript 动态加载的 Cloudflare 优选 IP 数据，将其转换为 `IP:端口#备注` 格式，并通过 GitHub Actions 定时更新。

生成的纯文本文件可用于 edgetunnel，以及其他支持“优选 API”格式的 VLESS 面板。

## 工作原理

源站表格由前端 JavaScript 异步渲染，直接使用 `requests` 或 `curl` 只能取得加载中的占位内容。本项目使用 Playwright 启动无头 Chromium，让页面正常发起动态数据请求并捕获其 JSON 响应，然后：

1. 按源站展示顺序读取前 40 条有效结果的线路、IP、延迟和速度信息；
2. 按线路分组，并按延迟从低到高排序；
3. 每条线路最多保留延迟最低的 6 个地址；
4. 为地址补充端口和备注，写入 `output/uouin.txt`。

输出示例：

```text
104.16.0.1:443#电信优选 | 35 ms | 12.5 MB/s
[2606:4700::1]:443#IPv6优选 | 42 ms | 10.2 MB/s
```

## 项目结构

| 路径 | 说明 |
| --- | --- |
| `scrape_uouin.py` | Playwright 动态响应捕获及格式转换脚本 |
| `requirements.txt` | Python 依赖清单 |
| `.github/workflows/update_ip_list.yml` | GitHub Actions 定时更新工作流，已授予结果提交权限 |
| `output/uouin.txt` | 运行后生成的 IP 列表，请勿手动编辑 |

## 本地运行

需要 Python 3.9 或更高版本。

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
playwright install --with-deps chromium
python scrape_uouin.py
```

成功后会生成 `output/uouin.txt`。

## GitHub Actions 自动更新

1. 将项目推送到 GitHub 仓库。
2. 在 **Actions** 页面手动运行一次工作流，确认抓取和推送正常。

工作流当前配置为每 5 分钟尝试运行一次。GitHub Actions 的定时任务可能延迟，源站刷新及 Raw 文件 CDN 缓存也会进一步增加实际更新时间。

生成文件的 Raw 地址格式如下：

```text
https://raw.githubusercontent.com/<用户名>/<仓库名>/<默认分支>/output/uouin.txt
```

请将 `<默认分支>` 替换为仓库实际使用的分支，例如 `main` 或 `master`。

## 配置

可在 `scrape_uouin.py` 顶部修改以下常量：

| 常量 | 默认值 | 说明 |
| --- | --- | --- |
| `SOURCE_URL` | `https://api.uouin.com/cloudflare.html` | 数据源页面 |
| `OUTPUT_PATH` | `output/uouin.txt` | 输出文件路径 |
| `DEFAULT_PORT` | `443` | 为所有地址补充的端口 |
| `MAX_SOURCE_ROWS` | `40` | 从源站表格读取的最大有效数据行数 |
| `MAX_PER_LINE` | `6` | 每条线路最多保留的地址数量 |
| `PAGE_TIMEOUT_MS` | `30000` | 页面主体加载超时，单位为毫秒 |
| `DATA_TIMEOUT_MS` | `60000` | 等待动态 IP 数据的超时，单位为毫秒 |
| `MAX_ATTEMPTS` | `3` | 动态数据请求失败时的最大尝试次数 |

除 `443` 外，edgetunnel 常用的 TLS 端口还包括 `2053`、`2083`、`2087`、`2096` 和 `8443`。

## 常见问题

### GitHub Actions 没有出现工作流

确认工作流文件位于 `.github/workflows/update_ip_list.yml`，而不是仓库根目录。

### 工作流在 `git push` 时返回权限错误

工作流已经显式声明以下权限；如果仓库或组织策略仍然阻止写入，请检查 **Settings → Actions → General → Workflow permissions**：

```yaml
permissions:
  contents: write
```

### 抓取超时或没有结果

可能是源站暂时不可访问、页面结构发生变化，或 Chromium 没有正确安装。脚本在结果为空时会终止运行并保留已有输出文件。先重新运行；若持续失败，请检查 Actions 日志以及源站表格的 DOM 结构。

## 注意事项

- 该项目依赖第三方数据源，其可用性、准确性和页面结构不受本项目控制。
- 定时任务不是严格实时任务，实际更新时间可能晚于 Cron 配置。
- 使用第三方优选 IP 或代理服务前，请自行确认 Cloudflare 及相关服务的使用条款，并评估合规和稳定性风险。
- 如有侵权，请立即联系删除。
