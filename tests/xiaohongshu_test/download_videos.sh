#!/bin/bash
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
