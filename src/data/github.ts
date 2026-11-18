/**
 * GitHub 数据获取模块
 * 构建时从 GitHub REST API 拉取 L-royse 的公开数据
 * 不需要 Personal Access Token（公开接口 rate limit 足够）
 */

export interface GithubRepo {
  id: number;
  name: string;
  full_name: string;
  html_url: string;
  description: string | null;
  language: string | null;
  stargazers_count: number;
  forks_count: number;
  watchers_count: number;
  topics: string[];
  updated_at: string;
  created_at: string;
  fork: boolean;
  archived: boolean;
}

export interface GithubUser {
  login: string;
  avatar_url: string;
  name: string | null;
  bio: string | null;
  company: string | null;
  location: string | null;
  blog: string;
  public_repos: number;
  followers: number;
  following: number;
  html_url: string;
}

const GITHUB_USERNAME = 'L-royse';
const GITHUB_API = 'https://api.github.com';

/** 带超时的 fetch */
async function fetchWithTimeout(url: string, options: RequestInit = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    return res;
  } finally {
    clearTimeout(timeout);
  }
}

/** 获取用户基础信息 */
export async function fetchUser(): Promise<GithubUser | null> {
  try {
    const res = await fetchWithTimeout(`${GITHUB_API}/users/${GITHUB_USERNAME}`);
    if (!res.ok) return null;
    const data = await res.json();
    return {
      login: data.login,
      avatar_url: data.avatar_url,
      name: data.name,
      bio: data.bio,
      company: data.company,
      location: data.location,
      blog: data.blog || '',
      public_repos: data.public_repos,
      followers: data.followers,
      following: data.following,
      html_url: data.html_url,
    };
  } catch {
    return null;
  }
}

/** 获取公开 Repo 列表 */
export async function fetchRepos(): Promise<GithubRepo[]> {
  try {
    const res = await fetchWithTimeout(
      `${GITHUB_API}/users/${GITHUB_USERNAME}/repos?sort=updated&per_page=30&type=owner`
    );
    if (!res.ok) return [];
    const data = await res.json();
    return data
      .filter((r: any) => !r.fork) // 过滤掉 fork 的
      .map((r: any) => ({
        id: r.id,
        name: r.name,
        full_name: r.full_name,
        html_url: r.html_url,
        description: r.description,
        language: r.language,
        stargazers_count: r.stargazers_count,
        forks_count: r.forks_count,
        watchers_count: r.watchers_count,
        topics: r.topics || [],
        updated_at: r.updated_at,
        created_at: r.created_at,
        fork: r.fork,
        archived: r.archived,
      }));
  } catch {
    return [];
  }
}

/** 聚合语言统计 */
export function aggregateLanguages(repos: GithubRepo[]): Record<string, number> {
  const map: Record<string, number> = {};
  repos.forEach((r) => {
    if (r.language) {
      map[r.language] = (map[r.language] || 0) + 1;
    }
  });
  return map;
}

/** 语言 → 颜色映射 */
export const LANGUAGE_COLORS: Record<string, string> = {
  JavaScript: '#f7df1e',
  TypeScript: '#3178d9',
  Python: '#3670a5',
  Java: '#f88f23',
  Vue: '#42b883',
  HTML: '#e34c26',
  CSS: '#1d65f1',
  SCSS: '#cd6799',
  Shell: '#89e051',
  Go: '#00add8',
  Rust: '#dea584',
  C: '#555555',
  'C++': '#f34b7d',
  CSharp: '#178600',
  Swift: '#f05138',
  Kotlin: '#a97bff',
  Ruby: '#cc342d',
  PHP: '#4f5d95',
  Astro: '#bc52ee',
  Svelte: '#ff3e00',
  Other: '#71717a',
};

/** 语言 → CSS tag 类名 */
export function getLanguageTagClass(lang: string | null): string {
  if (!lang) return 'tag-default';
  const key = lang.toLowerCase();
  if (key.includes('javascript') && !key.includes('typescript')) return 'tag-js';
  if (key.includes('typescript')) return 'tag-ts';
  if (key.includes('python')) return 'tag-py';
  if (key.includes('vue')) return 'tag-vue';
  if (key.includes('react')) return 'tag-react';
  if (key === 'html') return 'tag-html';
  if (key === 'css') return 'tag-css';
  if (key.includes('java') && !key.includes('script')) return 'tag-java';
  return 'tag-default';
}
