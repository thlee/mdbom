import { build } from 'esbuild';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = resolve(root, 'macOS/Sources/MarkdownViewer/Resources/Web');
const shared = resolve(root, 'Shared/Renderer/Resources/Web');
await mkdir(shared, { recursive: true });
await build({
  entryPoints: [resolve(root, 'Shared/Renderer/renderer.js')],
  outfile: resolve(shared, 'core.js'), bundle: true, minify: true,
  platform: 'browser', target: ['safari17', 'chrome120'], format: 'iife',
  globalName: 'MarkdownViewerCore', legalComments: 'inline', loader: {'.md':'text'}
});
await build({
  entryPoints: [resolve(root, 'macOS/WebSource/renderer.js')],
  outfile: resolve(out, 'viewer.js'), bundle: true, minify: true,
  platform: 'browser', target: ['safari17'], format: 'iife', legalComments: 'inline'
});
// Keep the complete upstream licenses for every bundled runtime dependency.
const names = ['markdown-it', 'dompurify', 'highlight.js', 'argparse', 'entities', 'linkify-it', 'mdurl', 'punycode.js', 'uc.micro'];
const manifest = [];
await mkdir(resolve(root, 'ThirdPartyLicenses'), { recursive: true });
for (const name of names) {
  const base = resolve(root, 'node_modules', name);
  const pkg = JSON.parse(await readFile(resolve(base, 'package.json'), 'utf8'));
  let license;
  for (const filename of ['LICENSE', 'LICENSE.txt', 'LICENSE.md', 'LICENSE-MIT.txt']) {
    try { license = await readFile(resolve(base, filename), 'utf8'); break; } catch { /* next */ }
  }
  if (!license) throw new Error(`Missing license: ${name}`);
  await writeFile(resolve(root, 'ThirdPartyLicenses', `${name}.txt`), `${name} ${pkg.version}\n\n${license}`);
  manifest.push({ name, version: pkg.version, license: pkg.license });
}
const bytes = await readFile(resolve(shared, 'core.js'));
const cssBytes = await readFile(resolve(shared, 'markdown.css'));
const adapter = await readFile(resolve(out, 'viewer.js'));
const presentation = await readFile(resolve(shared, 'presentation.css'));
const ui = await readFile(resolve(shared, 'interface.json'));

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
await writeFile(resolve(out, 'dependencies.json'), JSON.stringify({
  generatedBy: 'npm run bundle', packages: manifest,
  viewerJS_SHA256: hash(adapter), sharedCoreJS_SHA256: hash(bytes), sharedMarkdownCSS_SHA256: hash(cssBytes), presentationCSS_SHA256: hash(presentation), interfaceJSON_SHA256: hash(ui)
}, null, 2) + '\n');
console.log(`Bundled offline renderer: ${(bytes.length / 1024).toFixed(0)} KB`);
await writeFile(resolve(shared, 'dependencies.json'), JSON.stringify({
  generatedBy: 'npm run bundle', packages: manifest, coreJS_SHA256: hash(bytes), markdownCSS_SHA256: hash(cssBytes), presentationCSS_SHA256: hash(presentation), interfaceJSON_SHA256: hash(ui)
}, null, 2) + '\n');
