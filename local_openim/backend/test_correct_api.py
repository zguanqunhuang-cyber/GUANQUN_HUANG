import requests
import time
import json

API_URL = "http://127.0.0.1:10002"
TARGET_USER_ID = "7179594694"
SECRET = "openIM123"
ADMIN_ID = "imAdmin"

def get_admin_token():
    url = f"{API_URL}/auth/get_admin_token"
    headers = {"operationID": str(time.time())}
    payload = {"secret": SECRET, "userID": ADMIN_ID}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    if data.get("errCode") == 0:
        return data.get("data", {}).get("token")
    return None

def get_user_token(admin_token, user_id):
    url = f"{API_URL}/auth/get_user_token"
    headers = {"operationID": str(time.time()), "token": admin_token}
    payload = {"secret": SECRET, "platformID": 1, "userID": user_id}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    if data.get("errCode") == 0:
        return data.get("data", {}).get("token")
    return None

def get_newest_seq(user_token, user_id):
    """获取用户所有会话的最新序列号"""
    url = f"{API_URL}/msg/newest_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"userID": user_id}
    
    print(f"[*] Getting newest seq for user {user_id}...")
    resp = requests.post(url, json=payload, headers=headers)
    
    print(f"Status code: {resp.status_code}")
    
    if not resp.text:
        print("[-] Empty response from server")
        return {}
    
    try:
        data = resp.json()
        print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
        
        if data.get("errCode") == 0:
            return data.get("data", {})
    except json.JSONDecodeError as e:
        print(f"[-] JSON decode error: {e}")
    
    return {}

def get_conversations_max_seq(user_token, conversation_ids):
    """获取指定会话的已读和最大序列号"""
    url = f"{API_URL}/msg/get_conversations_has_read_and_max_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"conversationIDs": conversation_ids}
    
    print(f"\n[*] Getting max seq for conversations...")
    resp = requests.post(url, json=payload, headers=headers)
    
    if not resp.text:
        print("[-] Empty response")
        return {}
    
    try:
        data = resp.json()
        print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
        
        if data.get("errCode") == 0:
            return data.get("data", {})
    except json.JSONDecodeError as e:
        print(f"[-] JSON decode error: {e}")
    
    return {}

def pull_messages_by_seqs(user_token, user_id, conversation_id, begin_seq, end_seq):
    """使用正确的 PullMessageBySeqs API"""
    url = f"{API_URL}/msg/pull_msg_by_seqs"
    headers = {"operationID": str(time.time()), "token": user_token}
    
    # 正确的请求格式 (根据 proto 定义)
    payload = {
        "userID": user_id,
        "seqRanges": [
            {
                "conversationID": conversation_id,
                "begin": begin_seq,
                "end": end_seq,
                "num": end_seq - begin_seq + 1
            }
        ],
        "order": 0  # 0 = Asc, 1 = Desc
    }
    
    print(f"\n[*] Pulling messages with correct API...")
    print(f"Request payload: {json.dumps(payload, indent=2)}")
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
    
    return data

def get_conversations(user_token, user_id):
    url = f"{API_URL}/conversation/get_all_conversations"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"ownerUserID": user_id}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("conversations", [])
    return []

def main():
    print("=" * 80)
    print(f"Testing CORRECT API usage for user {TARGET_USER_ID}")
    print("=" * 80)
    
    # 1. Get tokens
    admin_token = get_admin_token()
    user_token = get_user_token(admin_token, TARGET_USER_ID)
    
    if not user_token:
        print("[-] Failed to get user token")
        return
    
    print(f"[+] User token obtained\n")
    
    # 2. Get conversations first
    print(f"[*] Getting conversations...")
    conversations = get_conversations(user_token, TARGET_USER_ID)
    print(f"[+] Found {len(conversations)} conversations\n")
    
    if not conversations:
        print("[!] No conversations found")
        return
    
    # 3. Get max seq for all conversations
    conv_ids = [conv.get("conversationID") for conv in conversations]
    max_seq_data = get_conversations_max_seq(user_token, conv_ids)
    
    # 4. 对每个会话使用正确的 API 拉取消息
    for conv in conversations:
        conv_id = conv.get("conversationID")
        print(f"\n{'='*80}")
        print(f"Conversation: {conv_id}")
        print(f"{'='*80}")
        
        # 从 API 响应获取这个会话的 maxSeq
        seq_info = max_seq_data.get(conv_id, {})
        max_seq = seq_info.get("maxSeq", 0)
        has_read_seq = seq_info.get("hasReadSeq", 0)
        
        print(f"Max seq: {max_seq}")
        print(f"Has read seq: {has_read_seq}")
        
        if max_seq > 0:
            # 使用正确的 API 拉取消息
            begin = 1
            result = pull_messages_by_seqs(user_token, TARGET_USER_ID, conv_id, begin, max_seq)
            
            # 解析消息
            if result.get("errCode") == 0:
                msgs_data = result.get("data", {})
                msgs = msgs_data.get("msgs", {}).get(conv_id, {}).get("Msgs", [])
                
                if msgs:
                    print(f"\n[+] Retrieved {len(msgs)} messages:")
                    for msg in msgs[:10]:
                        sender = msg.get("sendID")
                        seq = msg.get("seq")
                        content_str = msg.get("content", "")
                        
                        try:
                            content = json.loads(content_str)
                            text = content.get("content", content.get("text", content_str))
                        except:
                            text = content_str
                        
                        if isinstance(text, bytes):
                            text = text.decode('utf-8', errors='ignore')
                        
                        if len(str(text)) > 60:
                            text = str(text)[:60] + "..."
                        
                        print(f"  [{seq}] {sender}: {text}")
                    
                    if len(msgs) > 10:
                        print(f"  ... and {len(msgs) - 10} more messages")
                else:
                    print(f"\n[-] No messages in response")
        else:
            print(f"[!] Max seq is 0 - no messages in this conversation")

if __name__ == "__main__":
    main()
