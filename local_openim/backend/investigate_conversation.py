import requests
import time
import json

API_URL = "http://127.0.0.1:10002"
TARGET_USER_ID = "7179594694"
CONVERSATION_ID = "si_4363667287_7179594694"

# 从之前的成功运行中，我们知道这些凭据是正确的
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

def get_conversation_detail(user_token, conversation_id):
    """获取会话详情"""
    url = f"{API_URL}/conversation/get_conversation"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"conversationID": conversation_id, "ownerUserID": TARGET_USER_ID}
    
    print(f"\n[*] Getting conversation detail...")
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
    return data

def search_messages(user_token, user_id):
    """搜索消息"""
    url = f"{API_URL}/msg/search_msg"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {
        "conversationID": CONVERSATION_ID,
        "sendTime": 0,
        "sessionType": 1,  # 1=单聊
        "pagination": {
            "pageNumber": 1,
            "showNumber": 20
        }
    }
    
    print(f"\n[*] Searching messages...")
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
    return data

def get_newest_seq(user_token):
    """获取最新序列号"""
    url = f"{API_URL}/msg/newest_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"conversationIDs": [CONVERSATION_ID]}
    
    print(f"\n[*] Getting newest seq...")
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
    return data

def main():
    print("[*] Getting tokens...")
    admin_token = get_admin_token()
    user_token = get_user_token(admin_token, TARGET_USER_ID)
    
    if not user_token:
        print("[-] Failed to get user token")
        return
    
    print(f"[+] User token obtained")
    
    # 1. 获取会话详情
    conv_detail = get_conversation_detail(user_token, CONVERSATION_ID)
    
    # 2. 获取最新序列号
    newest_seq = get_newest_seq(user_token)
    
    # 3. 搜索消息
    search_result = search_messages(user_token, TARGET_USER_ID)
    
    # 4. 尝试用不同的方式拉取消息
    print(f"\n[*] Trying different message pulling methods...")
    
    # 方法1: 使用 pull_msg_by_seq
    url = f"{API_URL}/msg/pull_msg_by_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    
    # 尝试从 seq 1 开始拉取
    for begin_seq in [0, 1]:
        payload = {
            "userID": TARGET_USER_ID,
            "conversationID": CONVERSATION_ID,
            "beginSeq": begin_seq,
            "endSeq": begin_seq + 100,
            "num": 100
        }
        
        print(f"\n[*] Pulling messages from seq {begin_seq} to {begin_seq + 100}...")
        resp = requests.post(url, json=payload, headers=headers)
        data = resp.json()
        print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
        
        if data.get("data", {}).get("msgs"):
            print(f"[+] Found messages!")
            break

if __name__ == "__main__":
    main()
