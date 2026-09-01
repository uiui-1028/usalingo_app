// docs/legal/published/*.md を public/*.html へ変換する。
// 正本は Markdown 側だけに置く。ここでは文章を書かず、変換だけを行う。
import { readFile, writeFile, mkdir, copyFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { marked } from "marked";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const sourceDir = path.join(__dirname, "..", "..", "docs", "legal", "published");
const outDir = path.join(__dirname, "public");

// slug: 出力パス（cleanUrls で /terms のように開く） / title: ナビ表示名
const pages = [
  { file: "terms-of-service.md", slug: "terms", title: "利用規約" },
  { file: "privacy-policy.md", slug: "privacy", title: "プライバシーポリシー" },
  { file: "credits.md", slug: "credits", title: "クレジット" },
];

const slugByFile = new Map(pages.map((p) => [p.file, p.slug]));

function rewriteLinks(markdown) {
  // 既知の3文書への相対リンクは公開パスへ、それ以外の .md リンクは
  // 公開サイトの外を指すため、リンクを外してテキストだけ残す。
  return markdown.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (match, text, href) => {
    const cleanHref = href.split("#")[0];
    const slug = slugByFile.get(cleanHref);
    if (slug) {
      return `[${text}](/${slug})`;
    }
    if (cleanHref.endsWith(".md")) {
      return text;
    }
    return match;
  });
}

function stripAlertMarkers(markdown) {
  // GitHub の "> [!NOTE]" 記法をそのまま出すと読みにくいので、
  // マーカーだけ取り除き、通常の引用として表示する。
  return markdown.replace(/^> \[!NOTE\]\n/gm, "");
}

function page({ title, bodyHtml, nav }) {
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} | Usalingo</title>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="site-header">
  <nav>${nav}</nav>
</header>
<main>
${bodyHtml}
</main>
</body>
</html>
`;
}

async function main() {
  await mkdir(outDir, { recursive: true });

  const nav = pages
    .map((p) => `<a href="/${p.slug}">${p.title}</a>`)
    .join(" / ");

  for (const p of pages) {
    const raw = await readFile(path.join(sourceDir, p.file), "utf8");
    const rewritten = rewriteLinks(stripAlertMarkers(raw));
    const bodyHtml = marked.parse(rewritten);
    const html = page({ title: p.title, bodyHtml, nav });
    await writeFile(path.join(outDir, `${p.slug}.html`), html, "utf8");
  }

  const indexHtml = page({
    title: "法務文書",
    nav,
    bodyHtml: `<h1>Usalingo 法務文書</h1>\n<ul>\n${pages
      .map((p) => `<li><a href="/${p.slug}">${p.title}</a></li>`)
      .join("\n")}\n</ul>`,
  });
  await writeFile(path.join(outDir, "index.html"), indexHtml, "utf8");

  await copyFile(path.join(__dirname, "style.css"), path.join(outDir, "style.css"));

  console.log(`generated ${pages.length + 1} pages into ${outDir}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
