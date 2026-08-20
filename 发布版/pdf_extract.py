# -*- coding: utf-8 -*-
# MAP文件工具箱 - PDF 文字与坐标提取（供 LBD 识别使用）
# 输出格式（制表符分隔，UTF-8）:
#   P\t页号\t页标题文本(前150字)
#   L\t页号\tfx\tfy\t文字片段   （fx/fy 为页内相对位置 0~1，原点左下）
# 用法: pdf_extract.py <pdf> <out.txt> [pageStart] [pageEnd]
import sys

def main():
    if len(sys.argv) < 3:
        print("usage: pdf_extract.py <pdf> <out.txt> [pageStart] [pageEnd]")
        sys.exit(1)
    pdf, out = sys.argv[1], sys.argv[2]
    try:
        from pypdf import PdfReader
    except ImportError:
        try:
            from PyPDF2 import PdfReader
        except ImportError:
            print("ERR:pypdf missing, run: python -m pip install pypdf")
            sys.exit(2)
    try:
        reader = PdfReader(pdf)
        n = len(reader.pages)
    except Exception as e:
        print("ERR:open pdf failed: %s" % e)
        sys.exit(3)
    p0 = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    p1 = int(sys.argv[4]) if len(sys.argv) > 4 else n
    if p0 < 1: p0 = 1
    if p1 > n: p1 = n
    lines = []
    for idx in range(p0 - 1, p1):
        page = reader.pages[idx]
        try:
            cb = page.cropbox
            x0, y0 = float(cb.left), float(cb.bottom)
            pw = float(cb.right) - x0
            ph = float(cb.top) - y0
        except Exception:
            x0, y0, pw, ph = 0.0, 0.0, 1.0, 1.0
        if pw <= 0: pw = 1.0
        if ph <= 0: ph = 1.0
        items = []
        all_text = []
        def visit_text(text, cm, tm, font, size):
            if text:
                all_text.append(text)
                try:
                    dx = cm[0]*tm[4] + cm[2]*tm[5] + cm[4]
                    dy = cm[1]*tm[4] + cm[3]*tm[5] + cm[5]
                except Exception:
                    dx, dy = tm[4], tm[5]
                items.append([text, dx, dy])
        try:
            page.extract_text(visitor_text=visit_text)
        except Exception:
            items = []
        title = "".join(all_text[:100])
        lines.append("P\t%d\t%.2f\t%.2f\t%s" % (idx + 1, pw, ph, title[:150].replace("\t", " ").replace("\n", " ")))
        for it in items:
            if "LBD" not in it[0].upper():
                continue
            dx, dy = it[1], it[2]
            if dx < x0 or dy < y0 or dx > x0 + pw or dy > y0 + ph:
                continue
            fx = (dx - x0) / pw
            fy = (dy - y0) / ph
            lines.append("L\t%d\t%.6f\t%.6f\t%s" % (idx + 1, fx, fy, it[0].replace("\t", " ").replace("\n", " ")))
        print("page %d/%d" % (idx + 1, n), flush=True)
    try:
        with open(out, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
    except Exception as e:
        print("ERR:write out failed: %s" % e)
        sys.exit(4)
    print("DONE %d" % (p1 - p0 + 1))

main()