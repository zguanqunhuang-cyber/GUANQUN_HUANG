#!/usr/bin/env python3
"""下载小红书图文笔记的所有图片"""

import requests
import os
from pathlib import Path

# 图片URL列表（从API获取）
images = [
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/96ed6f6489339efb4b0d596ff4eceda0/notes_pre_post/1040g3k031g884t51hq005nej9c508rn0e321g2o!nd_dft_wlteh_webp_3",
        "filename": "image_1.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/1701cc585d2c52b5bfda1e394c446c90/notes_pre_post/1040g3k031g884t51hq0g5nej9c508rn06l3qk30!nd_dft_wlteh_webp_3",
        "filename": "image_2.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/bcf1ea51175db4f92b8b128bd4ef496b/notes_pre_post/1040g3k031g884t51hq105nej9c508rn0bq34j00!nd_dft_wlteh_webp_3",
        "filename": "image_3.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/3ce7f8f05ab6699f748db49fad58f720/notes_pre_post/1040g3k031g884t51hq1g5nej9c508rn07gfmmq0!nd_dft_wlteh_webp_3",
        "filename": "image_4.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/2e6deb11adb472f58077f1a2cc738edd/notes_pre_post/1040g3k031g884t51hq205nej9c508rn0i7f4ml8!nd_dft_wlteh_webp_3",
        "filename": "image_5.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/cafa2b964515bd155a69109d109c192c/notes_pre_post/1040g3k031g884t51hq2g5nej9c508rn0nlmvqso!nd_dft_wlteh_webp_3",
        "filename": "image_6.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/9237a86c12651678a1d67df46cd54f75/notes_pre_post/1040g3k031g884t51hq305nej9c508rn0pljcdd8!nd_dft_wlteh_webp_3",
        "filename": "image_7.webp"
    },
    {
        "url": "http://sns-webpic-qc.xhscdn.com/202511152045/b3faab447b34da384e4f100ef92db174/notes_pre_post/1040g3k031g884t51hq3g5nej9c508rn01j26d90!nd_dft_wlteh_webp_3",
        "filename": "image_8.webp"
    }
]

# 创建输出目录
output_dir = Path("xiaohongshu_downloads/note_67fc7a7f0000000007036462")
output_dir.mkdir(parents=True, exist_ok=True)

# 下载图片
session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
})

print(f"📥 开始下载 8 张图片到: {output_dir}\n")

for i, img in enumerate(images, 1):
    try:
        print(f"[{i}/8] 下载: {img['filename']}")
        response = session.get(img['url'], timeout=30)
        response.raise_for_status()

        filepath = output_dir / img['filename']
        with open(filepath, 'wb') as f:
            f.write(response.content)

        file_size = len(response.content) / 1024  # KB
        print(f"  ✅ 成功 ({file_size:.1f} KB)\n")
    except Exception as e:
        print(f"  ❌ 失败: {e}\n")

print("🎉 下载完成！")
