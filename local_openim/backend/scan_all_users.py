import requests
import time
import json

API_URL = "http://127.0.0.1:10002"
SECRET = "openIM123"
ADMIN_ID = "imAdmin"

# 新发现的用户 IDs
USER_IDS = ["2133879027", "8173002887", "4363667287", "7179594694", "5847732961"]

def get_admin_token():
    url = f"{API_URL}/auth/get_admin_token"
    headers = {"operationID": str(time.time())}
    payload = {"secret": SECRET, "userID": ADMIN_ID}
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    if data.get("errCode") == 0:
        return data.get("data", {}).get("token")
    return None

def get_user_info(admin_token, user_ids):
    url = f"{API_URL}/user/get_users_info"
    headers = {"operationID": str(time.time()), "token": admin_token}
    payload = {"userIDs": user_ids}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    return data.get("data", {}).get("usersInfo", [])

def get_user_token(admin_token, user_id):
    url = f"{API_URL}/auth/get_user_token"
    headers = {"operationID": str(time.time()), "token": admin_token}
    payload = {"secret": SECRET, "platformID": 1, "userID": user_id}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    if data.get("errCode") == 0:
        return data.get("data", {}).get("token")
    return None

def get_conversations(user_token, user_id):
    url = f"{API_URL}/conversation/get_all_conversations"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"ownerUserID": user_id}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("conversations", [])
    return []

def get_messages(user_token, user_id, conversation_id, max_seq):
    url = f"{API_URL}/msg/pull_msg_by_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    
    begin_seq = max(1, max_seq - 50)  # 从 1 开始而不是 0
    payload = {
        "userID": user_id,
        "conversationID": conversation_id,
        "beginSeq": begin_seq,
        "endSeq": max_seq,
        "num": 50
    }
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("msgs", [])
    return []

def main():
    print("=" * 80)
    print("SCANNING ALL USERS IN DATABASE")
    print("=" * 80)
    
    admin_token = get_admin_token()
    if not admin_token:
        print("[-] Failed to get admin token")
        return
    
    # 获取所有用户信息
    print(f"\n[*] Fetching user info for {len(USER_IDS)} users...")
    users_info = get_user_info(admin_token, USER_IDS)
    
    print(f"\n{'User ID':<15} {'Nickname':<20} {'Create Time'}")
    print("-" * 80)
    for user in users_info:
        user_id = user.get("userID")
        nickname = user.get("nickname", "N/A")
        create_time = user.get("createTime", 0)
        print(f"{user_id:<15} {nickname:<20} {create_time}")
    
    # 遍历每个用户，查找有消息的会话
    print("\n" + "=" * 80)
    print("SCANNING CONVERSATIONS FOR EACH USER")
    print("=" * 80)
    
    for user_id in USER_IDS:
        print(f"\n{'='*80}")
        print(f"USER: {user_id}")
        print(f"{'='*80}")
        
        user_token = get_user_token(admin_token, user_id)
        if not user_token:
            print(f"  [-] Could not get token for user {user_id}")
            continue
        
        conversations = get_conversations(user_token, user_id)
        print(f"  [*] Found {len(conversations)} conversations")
        
        for conv in conversations:
            conv_id = conv.get("conversationID")
            max_seq = conv.get("maxSeq", 0)
            min_seq = conv.get("minSeq", 0)
            conv_type = conv.get("conversationType")
            other_user = conv.get("userID", "")
            
            if max_seq > 0:
                print(f"\n  📱 Conversation: {conv_id}")
                print(f"     Type: {'Single' if conv_type == 1 else 'Group'}")
                print(f"     Other User: {other_user}")
                print(f"     Seq Range: {min_seq} - {max_seq}")
                
                # 获取消息
                messages = get_messages(user_token, user_id, conv_id, max_seq)
                
                if messages:
                    print(f"     ✅ Retrieved {len(messages)} messages:")
                    for msg in messages[:10]:  # 显示前10条
                        sender = msg.get("sendID")
                        seq = msg.get("seq")
                        content_str = msg.get("content", "{}")
                        send_time = msg.get("sendTime", 0)
                        
                        try:
                            content = json.loads(content_str)
                            text = content.get("text", content_str)
                        except:
                            text = content_str
                        
                        if len(text) > 60:
                            text = text[:60] + "..."
                        
                        print(f"        [{seq}] {sender}: {text}")
                else:
                    print(f"     ⚠️  No messages retrieved (API returned empty)")

if __name__ == "__main__":
    main()
