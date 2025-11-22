import requests
import time
import json

API_URL = "http://127.0.0.1:10002"
TARGET_USER_ID = "5847732961"
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

def get_conversations(user_token, user_id):
    url = f"{API_URL}/conversation/get_all_conversations"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"ownerUserID": user_id}
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    if data.get("errCode") == 0:
        return data.get("data", {}).get("conversations", [])
    return []

def get_conversations_max_seq(user_token, conv_ids):
    url = f"{API_URL}/msg/get_conversations_has_read_and_max_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {"conversationIDs": conv_ids}
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    if data.get("errCode") == 0:
        return data.get("data", {})
    return {}

def pull_messages_by_seqs(user_token, user_id, conv_id, begin_seq, end_seq):
    url = f"{API_URL}/msg/pull_msg_by_seqs"
    headers = {"operationID": str(time.time()), "token": user_token}
    payload = {
        "userID": user_id,
        "seqRanges": [{
            "conversationID": conv_id,
            "begin": begin_seq,
            "end": end_seq,
            "num": end_seq - begin_seq + 1
        }],
        "order": 0
    }
    resp = requests.post(url, json=payload, headers=headers)
    return resp.json()

def main():
    print("="*80)
    print(f"Fetching recent messages for user {TARGET_USER_ID}")
    print("="*80)

    admin_token = get_admin_token()
    if not admin_token:
        print("[-] Failed to obtain admin token")
        return
    user_token = get_user_token(admin_token, TARGET_USER_ID)
    if not user_token:
        print("[-] Failed to obtain user token")
        return
    conversations = get_conversations(user_token, TARGET_USER_ID)
    if not conversations:
        print("[!] No conversations found for this user")
        return
    conv_ids = [c.get("conversationID") for c in conversations]
    max_seq_data = get_conversations_max_seq(user_token, conv_ids)

    for conv in conversations:
        conv_id = conv.get("conversationID")
        seq_info = max_seq_data.get(conv_id, {})
        max_seq = seq_info.get("maxSeq", 0)
        if max_seq <= 0:
            # No seq info in Redis – skip (or you could fallback to MongoDB)
            continue
        # 拉取最近 20 条（或根据 max_seq 取更少）
        begin = max(1, max_seq - 19)
        result = pull_messages_by_seqs(user_token, TARGET_USER_ID, conv_id, begin, max_seq)
        if result.get("errCode") != 0:
            print(f"[-] Pull error for conv {conv_id}: {result.get('errMsg')}")
            continue
        msgs = result.get("data", {}).get("msgs", {}).get(conv_id, {}).get("Msgs", [])
        if not msgs:
            continue
        print(f"\nConversation: {conv_id} (last {len(msgs)} msgs)\n{'-'*60}")
        for m in msgs:
            sender = m.get("sendID")
            seq = m.get("seq")
            raw = m.get("content", "")
            try:
                content_obj = json.loads(raw)
                text = content_obj.get("content") or content_obj.get("text") or str(content_obj)
            except Exception:
                text = raw
            if isinstance(text, bytes):
                text = text.decode('utf-8', errors='ignore')
            print(f"[{seq}] {sender}: {text}")

if __name__ == "__main__":
    main()
