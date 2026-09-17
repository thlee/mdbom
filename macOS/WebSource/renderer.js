const reader = document.getElementById('content');
const shell = document.getElementById('reader');
const source = document.getElementById('sourcecontent');
const welcome = document.getElementById('welcome');
const post = message => window.webkit?.messageHandlers?.viewer?.postMessage(message);
let view = 'reading';
let filename = '';
const workspace = window.MarkdownViewerCore.createWorkspace(reader, source, post);
const positionSync = workspace.positions;
let presentation = {};
const search = window.MarkdownViewerCore.createSearch(workspace, reader, source);
const clearFind = () => search.clear();
const findText = (query, backwards = false) => search.find(query, backwards);

function setView(next, remember = true) {
  clearFind();
  workspace.setView(next, remember);
  view = next === 'source' ? 'source' : 'reading';
}

window.viewer = Object.freeze({
  findText,
  workspace,
  configure(options) {
    presentation = {...presentation, ...options};
    options = presentation;
    document.documentElement.dataset.theme = options.theme;
    for (const mode of ['reading', 'source']) {
      const width = options[mode];
      if (Number.isInteger(width) && (width === 0 || (width >= 600 && width <= 1800)))
        document.documentElement.style.setProperty(`--${mode}-width`, width === 0 ? 'none' : `${width}px`);
    }
    workspace.configure(options, view);
    if (options.view !== view) setView(options.view);
  },
  async render(markdown, name, preserveScroll = false) {
    const remember = preserveScroll && filename === name;
    const position = remember ? workspace.captureViewport() : null;
    filename = name;
    const opened = Boolean(name);
    shell.hidden = !opened;
    welcome.hidden = opened;
    document.title = name ? name + ' — 엠디봄' : '엠디봄';
    reader.replaceChildren(window.MarkdownViewerCore.render(markdown));
    window.MarkdownViewerCore.showSource(source, markdown);
    await window.MarkdownViewerCore.enhanceDiagrams(reader);
    positionSync.load();
    document.getElementById('documentname').textContent = name;
    if (opened && !markdown.trim()) {
      const empty = document.createElement('p'); empty.className = 'empty-document';
      empty.textContent = 'This document is empty.'; reader.append(empty);
    }
    setView(view, false);
    workspace.configure(presentation, view);
    if (remember) workspace.restoreViewport(position);
    return { opened, characters: markdown.length };
  }
});

document.getElementById('openfile').addEventListener('click', event => {
  if (event.isTrusted) post({ action: 'open' });
});
reader.addEventListener('click', event => {
  const link = event.target.closest('a[href]');
  if (!link) return;
  event.preventDefault();
  const href = link.getAttribute('href');
  if (href.startsWith('#')) {
    try { document.getElementById(`heading-${decodeURIComponent(href.slice(1))}`)?.scrollIntoView(); } catch {}
  } else if (event.isTrusted) post({ action: 'link', href });
});
window.addEventListener('dragover', event => event.preventDefault());
window.addEventListener('drop', event => event.preventDefault());
