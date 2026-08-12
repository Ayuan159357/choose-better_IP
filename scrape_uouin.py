"""
抓取 api.uouin.com/cloudflare.html 的实时优选IP表格，
转换成 "IP:端口#备注" 格式的纯文本，可以直接喂给 edgetunnel 的"优选API"。

为什么不能直接用 requests/httpx 抓？
    这个页面的表格数据是靠前端JS异步刷出来的，直接请求HTML只能拿到
    "正在加载最新的CloudFlare优选IP数据中..." 这句占位文字，
    所以这里用 Playwright 起一个无头浏览器，等真实数据渲染完再抓表格。

用法：
    pip install playwright
    playwright install --with-deps chromium
    python scrape_uouin.py

输出：
    output/uouin.txt   —— 每行一条 IP:端口#备注，按延迟从低到高排列，每条线路各取若干条
"""

import re
from pathlib import Path
from typing import Any

from playwright.sync_api import sync_playwright

SOURCE_URL = "https://api.uouin.com/cloudflare.html"
OUTPUT_PATH = Path("output/uouin.txt")
DEFAULT_PORT = "443"        # 该表格不带端口，统一补一个edgetunnel支持的端口(443/2053/2083/2087/2096/8443)
MAX_SOURCE_ROWS = 40         # 只处理源站表格的前40条结果
MAX_PER_LINE = 6            # 电信/联通/移动/多线/IPv6 各取延迟最低的前几条，避免一次塞太多导致真链接响应异常
PAGE_TIMEOUT_MS = 30_000     # 页面主体加载超时
DATA_TIMEOUT_MS = 60_000     # 源站动态数据有时需要二三十秒才返回
MAX_ATTEMPTS = 3             # 源站接口偶尔无响应，失败时重新打开页面

LINE_GROUPS = (
    ("ctcc", "电信"),
    ("cucc", "联通"),
    ("cmcc", "移动"),
    ("bgp", "多线"),
    ("ipv6", "IPV6"),
)


def format_addr(ip: str) -> str:
    # IPv6 地址在 host:port 里要用方括号包起来，比如 [2a06:98c1::1]:443
    if ip.count(":") > 1:
        return f"[{ip}]:{DEFAULT_PORT}"
    return f"{ip}:{DEFAULT_PORT}"


def fetch_data(page) -> dict[str, Any]:
    with page.expect_response(
        lambda response: "/index.php/index/cloudflare" in response.url.lower(),
        timeout=DATA_TIMEOUT_MS,
    ) as response_info:
        page.goto(SOURCE_URL, wait_until="domcontentloaded", timeout=PAGE_TIMEOUT_MS)

    response = response_info.value
    if not response.ok:
        raise RuntimeError(f"数据接口返回 HTTP {response.status}")

    payload = response.json()
    if str(payload.get("code")) != "200" or not isinstance(payload.get("data"), dict):
        raise RuntimeError(f"数据接口返回异常：{payload.get('msg', '未知错误')}")
    return payload["data"]


def parse_data(data: dict[str, Any]) -> list[str]:
    grouped: dict[str, list[tuple[float, str]]] = {}
    source_row_count = 0

    for group_key, line in LINE_GROUPS:
        group = data.get(group_key, {})
        records = group.get("info", []) if isinstance(group, dict) else []
        for record in records:
            if source_row_count >= MAX_SOURCE_ROWS:
                break
            if not isinstance(record, dict):
                continue

            ip = str(record.get("ip", "")).strip()
            latency = str(record.get("ping", "")).strip()
            speed = str(record.get("speed", "")).strip()
            if not re.fullmatch(r"[0-9a-fA-F:.]+", ip):
                continue

            source_row_count += 1
            try:
                latency_ms = float(re.sub(r"[^\d.]", "", latency) or "9999")
            except ValueError:
                continue

            remark = f"{line}优选 | {latency} | {speed}"
            entry = f"{format_addr(ip)}#{remark}"
            grouped.setdefault(line, []).append((latency_ms, entry))

        if source_row_count >= MAX_SOURCE_ROWS:
            break

    lines: list[str] = []
    for entries in grouped.values():
        entries.sort(key=lambda x: x[0])
        lines.extend(entry for _, entry in entries[:MAX_PER_LINE])
    return lines


def scrape() -> list[str]:
    last_error: Exception | None = None
    with sync_playwright() as p:
        browser = p.chromium.launch()
        try:
            for attempt in range(1, MAX_ATTEMPTS + 1):
                page = browser.new_page()
                try:
                    return parse_data(fetch_data(page))
                except Exception as error:
                    last_error = error
                    print(f"第 {attempt}/{MAX_ATTEMPTS} 次抓取失败：{error}")
                finally:
                    page.close()
        finally:
            browser.close()

    raise RuntimeError(f"连续 {MAX_ATTEMPTS} 次抓取失败") from last_error


def main():
    lines = scrape()
    if not lines:
        raise RuntimeError("未抓取到有效IP，保留现有输出文件")
    OUTPUT_PATH.parent.mkdir(exist_ok=True)
    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"写入 {len(lines)} 条，保存到 {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
