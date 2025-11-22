import requests
import time
import json

API_URL = "http://127.0.0.1:10002"
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

def send_test_message(user_token, from_user_id, to_user_id, text):
    """发送测试消息"""
    url = f"{API_URL}/msg/send_msg"
    headers = {"operationID": str(time.time()), "token": user_token}
    
    payload = {
        "sendMsg": {
            "sendID": from_user_id,
            "recvID": to_user_id,
            "groupID": "",
            "senderNickname": "测试用户",
            "senderFaceURL": "",
            "senderPlatformID": 1,
            "content": json.dumps({
                "text": text
            }),
            "contentType": 101,  # 101 = 文本消息
            "sessionType": 1,    # 1 = 单聊
            "isOnlineOnly": False,
            "notOfflinePush": False,
            "sendTime": int(time.time() * 1000),
            "createTime": int(time.time() * 1000),
            "offlinePushInfo": {
                "title": "新消息",
                "desc": text,
                "ex": "",
                "iOSPushSound": "default",
                "iOSBadgeCount": True
            }
        }
    }
    
    print(f"[*] Sending message from {from_user_id} to {to_user_id}...")
    print(f"[*] Message: {text}")
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    print(f"Response: {json.dumps(data, indent=2, ensure_ascii=False)}")
    
    if data.get("errCode") == 0:
        print("[+] Message sent successfully!")
        return True
    else:
        print(f"[-] Failed to send message: {data.get('errMsg')}")
        return False

def main():
    # 获取用户 7179594694 的 token
    admin_token = get_admin_token()
    user_token = get_user_token(admin_token, "7179594694")
    
    if not user_token:
        print("[-] Failed to get user token")
        return
    
    # 发送测试消息
    send_test_message(
        user_token=user_token,
        from_user_id="7179594694",
        to_user_id="4363667287",
        text="这是一条测试消息，用于验证消息获取功能。"
    )

if __name__ == "__main__":
    main()
