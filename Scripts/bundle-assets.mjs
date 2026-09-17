import { build } from 'esbuild';
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const out = resolve(root, 'macOS/Sources/MarkdownViewer/Resources/Web');
const shared = resolve(root, 'Shared/Renderer/Resources/Web');
await mkdir(shared, { recursive: true });
const coreBuild = await build({
  entryPoints: [resolve(root, 'Shared/Renderer/renderer.js')],
  outfile: resolve(shared, 'core.js'), bundle: true, minify: true,
  platform: 'browser', target: ['safari17', 'chrome120'], format: 'iife',
  metafile: true, globalName: 'MarkdownViewerCore', legalComments: 'inline', loader: {'.md':'text'}
});
await build({
  entryPoints: [resolve(root, 'macOS/WebSource/renderer.js')],
  outfile: resolve(out, 'viewer.js'), bundle: true, minify: true,
  platform: 'browser', target: ['safari17'], format: 'iife', legalComments: 'inline'
});
// Keep the complete upstream licenses for every bundled runtime dependency.
const packages = new Map();
for (const input of Object.keys(coreBuild.metafile.inputs)) {
  if (!input.includes('node_modules/')) continue;
  let base = dirname(resolve(root, input));
  while (base !== root && base !== dirname(base)) {
    try {
      const pkg = JSON.parse(await readFile(resolve(base, 'package.json'), 'utf8'));
      if (pkg.name && pkg.version) { packages.set(pkg.name + '@' + pkg.version, {base, pkg}); break; }
    } catch { /* walk to owning package */ }
    base = dirname(base);
  }
}
const manifest = [];
await mkdir(resolve(root, 'ThirdPartyLicenses'), { recursive: true });
for (const {base, pkg} of [...packages.values()].sort((a,b)=>a.pkg.name.localeCompare(b.pkg.name, 'en'))) {
  const filenames = (await readdir(base)).filter(name=>/^(?:licen[sc]e|copying)(?:[.-].*)?$/i.test(name)).sort();
  const licenses = [];
  for (const filename of filenames) {
    try { licenses.push(filename + '\n' + await readFile(resolve(base,filename),'utf8')); } catch { /* directories */ }
  }
  if (!licenses.length) throw new Error(`Missing license: ${pkg.name}`);
  await writeFile(resolve(root, 'ThirdPartyLicenses', `${pkg.name.replaceAll('/', '__')}@${pkg.version}.txt`), `${pkg.name} ${pkg.version}\n\n${licenses.join('\n\n')}`);
  manifest.push({ name:pkg.name, version: pkg.version, license: pkg.license });
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
