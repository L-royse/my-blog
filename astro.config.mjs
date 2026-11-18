import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
// 站点 URL —— 自建服务器部署在根路径，用实际域名
export default defineConfig({
  site: 'https://liu-royse.site',
  trailingSlash: 'ignore',

  vite: {
    plugins: [tailwindcss()],
  },

  integrations: [
    mdx(),
    sitemap(),
  ],

  // 静态生成模式（SSG），不需要 server adapter
  output: 'static',
});
