"""Render every final manuscript page, with contact sheets and R11 details."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "pdf-qa"
OUT.mkdir(exist_ok=True)
PDFS = {"arxiv": "arxiv-paper/Paper_v1.pdf", "jfds": "jfds-paper/Paper_v1.pdf",
        "supplement": "jfds-paper/Supplement_v1.pdf"}


def render(item):
    name, relative = item
    pdf = ROOT / relative
    subprocess.run(["pdftoppm", "-scale-to", "900", "-png", str(pdf), str(OUT / name)], check=True)
    text = subprocess.check_output(["pdftotext", "-layout", str(pdf), "-"], text=True)
    pages = text.split("\f")
    if not pages[-1].strip():
        pages.pop()
    (OUT / f"{name}.txt").write_text(text)
    details = []
    phrases = ("We used a Gaussian", "The Gaussian grid supplemented", "The synthetic grid checked",
               "Restricted Gaussian check")
    for number, page in enumerate(pages, 1):
        flat = " ".join(page.split())
        if any(phrase in flat for phrase in phrases):
            details.append(number)
            subprocess.run(["pdftoppm", "-f", str(number), "-l", str(number), "-r", "120",
                            "-singlefile", "-png", str(pdf), str(OUT / f"{name}-detail-{number:02}")], check=True)
    images = sorted(OUT.glob(f"{name}-[0-9]*.png"))
    assert len(images) == len(pages)
    for start in range(0, len(images), 12):
        sheet = Image.new("RGB", (1800, 1875), "#dddddd")
        draw = ImageDraw.Draw(sheet)
        for index, path in enumerate(images[start:start + 12]):
            im = Image.open(path).convert("RGB")
            im.thumbnail((440, 590))
            x, y = index % 4 * 450, index // 4 * 625
            draw.text((x + 10, y + 8), f"{name} page {start + index + 1}", fill="black")
            sheet.paste(im, (x + (450 - im.width)//2, y + 30))
        sheet.save(OUT / f"{name}-contact-{start//12+1}.png")
    return name, {"pdf": relative, "pages": len(pages), "detail_pages": details}


with ThreadPoolExecutor(max_workers=3) as executor:
    record = dict(executor.map(render, PDFS.items()))
(OUT / "render-manifest.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
