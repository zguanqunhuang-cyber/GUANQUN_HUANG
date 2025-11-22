#!/usr/bin/env python3
"""
小红书视频下载工具
支持下载指定用户的最新视频及评论
"""

import os
import json
import requests
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional


class XiaohongshuDownloader:
    """小红书视频下载器"""

    def __init__(self, output_dir: str = "xiaohongshu_downloads"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.xiaohongshu.com/',
        })

    def download_image(self, url: str, filename: str) -> bool:
        """下载图片"""
        try:
            print(f"  📥 下载图片: {filename}")
            response = self.session.get(url, timeout=30)
            response.raise_for_status()

            filepath = self.output_dir / filename
            with open(filepath, 'wb') as f:
                f.write(response.content)
            print(f"  ✅ 图片已保存: {filepath}")
            return True
        except Exception as e:
            print(f"  ❌ 下载图片失败: {e}")
            return False

    def download_video_from_url(self, video_url: str, filename: str) -> bool:
        """从URL下载视频"""
        try:
            print(f"  📥 下载视频: {filename}")
            response = self.session.get(video_url, timeout=60, stream=True)
            response.raise_for_status()

            filepath = self.output_dir / filename
            total_size = int(response.headers.get('content-length', 0))

            with open(filepath, 'wb') as f:
                if total_size == 0:
                    f.write(response.content)
                else:
                    downloaded = 0
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            downloaded += len(chunk)
                            progress = (downloaded / total_size) * 100
                            print(f"\r  进度: {progress:.1f}%", end='', flush=True)
            print(f"\n  ✅ 视频已保存: {filepath}")
            return True
        except Exception as e:
            print(f"\n  ❌ 下载视频失败: {e}")
            return False

    def parse_video_info_from_json(self, json_file: str) -> Optional[Dict]:
        """从已保存的JSON文件解析视频信息"""
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ 读取JSON文件失败: {e}")
            return None

    def try_get_video_url_variants(self, cover_url: str) -> List[str]:
        """
        尝试从封面URL推断可能的视频URL
        小红书的视频URL可能与封面URL有相似的模式
        """
        video_urls = []

        # 尝试将封面图的后缀替换为视频格式
        base_url = cover_url.rsplit('!', 1)[0] if '!' in cover_url else cover_url

        # 尝试不同的视频URL模式
        patterns = [
            base_url.replace('.webp', '.mp4'),
            base_url.replace('.jpg', '.mp4'),
            base_url.replace('webpic', 'video'),
            base_url,
        ]

        return patterns

    def download_covers_from_json_files(self):
        """从已有的JSON文件下载封面图"""
        json_files = list(self.output_dir.glob("video*_comments.json"))

        if not json_files:
            print("❌ 未找到视频信息JSON文件")
            return

        print(f"\n📋 找到 {len(json_files)} 个视频信息文件\n")

        for json_file in json_files:
            print(f"处理: {json_file.name}")
            video_info = self.parse_video_info_from_json(json_file)

            if not video_info:
                continue

            video_id = video_info.get('video_id', 'unknown')
            title = video_info.get('title', 'untitled').replace('/', '_').replace('\\', '_')

            # 从README中提取封面URL（这里需要手动提供，因为JSON中没有）
            print(f"  ℹ️  视频标题: {title}")
            print(f"  ℹ️  视频ID: {video_id}")
            print(f"  ⚠️  JSON文件中未包含封面URL，需要从README或其他来源获取")
            print()


def download_with_you_get(video_urls: List[str], output_dir: str = "xiaohongshu_downloads"):
    """
    使用 you-get 工具下载小红书视频
    需要先安装: pip install you-get
    """
    try:
        import subprocess

        print("\n🔧 使用 you-get 下载视频\n")

        for url in video_urls:
            print(f"📥 下载: {url}")
            try:
                result = subprocess.run(
                    ['you-get', '-o', output_dir, url],
                    capture_output=True,
                    text=True,
                    timeout=300
                )

                if result.returncode == 0:
                    print(f"✅ 下载成功\n{result.stdout}")
                else:
                    print(f"❌ 下载失败\n{result.stderr}")
            except subprocess.TimeoutExpired:
                print("❌ 下载超时")
            except FileNotFoundError:
                print("❌ 未找到 you-get 命令，请先安装: pip install you-get")
                return

            time.sleep(2)  # 避免请求过快

    except ImportError:
        print("❌ 需要安装 you-get: pip install you-get")


def create_download_script():
    """创建一个shell脚本来使用第三方工具下载"""
    script_content = """#!/bin/bash
# 小红书视频下载脚本
# 使用 you-get 工具下载视频

# 安装 you-get (如果未安装)
# pip install you-get

# 视频链接
VIDEO_URLS=(
    "https://www.xiaohongshu.com/explore/64952ac1000000001203ca5b"
    "https://www.xiaohongshu.com/explore/66716e25000000001d016091"
    "https://www.xiaohongshu.com/explore/667aa7f8000000001c0217d1"
)

# 输出目录
OUTPUT_DIR="xiaohongshu_downloads/videos"
mkdir -p "$OUTPUT_DIR"

# 下载视频
for url in "${VIDEO_URLS[@]}"; do
    echo "正在下载: $url"
    you-get -o "$OUTPUT_DIR" "$url"
    echo "---"
    sleep 2
done

echo "下载完成！"
"""

    script_path = Path("download_videos.sh")
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(script_content)

    # 添加执行权限
    os.chmod(script_path, 0o755)

    print(f"✅ 已创建下载脚本: {script_path}")
    print(f"   使用方法: ./download_videos.sh")


def main():
    """主函数"""
    print("=" * 60)
    print("小红书视频下载工具".center(60))
    print("=" * 60)

    # 初始化下载器
    downloader = XiaohongshuDownloader()

    # 视频信息（从已保存的数据中读取）
    videos = [
        {
            "video_id": "64952ac1000000001203ca5b",
            "title": "有这双手，ps都不需要了吧！",
            "url": "https://www.xiaohongshu.com/explore/64952ac1000000001203ca5b",
            "cover_url": "http://sns-webpic-qc.xhscdn.com/202511152026/95c3e15740c3078eb080472874e0dcf6/1000g0082mlercrkjm0605nod9gsg8v5ft0a0kuo!nd_dft_wlteh_webp_3"
        },
        {
            "video_id": "66716e25000000001d016091",
            "title": "被画封印住的摄魂鬼手",
            "url": "https://www.xiaohongshu.com/explore/66716e25000000001d016091",
            "cover_url": "http://sns-webpic-qc.xhscdn.com/202511152028/1413574def9786f77d7b9a7cbedbcdd7/1040g2sg3146eu2oe1ob05nod9gsg8v5fhbe3npg!nd_dft_wlteh_webp_3"
        },
        {
            "video_id": "667aa7f8000000001c0217d1",
            "title": "第一次这么直观的感受到，大家眼中的差异！",
            "url": "https://www.xiaohongshu.com/explore/667aa7f8000000001c0217d1",
            "cover_url": "http://sns-webpic-qc.xhscdn.com/202511152027/26103126d0737ea24d7fd6c6f1dafed5/1040g008314ff7up76g6g5nod9gsg8v5fd14bce8!nd_dft_wlteh_webp_3"
        }
    ]

    print("\n📋 准备下载 3 个视频\n")

    # 选项1: 下载封面图
    print("=" * 60)
    print("选项 1: 下载封面图")
    print("=" * 60)
    for i, video in enumerate(videos, 1):
        print(f"\n[{i}/3] {video['title']}")
        filename = f"cover_{video['video_id']}.webp"
        downloader.download_image(video['cover_url'], filename)

    # 选项2: 创建下载脚本
    print("\n" + "=" * 60)
    print("选项 2: 创建视频下载脚本")
    print("=" * 60)
    create_download_script()

    # 选项3: 使用 you-get 下载（如果已安装）
    print("\n" + "=" * 60)
    print("选项 3: 使用 you-get 直接下载")
    print("=" * 60)
    print("\n⚠️  说明:")
    print("  - 需要先安装: pip install you-get")
    print("  - 如果已安装，取消下面代码的注释即可自动下载\n")

    # 取消注释以使用 you-get 下载
    # video_urls = [v['url'] for v in videos]
    # download_with_you_get(video_urls)

    print("\n" + "=" * 60)
    print("完成！".center(60))
    print("=" * 60)
    print("\n📁 文件保存位置: xiaohongshu_downloads/")
    print("\n💡 下载视频的推荐方法:")
    print("  1. 使用 you-get: pip install you-get && ./download_videos.sh")
    print("  2. 使用 yt-dlp: pip install yt-dlp && yt-dlp <视频链接>")
    print("  3. 使用浏览器插件（如 Video DownloadHelper）")
    print()


if __name__ == "__main__":
    main()
