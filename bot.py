# -*- coding: utf-8 -*-
import os
import json
import asyncio
import logging
import re
import time
import csv
from datetime import datetime, timezone
from io import BytesIO
from itertools import cycle

import discord
from discord.ext import commands, tasks
import aiohttp
from bs4 import BeautifulSoup
from google import genai
from dotenv import load_dotenv
from aiohttp import web

load_dotenv()

# ========== CONFIG ==========
DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID = int(os.getenv("CHANNEL_ID", "0"))
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL_MINUTES", "10"))
GEMINI_MODEL = "gemini-3.5-flash"

SEEN_FILE = "seen_posts.json"
LAST_TIME_FILE = "last_publish_time.json"
PORT = int(os.getenv("PORT", "10000"))
MAX_POSTS_PER_CYCLE = 3
DICT_FILE = "game dict.csv"

XUA = "V%3D1%26PN%3DWebApp%26LANG%3Dzh_CN%26VN_CODE%3D100000000%26LOC%3DCN%26PLT%3DPC"

# ========== LOGGING ==========
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("gfl2-bot")

# ========== LOAD MULTIPLE GEMINI KEYS ==========
def load_gemini_keys() -> list[str]:
    keys = []

    # Cách 1: GEMINI_API_KEYS=key1,key2,key3
    raw = os.getenv("GEMINI_API_KEYS", "").strip()
    if raw:
        keys.extend([k.strip() for k in raw.split(",") if k.strip()])

    # Cách 2: GEMINI_API_KEY + GEMINI_API_KEY_2 + GEMINI_API_KEY_3 ...
    if not keys:
        main = os.getenv("GEMINI_API_KEY")
        if main:
            keys.append(main.strip())

        i = 2
        while True:
            extra = os.getenv(f"GEMINI_API_KEY_{i}")
            if not extra:
                break
            keys.append(extra.strip())
            i += 1

    # Lọc trùng
    keys = list(dict.fromkeys(keys))
    if not keys:
        raise ValueError("Thieu GEMINI_API_KEY / GEMINI_API_KEYS trong environment")
    logger.info(f"Da load {len(keys)} Gemini API key")
    return keys


GEMINI_KEYS = load_gemini_keys()
key_cycle = cycle(GEMINI_KEYS)
current_key = next(key_cycle)
client = genai.Client(api_key=current_key)


def rotate_key():
    """Chuyen sang key tiep theo"""
    global current_key, client
    current_key = next(key_cycle)
    client = genai.Client(api_key=current_key)
    logger.warning(f"Da chuyen sang Gemini key moi (cuoi ...{current_key[-6:]})")


# ========== LOAD DICTIONARY ==========
def load_dictionary(path: str = DICT_FILE) -> dict:
    mapping = {}
    if not os.path.exists(path):
        logger.warning(f"Khong tim thay file tu dien: {path}")
        return mapping

    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                cn = (row.get("Column1") or "").strip()
                vi = (row.get("Translation") or "").strip()
                if cn and vi:
                    mapping[cn] = vi
        logger.info(f"Da load {len(mapping)} muc tu dien tu {path}")
    except Exception as e:
        logger.error(f"Loi doc tu dien: {e}")
    return mapping


DICT_MAP = load_dictionary()


def build_mapping_string(mapping: dict) -> str:
    if not mapping:
        return ""
    return " | ".join(f"{k}={v}" for k, v in mapping.items())


# ========== TRANSLATE ==========
def is_quota_error(error: Exception) -> bool:
    msg = str(error).lower()
    return any(x in msg for x in ("429", "quota", "resource exhausted", "rate limit", "exceeded"))


def translate_to_vietnamese(text: str) -> str:
    if not text or not text.strip():
        return text
    text = text[:8000]

    mapping_str = build_mapping_string(DICT_MAP)

    prompt = (
        "Ban la dich gia game Girls' Frontline 2: Exilium (少前2).\n"
        "Dich tieng Trung sang tieng Viet tu nhien, giu markdown neu co.\n\n"
        "QUY TAC BAT BUOC:\n"
        "1. Chi tra ve ban dich, khong giai thich, khong them ghi chu.\n"
        "2. Bat buoc su dung dung theo bang dich ben duoi. Khong duoc tu dich khac.\n"
        "3. Neu khong co trong bang thi giu nguyen tieng Trung (CAM tu che ten nhan vat).\n"
        "4. Class (Sentinel/Bulwark/Vanguard/Support) va Phase (Burn/Corrosion/Hydro/Freeze/Electric) GIU NGUYEN tieng Anh.\n"
        "5. Hashtag su kien phai viet: #KimTướcvàNhànhOliu\n"
        "6. Leap Key / 跃键:\n"
        "   - 1阶/一阶 = Expansion Key\n"
        "   - 2阶/二阶 = Expansion Key ver2\n"
        "   - Khong duoc viet 'khoa Leap Key' hay 'Leap Key bac X'.\n\n"
        f"BANG DICH CO DINH (bat buoc dung):\n{mapping_str}\n\n"
        + text
    )

    max_retries_per_key = 3
    max_key_switches = len(GEMINI_KEYS)  # xoay het 1 vong key

    for key_try in range(max_key_switches):
        for attempt in range(1, max_retries_per_key + 1):
            try:
                response = client.models.generate_content(
                    model=GEMINI_MODEL,
                    contents=prompt,
                )
                result = (response.text or "").strip()
                if result:
                    return result
                logger.warning(f"Lan {attempt}: Gemini tra ve rong")
            except Exception as e:
                logger.error(f"Loi dich (key ...{current_key[-6:]}, lan {attempt}): {e}")

                if is_quota_error(e):
                    logger.warning("Phat hien het quota → chuyen key")
                    rotate_key()
                    break  # thoat vong retry, dung key moi
                else:
                    if attempt < max_retries_per_key:
                        time.sleep(1.5 * attempt)
                    else:
                        # het retry ma khong phai quota → thu key khac luon
                        rotate_key()
                        break
        else:
            # neu khong break (tuc la khong gap loi quota) thi tiep tuc key hien tai
            continue

    logger.error("Dich that bai sau khi thu het key, tra ve ban goc tieng Trung")
    return text


# ========== STATE ==========
def load_seen() -> set:
    if os.path.exists(SEEN_FILE):
        try:
            with open(SEEN_FILE, "r", encoding="utf-8") as f:
                return set(json.load(f))
        except Exception:
            return set()
    return set()


def save_seen(seen: set):
    with open(SEEN_FILE, "w", encoding="utf-8") as f:
        json.dump(list(seen), f, ensure_ascii=False)


def load_last_time() -> int:
    if os.path.exists(LAST_TIME_FILE):
        try:
            with open(LAST_TIME_FILE, "r", encoding="utf-8") as f:
                return int(json.load(f).get("publish_time", 0))
        except Exception:
            return 0
    return 0


def save_last_time(ts: int):
    with open(LAST_TIME_FILE, "w", encoding="utf-8") as f:
        json.dump({"publish_time": int(ts)}, f)


seen_posts = load_seen()
last_publish_time = load_last_time()

# ========== TAPTAP ==========
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Referer": "https://www.taptap.cn/",
}


async def fetch_official_list(session: aiohttp.ClientSession) -> list[dict]:
    url = "https://www.taptap.cn/app/190930/topic?type=official"
    try:
        async with session.get(url, headers=HEADERS, timeout=30) as resp:
            if resp.status != 200:
                logger.warning(f"List status: {resp.status}")
                return []
            html = await resp.text()
    except Exception as e:
        logger.error(f"Loi list: {e}")
        return []

    ids = []
    seen = set()
    for m in re.finditer(r"/moment/(\d{15,})", html):
        mid = m.group(1)
        if mid not in seen:
            seen.add(mid)
            ids.append(mid)

    results = []
    for mid in ids[:20]:
        try:
            api = f"https://www.taptap.cn/webapiv2/moment/v2/detail?id={mid}&X-UA={XUA}"
            async with session.get(api, headers=HEADERS, timeout=15) as resp:
                data = await resp.json()
            redir = (data.get("redirect") or {}).get("web_url") or ""
            m = re.search(r"/topic/(\d+)", redir)
            if not m:
                continue
            topic_id = m.group(1)

            api = f"https://www.taptap.cn/webapiv2/topic/v1/detail?id={topic_id}&X-UA={XUA}"
            async with session.get(api, headers=HEADERS, timeout=15) as resp:
                data = await resp.json()
            moment = (data.get("data") or {}).get("moment") or {}
            if not moment.get("is_official"):
                continue
            topics = (moment.get("extended_entities") or {}).get("topics") or [{}]
            t = topics[0] if topics else {}
            results.append({
                "id": mid,
                "title": (t.get("title") or "")[:200],
                "url": f"https://www.taptap.cn/moment/{mid}",
                "publish_time": moment.get("publish_time") or 0,
                "topic_id": topic_id,
                "summary": (t.get("summary") or "").strip(),
                "images_api": t.get("images") or [],
            })
        except Exception as e:
            logger.warning(f"Loi meta {mid}: {e}")

    results.sort(key=lambda x: x["publish_time"], reverse=True)
    logger.info("Top 3: " + str([(p["id"], p["title"][:40]) for p in results[:3]]))
    return results[:12]


async def fetch_post_detail(session: aiohttp.ClientSession, post: dict) -> dict:
    moment_id = post["id"]
    result = {
        "title": post.get("title") or "",
        "content": post.get("summary") or "",
        "images": [],
        "video_url": None,
        "is_official": True,
        "url": post["url"],
    }

    for img in post.get("images_api") or []:
        src = img.get("original_url") or img.get("url") or ""
        if img.get("gif_url"):
            g = img["gif_url"]
            if g and g.startswith("http"):
                src = g
        if not src or src.startswith("data:"):
            continue
        if any(x in src.lower() for x in ("avatar", "icon", "appicon")):
            continue
        if src.startswith("//"):
            src = "https:" + src
        if src not in result["images"]:
            result["images"].append(src)

    try:
        async with session.get(post["url"], headers=HEADERS, timeout=30) as resp:
            if resp.status == 200:
                html = await resp.text()
                soup = BeautifulSoup(html, "lxml")
                for meta in soup.select("meta"):
                    prop = (meta.get("property") or meta.get("name") or "").lower()
                    content = meta.get("content") or ""
                    if prop == "og:title" and content:
                        result["title"] = content.split(" - ")[0].strip()
                    elif prop in ("og:description", "description"):
                        if len(content) > len(result["content"]):
                            result["content"] = content.strip()

                for v in soup.select("video source, video[src]"):
                    vsrc = v.get("src") or v.get("data-src") or ""
                    if vsrc and vsrc.startswith("http") and not vsrc.startswith("data:"):
                        result["video_url"] = vsrc
                        break
                if not result["video_url"]:
                    m = re.search(r'https?://[^"\']+\.mp4[^"\']*', html)
                    if m:
                        result["video_url"] = m.group(0).split('"')[0].split("'")[0]

                if not result["images"]:
                    for img in soup.select("img[src*='tapimg'], img[data-src*='tapimg']"):
                        src = img.get("src") or img.get("data-src") or ""
                        if not src or src.startswith("data:"):
                            continue
                        if any(x in src.lower() for x in ("avatar", "icon", "appicon")):
                            continue
                        if src.startswith("//"):
                            src = "https:" + src
                        src = re.sub(r"/_tap_ugc(_[ms])?\.(jpg|png|gif|webp)", "", src)
                        if src not in result["images"]:
                            result["images"].append(src)
    except Exception as e:
        logger.warning(f"Loi fetch page {moment_id}: {e}")

    result["images"] = [
        s for s in result["images"]
        if s and not s.startswith("data:") and "1x1" not in s.lower()
    ]
    return result


# ========== DISCORD ==========
intents = discord.Intents.default()
bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    logger.info(f"Da login: {bot.user} (ID: {bot.user.id})")
    if not check_new_posts.is_running():
        check_new_posts.start()


@tasks.loop(minutes=CHECK_INTERVAL)
async def check_new_posts():
    global seen_posts, last_publish_time
    channel = bot.get_channel(CHANNEL_ID)
    if channel is None:
        logger.error("Khong tim thay channel. Kiem tra CHANNEL_ID.")
        return

    async with aiohttp.ClientSession() as session:
        posts = await fetch_official_list(session)
        if not posts:
            logger.info("Khong lay duoc post.")
            return

        top3 = posts[:MAX_POSTS_PER_CYCLE]

        if not seen_posts and last_publish_time == 0:
            logger.info(
                f"Lan dau: gui {len(top3)} post gan nhat (cu -> moi), "
                f"danh dau cac post con lai."
            )
            for p in posts:
                if p["id"] not in {x["id"] for x in top3}:
                    seen_posts.add(p["id"])
            save_seen(seen_posts)
            to_send = list(reversed(top3))
        else:
            new_posts = []
            for p in posts:
                if p["id"] in seen_posts:
                    continue
                pts = int(p.get("publish_time") or 0)
                if last_publish_time and pts <= last_publish_time:
                    seen_posts.add(p["id"])
                    continue
                new_posts.append(p)

            if not new_posts:
                save_seen(seen_posts)
                logger.info("Khong co post moi.")
                return

            batch = new_posts[:MAX_POSTS_PER_CYCLE]
            to_send = list(reversed(batch))

        logger.info(
            "Thu tu gui (cu -> moi): "
            + str([(p["id"], p["title"][:30]) for p in to_send])
        )

        for post in to_send:
            detail = await fetch_post_detail(session, post)
            title = detail["title"] or post.get("title") or "Khong co tieu de"
            content = detail["content"] or ""
            images = detail["images"]

            logger.info(f"Xu ly {post['id']} | {title[:50]} | {post['url']}")

            if not content and not images:
                logger.warning(f"Rong: {post['id']}")
                seen_posts.add(post["id"])
                save_seen(seen_posts)
                continue

            if content:
                block = f"TIEU DE:\n{title}\n\nNOI DUNG:\n{content}"
            else:
                block = f"TIEU DE:\n{title}"
            translated = translate_to_vietnamese(block)

            title_vi = title
            content_vi = content
            if translated and translated != block:
                m_title = re.search(
                    r"(?:TIEU DE|TIÊU ĐỀ)\s*:\s*(.+?)(?:\n\s*(?:NOI DUNG|NỘI DUNG)\s*:|$)",
                    translated,
                    re.I | re.S,
                )
                m_body = re.search(
                    r"(?:NOI DUNG|NỘI DUNG)\s*:\s*(.+)$",
                    translated,
                    re.I | re.S,
                )
                if m_title:
                    title_vi = m_title.group(1).strip()
                if m_body:
                    content_vi = m_body.group(1).strip()
                elif not m_title:
                    lines = [ln.strip() for ln in translated.split("\n") if ln.strip()]
                    if lines:
                        title_vi = lines[0][:256]
                        content_vi = "\n".join(lines[1:]) if len(lines) > 1 else content
            else:
                if content:
                    content_vi = content + "\n\n_(Ban dich tam thoi loi / het quota Gemini)_"

            desc = content_vi or "Khong co noi dung text"
            if detail.get("video_url") or "PV" in title or "视频" in title:
                desc = f"🎬 [Xem tren TapTap]({post['url']})\n\n" + desc
            if len(desc) > 4090:
                desc = desc[:4090] + "..."

            embed = discord.Embed(
                title=title_vi[:256],
                description=desc,
                url=post["url"],
                color=0x00A8FF,
                timestamp=datetime.now(timezone.utc),
            )
            embed.set_footer(text="GFL2 Official • TapTap CN • Dich boi Gemini")

            files = []
            for i, img_url in enumerate(images[:8]):
                if not img_url or img_url.startswith("data:"):
                    continue
                try:
                    async with session.get(img_url, headers=HEADERS, timeout=20) as r:
                        if r.status != 200:
                            continue
                        data = await r.read()
                        if len(data) < 500:
                            continue
                        is_gif = (
                            data[:6] in (b"GIF87a", b"GIF89a")
                            or "gif" in img_url.lower()
                        )
                        ext = "gif" if is_gif else "jpg"
                        files.append(
                            discord.File(BytesIO(data), filename=f"img_{i}.{ext}")
                        )
                except Exception as e:
                    logger.warning(f"Loi anh: {e}")

            try:
                await channel.send(embed=embed, files=files if files else None)
                seen_posts.add(post["id"])
                save_seen(seen_posts)
                pts = int(post.get("publish_time") or 0)
                if pts > last_publish_time:
                    last_publish_time = pts
                    save_last_time(last_publish_time)
                logger.info(f"Da gui {post['id']}")
            except Exception as e:
                logger.error(f"Loi Discord: {e}")

            await asyncio.sleep(2)


@check_new_posts.before_loop
async def before_check():
    await bot.wait_until_ready()


# ========== KEEP-ALIVE ==========
async def health(request):
    return web.Response(text="GFL2 Bot is alive")


async def start_web_server():
    app = web.Application()
    app.router.add_get("/", health)
    app.router.add_get("/health", health)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", PORT)
    await site.start()
    logger.info(f"Web server listening on port {PORT}")


async def main():
    await start_web_server()
    async with bot:
        await bot.start(DISCORD_TOKEN)


if __name__ == "__main__":
    if not DISCORD_TOKEN or not CHANNEL_ID:
        raise ValueError("Thieu DISCORD_TOKEN hoac CHANNEL_ID")
    asyncio.run(main())