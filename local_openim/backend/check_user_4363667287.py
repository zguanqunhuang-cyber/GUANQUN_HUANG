import requests
import time
import json

API_URL = "http://127.0.0.1:10002"
TARGET_USER_ID = "4363667287"  # 查看这个用户
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
    else:
        print(f"[-] Failed to get user token: {data}")
    return None

def get_user_info(admin_token, user_id):
    """获取用户信息"""
    url = f"{API_URL}/user/get_users_info"
    headers = {"operationID": str(time.time()), "token": admin_token}
    payload = {"userIDs": [user_id]}
    
    print(f"\n[*] Getting user info for {user_id}...")
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    print(f"User Info: {json.dumps(data, indent=2, ensure_ascii=False)}")
    return data

def get_conversations(user_token, user_id):
    url = f"{API_URL}/conversation/get_all_conversations"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"ownerUserID": user_id}
    
    print(f"\n[*] Getting conversations for {user_id}...")
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        conversations = data.get("data", {}).get("conversations", [])
        print(f"[+] Found {len(conversations)} conversations")
        return conversations
    else:
        print(f"[-] Failed: {data}")
        return []

def get_conversation_detail(user_token, user_id, conversation_id):
    url = f"{API_URL}/conversation/get_conversation"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"conversationID": conversation_id, "ownerUserID": user_id}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        conv = data.get("data", {}).get("conversation", {})
        return conv
    return None

def get_messages(user_token, user_id, conversation_id, max_seq):
    url = f"{API_URL}/msg/pull_msg_by_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    
    begin_seq = max(0, max_seq - 50)
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
    print(f"[*] Investigating user: {TARGET_USER_ID}")
    print("=" * 60)
    
    admin_token = get_admin_token()
    if not admin_token:
        print("[-] Failed to get admin token")
        return
    
    # 1. 获取用户信息
    user_info = get_user_info(admin_token, TARGET_USER_ID)
    
    # 2. 获取用户 Token
    print(f"\n[*] Getting user token for {TARGET_USER_ID}...")
    user_token = get_user_token(admin_token, TARGET_USER_ID)
    
    if not user_token:
        print("[-] Failed to get user token. User might not exist.")
        return
    
    print(f"[+] User token obtained")
    
    # 3. 获取会话列表
    conversations = get_conversations(user_token, TARGET_USER_ID)
    
    if not conversations:
        print("\n[!] This user has no conversations.")
        return
    
    # 4. 遍历每个会话
    print("\n" + "=" * 60)
    print("CONVERSATIONS DETAIL:")
    print("=" * 60)
    
    for idx, conv in enumerate(conversations, 1):
        conv_id = conv.get("conversationID")
        conv_type = conv.get("conversationType")
        other_user = conv.get("userID", "")
        group_id = conv.get("groupID", "")
        
        print(f"\n[{idx}] Conversation ID: {conv_id}")
        print(f"    Type: {'Single Chat' if conv_type == 1 else 'Group Chat' if conv_type == 2 else 'Unknown'}")
        
        if conv_type == 1:
            print(f"    Other User: {other_user}")
        elif conv_type == 2:
            print(f"    Group ID: {group_id}")
        
        # 获取详细信息
        detail = get_conversation_detail(user_token, TARGET_USER_ID, conv_id)
        if detail:
            min_seq = detail.get("minSeq", 0)
            max_seq = detail.get("maxSeq", 0)
            print(f"    Message Range: seq {min_seq} - {max_seq}")
            
            # 如果有消息，拉取消息
            if max_seq > 0:
                print(f"    [*] Fetching messages...")
                messages = get_messages(user_token, TARGET_USER_ID, conv_id, max_seq)
                
                if messages:
                    print(f"    [+] Retrieved {len(messages)} messages:")
                    for msg in messages[:5]:  # 只显示前5条
                        sender = msg.get("sendID")
                        seq = msg.get("seq")
                        content_str = msg.get("content", "{}")
                        
                        try:
                            content = json.loads(content_str)
                            text = content.get("text", content_str)
                        except:
                            text = content_str
                        
                        # 截断长消息
                        if len(text) > 50:
                            text = text[:50] + "..."
                        
                        print(f"        [{seq}] {sender}: {text}")
                    
                    if len(messages) > 5:
                        print(f"        ... and {len(messages) - 5} more messages")
                else:
                    print(f"    [-] No messages retrieved (might be notifications only)")
            else:
                print(f"    [!] No messages in this conversation")

if __name__ == "__main__":
    main()
