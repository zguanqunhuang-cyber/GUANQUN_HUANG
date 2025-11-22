# Vercel 部署配置说明

## 已完成的步骤 ✅

1. ✅ 项目已成功部署到 Vercel
2. ✅ 域名 `guanqunhuang.com` 已添加到项目
3. ✅ 自动 HTTPS 配置（Vercel 会自动配置 SSL 证书）

## 项目信息

- **项目名称**: guanqunhuang-viewer
- **默认 URL**: https://guanqunhuang-viewer.vercel.app
- **自定义域名**: guanqunhuang.com
- **框架**: Vite + React

## DNS 配置步骤（在 GoDaddy 完成）

### 登录 GoDaddy

1. 访问 [GoDaddy.com](https://www.godaddy.com)
2. 登录你的账户
3. 进入 "我的产品" (My Products)
4. 找到域名 `guanqunhuang.com`，点击 "DNS" 按钮

### 配置 DNS 记录

#### 选项 1：A 记录配置（推荐）

添加以下记录：

**主域名 A 记录：**
- **类型**: A
- **名称**: @
- **值/指向**: 76.76.21.21
- **TTL**: 600 秒（默认即可）

**www 子域名 CNAME 记录：**
- **类型**: CNAME
- **名称**: www
- **值/指向**: cname.vercel-dns.com
- **TTL**: 600 秒（默认即可）

#### 选项 2：仅使用 CNAME（如果 GoDaddy 支持根域名 CNAME）

- **类型**: CNAME
- **名称**: @
- **值/指向**: cname.vercel-dns.com
- **TTL**: 600 秒

### 删除冲突的记录

在添加新记录之前，请删除所有指向 `guanqunhuang.com` 的现有 A 记录或 CNAME 记录，避免冲突。

## 验证配置

### 1. 检查 DNS 传播

配置完成后，DNS 记录需要一些时间传播（通常 5-30 分钟，最多可能需要 48 小时）。

使用以下工具检查 DNS 传播状态：
- https://dnschecker.org
- https://www.whatsmydns.net

### 2. 检查 Vercel 域名状态

在终端运行：
```bash
vercel domains inspect guanqunhuang.com
```

### 3. 访问网站

DNS 传播完成后，访问：
- https://guanqunhuang.com
- https://www.guanqunhuang.com

## SSL 证书

Vercel 会在 DNS 记录正确配置后，自动为你的域名颁发免费的 SSL 证书（Let's Encrypt）。这个过程通常在几分钟内完成。

## 常见问题

### Q: DNS 配置后多久生效？
A: 通常 5-30 分钟，最长可能需要 48 小时。

### Q: 如何查看部署日志？
A: 运行 `vercel inspect --logs`

### Q: 如何重新部署？
A: 运行 `vercel --prod` 或者在 Vercel Dashboard 中点击 "Redeploy"

### Q: 域名显示 "Vercel Not Found"
A: 检查：
1. DNS 记录是否正确配置
2. 域名是否已在 Vercel 项目中添加
3. DNS 是否已完全传播

## 更新部署

每次代码更改后，重新部署：

```bash
# 开发环境
vercel

# 生产环境
vercel --prod
```

或者连接 GitHub 仓库，实现自动部署。

## 有用的命令

```bash
# 查看所有部署
vercel list

# 查看域名列表
vercel domains list

# 查看项目信息
vercel project ls

# 删除域名
vercel domains remove guanqunhuang.com

# 查看部署日志
vercel logs
```

## 下一步

- [ ] 在 GoDaddy 配置 DNS 记录
- [ ] 等待 DNS 传播
- [ ] 验证网站可以通过 guanqunhuang.com 访问
- [ ] 配置 GitHub 自动部署（可选）

## 支持

如有问题，请访问：
- Vercel 文档: https://vercel.com/docs
- Vercel 支持: https://vercel.com/support
