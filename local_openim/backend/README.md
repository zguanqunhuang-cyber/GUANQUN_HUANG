# OpenIM Python 后端获取历史消息指南

## 概述

本文档说明如何在 Python 后端通过 **REST API** 方式获取 OpenIM Server 的历史消息，适用于本地部署和云端部署。

---

## 方案一：REST API（推荐 ⭐⭐⭐⭐⭐）

### 优点
- ✅ **官方标准**：使用 OpenIM 提供的标准 HTTP 接口
- ✅ **云端兼容**：本地和云端部署都适用，无需修改代码
- ✅ **安全可靠**：通过 Token 认证，符合安全最佳实践
- ✅ **易于维护**：不依赖数据库结构，OpenIM 升级不影响代码

### 核心步骤

#### 1. 获取 Admin Token
```python
import requests

API_URL = "http://127.0.0.1:10002"  # 本地部署
# API_URL = "https://your-domain.com/api"  # 云端部署

def get_admin_token():
    url = f"{API_URL}/auth/get_admin_token"
    headers = {"operationID": str(time.time())}
    payload = {
        "secret": "openIM123",  # 从 config/share.yml 获取
        "userID": "imAdmin"     # 从 config/share.yml 的 imAdminUserID 获取
    }
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("token")
    return None
```

#### 2. 获取目标用户的 Token
```python
def get_user_token(admin_token, user_id):
    url = f"{API_URL}/auth/get_user_token"
    headers = {
        "operationID": str(time.time()),
        "token": admin_token  # 使用 Admin Token
    }
    payload = {
        "secret": "openIM123",
        "platformID": 1,  # 1=iOS, 2=Android, 5=Web
        "userID": user_id
    }
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("token")
    return None
```

#### 3. 获取用户的会话列表
```python
def get_conversations(user_token, user_id):
    url = f"{API_URL}/conversation/get_all_conversations"
    headers = {
        "operationID": str(time.time()),
        "token": user_token
    }
    payload = {"ownerUserID": user_id}
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("conversations", [])
    return []
```

#### 4. 获取会话的历史消息
```python
def get_history_messages(user_token, user_id, conversation_id):
    # 先获取最大序列号
    max_seq_url = f"{API_URL}/msg/get_max_seq"
    headers = {"operationID": str(time.time()), "token": user_token}
    
    resp = requests.post(max_seq_url, json={"conversationID": conversation_id}, headers=headers)
    max_seq = resp.json().get("data", {}).get("maxSeq", 0)
    
    # 拉取消息
    url = f"{API_URL}/msg/pull_msg_by_seq"
    payload = {
        "userID": user_id,
        "conversationID": conversation_id,
        "beginSeq": max(0, max_seq - 50),  # 拉取最近 50 条
        "endSeq": max_seq,
        "num": 50
    }
    
    resp = requests.post(url, json=payload, headers=headers)
    data = resp.json()
    
    if data.get("errCode") == 0:
        return data.get("data", {}).get("msgs", [])
    return []
```

### 完整示例
参见 `experiment_history.py`

---

## 方案二：直接读取 MongoDB（仅限本地/私有云）

### 优点
- ✅ **灵活查询**：可以进行复杂的数据分析和聚合
- ✅ **性能高**：直接查询数据库，无需经过 API 层
- ✅ **批量操作**：适合数据迁移、备份等场景

### 缺点
- ❌ **不适合公有云**：云端 MongoDB 通常有访问限制
- ❌ **维护成本高**：数据库结构变化需要修改代码
- ❌ **安全风险**：绕过业务逻辑层，可能导致数据不一致

### 实现方式
```python
from pymongo import MongoClient

# 从 config/mongodb.yml 获取配置
MONGO_URI = "mongodb://openIM:openIM123@localhost:37017/openim_v3?authSource=openim_v3"

def get_messages_from_db(user_id):
    client = MongoClient(MONGO_URI)
    db = client["openim_v3"]
    collection = db["msg"]
    
    query = {
        "$or": [
            {"sendID": user_id},
            {"recvID": user_id}
        ]
    }
    
    messages = collection.find(query).sort("sendTime", -1).limit(50)
    return list(messages)
```

---

## 上云后的最佳实践

### 1. 使用 REST API（强烈推荐）

**为什么？**
- 云端部署通常会限制直接访问数据库
- REST API 可以通过负载均衡、CDN 等方式优化
- 更容易实现微服务架构

**配置示例：**
```python
# 本地开发
API_URL = "http://127.0.0.1:10002"

# 云端生产环境
API_URL = "https://api.yourdomain.com"

# 使用环境变量
import os
API_URL = os.getenv("OPENIM_API_URL", "http://127.0.0.1:10002")
SECRET = os.getenv("OPENIM_SECRET", "openIM123")
```

### 2. 如果必须使用数据库

**方案 A：VPN/专线连接**
- 通过 VPN 或云专线连接到云端 MongoDB
- 适合私有云或混合云部署

**方案 B：MongoDB Atlas/云数据库**
- 使用云厂商提供的 MongoDB 服务
- 配置白名单 IP 访问
- 使用 SSL/TLS 加密连接

**方案 C：数据同步**
- 定期将云端数据同步到本地分析库
- 使用 MongoDB Change Streams 实时同步
- 适合数据分析和报表场景

### 3. 混合方案

```python
class OpenIMClient:
    def __init__(self, use_api=True):
        self.use_api = use_api
        
    def get_messages(self, user_id):
        if self.use_api:
            return self._get_messages_via_api(user_id)
        else:
            return self._get_messages_via_db(user_id)
    
    def _get_messages_via_api(self, user_id):
        # REST API 实现
        pass
    
    def _get_messages_via_db(self, user_id):
        # MongoDB 直连实现
        pass

# 本地开发使用数据库
client = OpenIMClient(use_api=False)

# 生产环境使用 API
client = OpenIMClient(use_api=True)
```

---

## 配置文件说明

### 关键配置位置

1. **Secret 和 Admin ID**
   - 文件：`config/share.yml`
   - 字段：`secret`, `imAdminUserID`

2. **API 端口**
   - 文件：`config/openim-api.yml`
   - 字段：`api.ports`（默认 10002）

3. **MongoDB 连接**
   - 文件：`config/mongodb.yml`
   - 字段：`address`, `database`, `username`, `password`

---

## 常见问题

### Q1: 获取 Token 时返回 `errCode: 1001 ArgsError`
**原因：** 参数错误或端点路径错误

**解决：**
- 确认使用 `/auth/get_admin_token` 而不是 `/auth/user_token`
- 检查 `secret` 和 `userID` 是否与配置文件一致

### Q2: 消息列表为空
**原因：** 
- 会话确实没有消息
- Seq 范围不正确

**解决：**
- 先调用 `/msg/get_max_seq` 获取最大序列号
- 确保 `beginSeq` 和 `endSeq` 在有效范围内

### Q3: 上云后如何保证安全？
**建议：**
- 使用 HTTPS 加密传输
- 定期轮换 Secret
- 限制 Admin Token 的使用范围
- 使用 API Gateway 进行访问控制

---

## 总结

| 场景 | 推荐方案 | 理由 |
|------|---------|------|
| **生产环境（云端）** | REST API | 标准、安全、易维护 |
| **本地开发/调试** | REST API 或 MongoDB | 灵活选择 |
| **数据分析/报表** | MongoDB（只读副本） | 性能好，不影响主库 |
| **数据迁移** | MongoDB | 批量操作效率高 |

**最佳实践：优先使用 REST API，只在特殊场景下使用 MongoDB 直连。**
