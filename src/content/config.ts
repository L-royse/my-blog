/**
 * Astro Content Collections 配置
 * 博客文章集合定义
 *
 * 注意：Collections schema 必须放在 src/content/config.* 中
 * （而不是 astro.config.mjs），这是 Astro 的规范
 */
import { defineCollection, z } from 'astro:content';

// 博客文章集合
const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
    cover: z.string().optional(),
  }),
});

export const collections = { blog };
