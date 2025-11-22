"""
直接从 MongoDB 读取 OpenIM 消息的脚本

由于发现 conversation 表的 maxSeq 字段可能不准确，
这个脚本直接从 msg 集合中读取实际的消息数据。
"""

import subprocess
import json

def run_mongo_command(command):
    """执行 MongoDB 命令"""
    docker_cmd = [
        'docker', 'exec', '-i',
        subprocess.check_output(['docker', 'ps', '|', 'grep', 'mongo', '|', 'awk', "'{print $1}'"], 
                               shell=True, text=True).strip(),
        'mongosh', '-u', 'openIM', '-p', 'openIM123',
        '--authenticationDatabase', 'openim_v3',
        'openim_v3', '--quiet', '--eval', command
    ]
    
    try:
        result = subprocess.run(docker_cmd, capture_output=True, text=True, timeout=10)
        return result.stdout
    except Exception as e:
        print(f"Error: {e}")
        return None

def get_all_conversations_from_db():
    """从 msg 集合获取所有会话 ID"""
    command = """
    db.msg.find({}, {doc_id: 1}).forEach(doc => {
        var parts = doc.doc_id.split(':');
        print(parts[0]);
    });
    """
    result = run_mongo_command(command)
    if result:
        conversations = set(result.strip().split('\n'))
        return [c for c in conversations if c and not c.startswith('n_')]  # 过滤通知
    return []

def get_messages_for_conversation(conv_id):
    """获取指定会话的所有消息"""
    command = f"""
    var doc = db.msg.findOne({{'doc_id': '{conv_id}:0'}});
    if (doc && doc.msgs) {{
        var messages = [];
        for (var i = 0; i < doc.msgs.length; i++) {{
            if (doc.msgs[i].msg != null) {{
                var m = doc.msgs[i].msg;
                messages.push({{
                    seq: m.seq.toString(),
                    sendID: m.send_id,
                    recvID: m.recv_id,
                    content: m.content,
                    sendTime: m.send_time.toString(),
                    senderNickname: m.sender_nickname
                }});
            }}
        }}
        print(JSON.stringify(messages));
    }} else {{
        print('[]');
    }}
    """
    
    result = run_mongo_command(command)
    if result:
        try:
            return json.loads(result.strip())
        except:
            return []
    return []

def main():
    print("=" * 80)
    print("直接从 MongoDB 读取 OpenIM 消息")
    print("=" * 80)
    
    # 1. 获取所有会话
    print("\n[*] 扫描 msg 集合中的所有会话...")
    conversations = get_all_conversations_from_db()
    print(f"[+] 找到 {len(conversations)} 个会话")
    
    # 2. 遍历每个会话，获取消息
    for conv_id in conversations:
        print(f"\n{'='*80}")
        print(f"会话: {conv_id}")
        print(f"{'='*80}")
        
        messages = get_messages_for_conversation(conv_id)
        
        if messages:
            print(f"✅ 找到 {len(messages)} 条消息:\n")
            for msg in messages:
                sender = msg.get('senderNickname', msg.get('sendID'))
                content_str = msg.get('content', '{}')
                
                try:
                    content = json.loads(content_str)
                    text = content.get('content', content.get('text', content_str))
                except:
                    text = content_str
                
                send_time = int(msg.get('sendTime', 0)) // 1000
                from datetime import datetime
                time_str = datetime.fromtimestamp(send_time).strftime('%Y-%m-%d %H:%M:%S')
                
                print(f"  [{msg.get('seq')}] {sender} ({time_str}):")
                print(f"      {text}")
                print()
        else:
            print("  ⚠️  此会话没有消息")

if __name__ == "__main__":
    main()
