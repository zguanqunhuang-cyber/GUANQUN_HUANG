from pymongo import MongoClient
import time

# Configuration from mongodb.yml
# address: [ localhost:37017 ]
# database: openim_v3
# username: openIM
# password: openIM123

MONGO_URI = "mongodb://openIM:openIM123@localhost:37017/openim_v3?authSource=openim_v3"
DB_NAME = "openim_v3"
TARGET_USER_ID = "7179594694"

def get_mongo_messages(user_id):
    print(f"[*] Connecting to MongoDB at {MONGO_URI}...")
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=2000)
        # Force connection check
        client.server_info()
        print("[+] Connected to MongoDB.")
    except Exception as e:
        print(f"[-] Failed to connect to MongoDB: {e}")
        return []

    db = client[DB_NAME]
    
    # Collections in OpenIM v3 are often 'msg' or 'chat_logs'
    # Let's list collections to be sure
    collections = db.list_collection_names()
    print(f"[*] Collections found: {collections}")
    
    msg_col_name = None
    if "msg" in collections:
        msg_col_name = "msg"
    elif "chat_logs" in collections:
        msg_col_name = "chat_logs"
    
    if not msg_col_name:
        print("[-] Could not find a known message collection (msg or chat_logs).")
        return []

    print(f"[*] Querying collection '{msg_col_name}' for user {user_id}...")
    col = db[msg_col_name]
    
    # Query for messages where the user is sender OR receiver
    query = {
        "$or": [
            {"sendID": user_id},
            {"recvID": user_id}
        ]
    }
    
    # Sort by sendTime descending (assuming sendTime exists, or createTime)
    # We'll try 'sendTime' first, which is standard.
    try:
        cursor = col.find(query).sort("sendTime", -1).limit(20)
        messages = list(cursor)
        return messages
    except Exception as e:
        print(f"[-] Error querying messages: {e}")
        return []

def main():
    msgs = get_mongo_messages(TARGET_USER_ID)
    print(f"\n[+] Found {len(msgs)} messages for user {TARGET_USER_ID}:")
    for m in msgs:
        # Extract useful fields
        send_id = m.get("sendID")
        recv_id = m.get("recvID")
        content = m.get("content")
        seq = m.get("seq")
        print(f"  - [Seq:{seq}] {send_id} -> {recv_id}: {content[:50]}...")

if __name__ == "__main__":
    main()
