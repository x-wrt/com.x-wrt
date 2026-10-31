# 教程配图来源

本目录图片供 [中文图文教程](../../TUTORIAL.zh-CN.md)使用，随文档一起保存，无需从第三方服务器加载图片。教程中可以点击图片查看原图。

## 本项目绘制的示意图

| 文件 | 内容 |
| --- | --- |
| [setup-flow.svg](setup-flow.svg) | 从购买域名到远程验证的八步操作路线 |
| [dns-setup.svg](dns-setup.svg) | 从 Cloudflare 复制 NS 并填回注册商的操作关系 |

这两张图片是本教程绘制的关系示意图，保留 SVG 源文件便于更新，不代表服务商的真实控制台界面。

## 服务商官方截图

以下原图来自公开的官方文档或博客，版权归对应作者或服务商所有。界面及价格仅作操作位置示例，以当前控制台为准。

| 文件 | 来源页面 | 原图 |
| --- | --- | --- |
| [tencent-domain-search.png](tencent-domain-search.png) | [腾讯云：单个域名注册](https://cloud.tencent.com/document/product/242/9595) | [原图](https://qcloudimg.tencent-cloud.cn/image/document/35344dfbcd4488188cb260046fbfeeb7.png) |
| [tencent-nameservers.png](tencent-nameservers.png) | [腾讯云：修改 DNS 服务器](https://cloud.tencent.com/document/product/242/62106) | [原图](https://qcloudimg.tencent-cloud.cn/image/document/f955b3f3b6269adde9a8ba3bae6f57ef.png) |
| [cloudflare-account-tokens.png](cloudflare-account-tokens.png) | [Cloudflare：Account Owned Tokens](https://blog.cloudflare.com/account-owned-tokens-automated-actions-zaraz/)（2024-11-14） | [原图](https://blog.cloudflare.com/_emdash/api/media/file/01KW44S9VZD7W4BHQZMD1KKZNA.png) |

腾讯云截图中的名称与价格遮盖是原图已有的内容。NS 截图默认选中 DNSPod，教程明确说明应切换至“使用非腾讯云 DNS”。Cloudflare 截图用于展示账户级令牌页面与创建入口，图中已有令牌的权限并非本插件的权限示例。

## 本插件实机截图

| 文件 | 内容 |
| --- | --- |
| [xwrt-token-guide.png](xwrt-token-guide.png) | 展开的 Token 创建指引、官方链接和三项权限 |
| [xwrt-password-warning.png](xwrt-password-warning.png) | 公开访问风险与 Web 管理密码设置入口 |
| [xwrt-settings.png](xwrt-settings.png) | Token、访问域名与保存部署操作 |
| [xwrt-connected.png](xwrt-connected.png) | 真实连接成功及 HTTPS 验证通过的状态 |
| [xwrt-public-login.png](xwrt-public-login.png) | 通过公网 HTTPS 域名访问的路由器登录页 |

实机截图日期为 2026-10-31，使用中文界面。为避免公开测试设备的访问域名，截图前仅在浏览器显示层将域名替换为 `router.example.com`，并清空登录页的用户名；没有更改设备配置或将示例域名实际部署。截图没有包含 API Token、隧道凭据、密码或会话 Cookie。

“隧道配置”截图来自 Token 已保存的设备，输入框本来就为空。教程明确区分了首次填写 Token 与后续留空保留 Token 的情况。
