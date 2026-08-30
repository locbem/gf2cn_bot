# -*- coding: utf-8 -*-
import os
import json
import asyncio
import logging
import re
from datetime import datetime, timezone
from io import BytesIO

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
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL_MINUTES", "10"))
GEMINI_MODEL = "gemini-3.5-flash"

SEEN_FILE = "seen_posts.json"
PORT = int(os.getenv("PORT", "10000"))
MAX_POSTS_PER_CYCLE = 1

XUA = "V%3D1%26PN%3DWebApp%26LANG%3Dzh_CN%26VN_CODE%3D100000000%26LOC%3DCN%26PLT%3DPC"

# ========== LOGGING ==========
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("gfl2-bot")

# ========== GEMINI (google-genai moi) ==========
if not GEMINI_API_KEY:
    raise ValueError("Thieu GEMINI_API_KEY trong environment")
client = genai.Client(api_key=GEMINI_API_KEY)

NAME_MAP = (
    "希丽雅=Cecilia | 桑朵莱希=Centaureissi | 莱娅=Leva | 伊格蕾塔=Eagletta | "
    "可露凯=Klukai | 威玛西娜=Voymastina | 刘易斯=Lewis | 托洛洛=Tololo | "
    "琼玖=Qiongjiu | 维普蕾=Vepley | 佩里缇亚=Peritya | 塞布丽娜=Sabrina | "
    "格罗扎=Groza | 克罗丽科=Krolik | 科勒芬=Colphne | 涅墨西斯=Nemesis | "
    "斯普林菲尔德=Springfield | 玛奇亚托=Makiatto | 铃兰=Suomi | 矢量=Vector | "
    "梅奇=Mechty | 贝露卡=Belka | 安朵莉丝=Andoris | 尤希=Yoohee | "
    "弗洛伦=Florence | 琳德=Lind | 海伦=Helen | 法叶=Faye | 帕帕莎=Papasha | "
    "黛烟=Daiyan | 姜瑜=Jiangyu | 秋花=Qiuhua | 罗贝拉=Robella | "
    "乌尔丽德=Ullrid | 莱妮=Lainie | 莱娜=Lenna | 杜莎妮=Dushevnaya | "
    "莫辛纳甘=Mosin-Nagant | 夏安=Cheyanne | 哈普西=Harpsy | 洛塔=Lotta"
)


def translate_to_vietnamese(text: str) -> str:
    if not text or not text.strip():
        return text
    text = text[:8000]
    prompt = (
        "Ban la dich gia game Girls' Frontline 2: Exilium (少前2).\n"
        "Dich tieng Trung sang tieng Viet tu nhien, giu markdown neu co.\n\n"
        "QUY TAC:\n"
        "1. 人形/战术人形/精英人形/标准人形 -> T-Doll (KHONG dung nhan hinh/hinh nhan).\n"
        f"2. Ten nhan vat dung bang IOP Wiki: {NAME_MAP}\n"
        "   Khong co trong bang thi giu ten Trung. CAM tu che (Ciallo, Klaida...).\n"
        "3. 指挥官=Chi huy, 格里芬=Griffin, 艾莫号=Elmo.\n"
        "4. Chi tra ve ban dich, khong giai thich.\n\n"
        + text
    )
    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
        )
        return (response.text or "").strip()
    except Exception as e:
        logger.error(f"Loi dich: {e}")
        return text


# ========== SEEN POSTS ==========
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


seen_posts = load_seen()

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
    """Lay post official, sort theo publish_time (moi nhat truoc)."""
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
    """Title/content tu meta + API, images tu API, video chi lay link."""
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


# ========== DISCORD BOT ==========
intents = discord.Intents.default()
bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    logger.info(f"Da login: {bot.user} (ID: {bot.user.id})")
    if not check_new_posts.is_running():
        check_new_posts.start()


@tasks.loop(minutes=CHECK_INTERVAL)
async def check_new_posts():
    global seen_posts
    channel = bot.get_channel(CHANNEL_ID)
    if channel is None:
        logger.error("Khong tim thay channel. Kiem tra CHANNEL_ID.")
        return

    async with aiohttp.ClientSession() as session:
        posts = await fetch_official_list(session)
        if not posts:
            logger.info("Khong lay duoc post.")
            return

        if not seen_posts:
            logger.info(
                f"Lan dau: gui 1 post moi nhat ({posts[0]['id']}), "
                f"danh dau {len(posts) - 1} post con lai."
            )
            for p in posts[1:]:
                seen_posts.add(p["id"])
            save_seen(seen_posts)

        new_posts = [p for p in posts if p["id"] not in seen_posts]
        if not new_posts:
            logger.info("Khong co post moi.")
            return

        for post in new_posts[:MAX_POSTS_PER_CYCLE]:
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

            # Dich title + content 1 lan de tiet kiem quota
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