---
title: 你好，世界！
description: 这是第一篇示例文章，展示 Markdown 的常见语法和博客样式。
pubDate: 2026-11-13
tags: [欢迎, hello-world]
draft: false
---

## 欢迎 🎉

这是你的博客的第一篇文章！以后就可以在这里记录学习、思考和项目了。

> 💡 **小技巧**：所有文章都是 Markdown 文件，直接在 `src/content/blog/` 目录下新建 `.md` 即可，写好就能被自动识别。

## 目录结构

```
src/content/blog/
├── hello-world.md        ← 这篇示例文章
└── （以后你写的文章都放这里）
```

## Frontmatter 说明

每篇文章的头部需要这样的元信息：

```yaml
---
title: 文章标题
description: 简短描述（显示在卡片和 SEO 里）
pubDate: 2026-11-13       # 发布日期
tags: [标签1, 标签2]      # 可选
draft: false              # true = 不发布
---
```

## 写完推上去

```bash
git add .
git commit -m "post: my first blog post"
git push
```

推上去后 GitHub Actions 会自动构建部署，几分钟后就能在你的域名看到了 ✨
