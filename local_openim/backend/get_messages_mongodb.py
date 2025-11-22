"""
OpenIM 消息获取脚本 - MongoDB 直连版本

由于发现 OpenIM 的 conversation.maxSeq 字段未正确更新，
导致 REST API 无法正确拉取消息。

此脚本直接从 MongoDB 读取消息，适用于：
1. 本地开发和调试
2. 数据分析和导出
3. API 无法正常工作时的备用方案

上云后建议：
1. 优先修复 OpenIM 的 maxSeq 更新问题
2. 或使用此脚本通过 VPN/专线连接云端 MongoDB
3. 或定期同步数据到本地分析库
"""

import subprocess
import json
from datetime import datetime

# MongoDB 配置
MONGO_HOST = "localhost"
MONGO_PORT = "37017"
MONGO_USER = "openIM"
MONGO_PASS = "openIM123"
MONGO_DB = "openim_v3"

def get_docker_mongo_container():
    """获取 MongoDB 容器 ID"""
    try:
        result = subprocess.run(
            "docker ps | grep mongo | awk '{print $1}'",
            shell=True,
            capture_output=True,
            text=True
        )
        return result.stdout.strip()
    except:
        return None

def run_mongo_query(query):
    """执行 MongoDB 查询"""
    container_id = get_docker_mongo_container()
    if not container_id:
        print("[-] MongoDB 容器未找到")
        return None
    
    cmd = [
        'docker', 'exec', '-i', container_id,
        'mongosh', '-u', MONGO_USER, '-p', MONGO_PASS,
        '--authenticationDatabase', MONGO_DB,
        MONGO_DB, '--quiet', '--eval', query
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except Exception as e:
        print(f"[-] 查询失败: {e}")
        return None

def get_user_messages(user_id):
    """
    获取指定用户的所有消息
    
    Args:
        user_id: 用户 ID (例如: "7179594694")
    
    Returns:
        list: 消息列表，每条消息包含：
            - seq: 序列号
            - conversationID: 会话 ID
            - sendID: 发送者 ID
            - recvID: 接收者 ID
            - senderNickname: 发送者昵称
            - content: 消息内容
            - sendTime: 发送时间（时间戳）
            - isRead: 是否已读
    """
    query = f"""
    var userId = '{user_id}';
    var allMessages = [];
    
    // 查找所有包含该用户的会话
    db.msg.find({{}}).forEach(function(doc) {{
        var convId = doc.doc_id.split(':')[0];
        
        // 只处理单聊会话（si_ 开头）且包含目标用户
        if (convId.startsWith('si_') && convId.includes(userId)) {{
            if (doc.msgs) {{
                for (var i = 0; i < doc.msgs.length; i++) {{
                    if (doc.msgs[i].msg != null) {{
                        var m = doc.msgs[i].msg;
                        
                        // 只获取文本消息（contentType 101）
                        if (m.content_type == 101) {{
                            allMessages.push({{
                                seq: m.seq.toString(),
                                conversationID: convId,
                                sendID: m.send_id,
                                recvID: m.recv_id,
                                senderNickname: m.sender_nickname || m.send_id,
                                content: m.content,
                                sendTime: m.send_time.toString(),
                                isRead: doc.msgs[i].is_read
                            }});
                        }}
                    }}
                }}
            }}
        }}
    }});
    
    print(JSON.stringify(allMessages));
    """
    
    result = run_mongo_query(query)
    if result:
        try:
            messages = json.loads(result)
            # 按时间排序
            messages.sort(key=lambda x: int(x['sendTime']))
            return messages
        except json.JSONDecodeError as e:
            print(f"[-] JSON 解析失败: {e}")
            print(f"原始输出: {result}")
            return []
    return []

def format_message(msg):
    """格式化消息显示"""
    # 解析内容
    try:
        content_obj = json.loads(msg['content'])
        text = content_obj.get('content', content_obj.get('text', msg['content']))
    except:
        text = msg['content']
    
    # 格式化时间
    timestamp = int(msg['sendTime']) / 1000
    time_str = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
    
    # 判断消息方向
    sender = msg['senderNickname']
    is_sent = msg['sendID'] == msg.get('ownerID', '')
    direction = "→" if is_sent else "←"
    
    return f"[{time_str}] {direction} {sender}: {text}"

def main():
    import sys
    
    if len(sys.argv) < 2:
        print("用法: python3 get_messages_mongodb.py <user_id>")
        print("示例: python3 get_messages_mongodb.py 7179594694")
        sys.exit(1)
    
    user_id = sys.argv[1]
    
    print(f"{'='*80}")
    print(f"获取用户 {user_id} 的聊天记录")
    print(f"{'='*80}\n")
    
    messages = get_user_messages(user_id)
    
    if not messages:
        print("[-] 未找到消息")
        return
    
    print(f"[+] 找到 {len(messages)} 条消息\n")
    
    # 按会话分组显示
    conversations = {}
    for msg in messages:
        conv_id = msg['conversationID']
        if conv_id not in conversations:
            conversations[conv_id] = []
        conversations[conv_id].append(msg)
    
    for conv_id, conv_messages in conversations.items():
        print(f"\n{'='*80}")
        print(f"会话: {conv_id}")
        print(f"消息数: {len(conv_messages)}")
        print(f"{'='*80}\n")
        
        for msg in conv_messages:
            print(format_message(msg))
    
    print(f"\n{'='*80}")
    print(f"总计: {len(messages)} 条消息")
    print(f"{'='*80}")

if __name__ == "__main__":
    main()
