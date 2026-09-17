import MarkdownIt from 'markdown-it';
import createDOMPurify from 'dompurify';
const DOMPurify = createDOMPurify(window);
import hljs from 'highlight.js/lib/common';
import {installMath, typesetMath} from './rich-content.js';
export {enhanceDiagrams} from './rich-content.js';
import { markSourceTokens, attachSourcePositions } from './position.js';
export { createPositionSync } from './position.js';
export { createSearch } from './search.js';
export { createWorkspace } from './workspace.js';

const md = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: false,
  highlight(code, language) {
    // Bound syntax highlighting work for very large code blocks; plain text stays readable.
    if (language !== 'mermaid' && code.length < 100000 && language && hljs.getLanguage(language)) {
      try { return hljs.highlight(code, { language, ignoreIllegals: true }).value; } catch { /* escaped fallback */ }
    }
    return '';
  }
});

installMath(md);

// Recognize a closed YAML metadata header only at the start of the document.
// Keep parser line numbers intact for reading/source alignment; never execute YAML.
md.block.ruler.before('hr', 'front_matter', (state, startLine, endLine, silent) => {
  if (startLine !== 0 || state.parentType !== 'root') return false;
  const line = n => state.src.slice(state.bMarks[n], state.eMarks[n]);
  if (!/^\uFEFF?---[ \t]*$/.test(line(0))) return false;
  let end = 1;
  while (end < endLine && !/^(?:---|\.\.\.)[ \t]*$/.test(line(end))) end++;
  if (end === endLine) return false;
  let first = 1;
  while (first < end && /^\s*(?:#.*)?$/.test(line(first))) first++;
  if (!/^(?:[\w.-]+|"[^"\n]+"|'[^'\n]+'):(?:\s|$)/.test(line(first))) return false;
  if (silent) return true;
  const token = state.push('front_matter', 'details', 0);
  token.block = true;
  token.map = [0, end + 1];
  token.content = state.src.slice(state.bMarks[1], state.bMarks[end]);
  state.line = end + 1;
  return true;
});
md.renderer.rules.front_matter = (tokens, idx) => {
  const token = tokens[idx];
  return `<details data-mv-position="${token.attrGet('data-mv-position')}"><summary>문서 정보 · YAML</summary><pre><code>${md.utils.escapeHtml(token.content)}</code></pre></details>\n`;
};

// These rules do not use renderToken, so carry their trusted block marker explicitly.
for (const name of ['fence', 'code_block', 'html_block']) {
  const original = md.renderer.rules[name];
  md.renderer.rules[name] = (tokens, idx, options, env, renderer) => {
    const html = original(tokens, idx, options, env, renderer);
    const id = tokens[idx].attrGet('data-mv-position');
    if (!id) return html;
    return name === 'html_block' ? `<div data-mv-position="${id}">${html}</div>`
      : html.replace('<pre', `<pre data-mv-position="${id}"`);
  };
}

// Recognize task markers on list-item inline tokens, including nested and loose lists.
// Source Markdown is never modified, and checkboxes are always disabled.
md.core.ruler.after('inline', 'readonly_tasks', (state) => {
  const tokens = state.tokens;
  for (let i = 2; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.type !== 'inline' || tokens[i - 1].type !== 'paragraph_open' ||
        tokens[i - 2].type !== 'list_item_open' || !/^\[[ xX]\](?:\s|$)/.test(token.content)) continue;
    const first = token.children?.[0];
    if (!first || first.type !== 'text' || !/^\[[ xX]\](?:\s|$)/.test(first.content)) continue;
    const checked = /^\[[xX]\]/.test(first.content);
    first.content = first.content.replace(/^\[[ xX]\]\s?/, '');
    const checkbox = new state.Token('html_inline', '', 0);
    checkbox.content = `<input type="checkbox" disabled aria-label="${checked ? 'Completed' : 'Not completed'}"${checked ? ' checked' : ''}> `;
    token.children.unshift(checkbox);
    tokens[i - 2].attrJoin('class', 'task-list-item');
  }
});

// Turn parser-generated table alignment into a restricted attribute before sanitation.
for (const name of ['th_open', 'td_open']) {
  md.renderer.rules[name] = (tokens, idx, options, env, renderer) => {
    const token = tokens[idx];
    const alignment = token.attrGet('style')?.match(/^text-align:(left|center|right)$/)?.[1];
    if (alignment) {
      token.attrs = token.attrs.filter(([key]) => key !== 'style');
      token.attrSet('align', alignment);
    }
    return renderer.renderToken(tokens, idx, options);
  };
}

const sanitizeOptions = {
  ALLOWED_TAGS: ['a', 'p', 'br', 'hr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'strong', 'em',
    's', 'del', 'blockquote', 'ul', 'ol', 'li', 'pre', 'code', 'table', 'thead', 'tbody',
    'tfoot', 'tr', 'th', 'td', 'img', 'input', 'span', 'div', 'details', 'summary', 'kbd',
    'sup', 'sub', 'dl', 'dt', 'dd', 'abbr', 'b', 'i'],
  ALLOWED_ATTR: ['href', 'src', 'alt', 'title', 'class', 'type', 'checked', 'disabled',
    'start', 'colspan', 'rowspan', 'align', 'open', 'aria-label', 'data-mv-position', 'data-mv-math'],
  ALLOW_DATA_ATTR: false,
  ALLOW_ARIA_ATTR: false,
  ALLOW_UNKNOWN_PROTOCOLS: false,
  RETURN_DOM_FRAGMENT: true
};

function documentURL(value, baseURL) {
  // Absolute, scheme-relative, backslash, and explicit-scheme paths never become local reads.
  if (!value || /^[\/\\]/.test(value) || /^[a-z][a-z0-9+.-]*:/i.test(value) || value.includes('\\')) return null;
  try {
    const url = new URL(value, baseURL);
    return url.href.startsWith(baseURL) ? url : null;
  } catch { return null; }
}

function imagePlaceholder(image, message) {
  const placeholder = document.createElement('span');
  placeholder.className = 'image-placeholder';
  placeholder.textContent = image.alt ? `${image.alt} — ${message}` : message;
  placeholder.setAttribute('role', 'note');
  image.replaceWith(placeholder);
}

function prepare(fragment, { baseURL, headingPrefix, imageExtensions, localMarkdownLinks }) {
  // Arbitrary document classes cannot hide content or impersonate application controls.
  for (const element of fragment.querySelectorAll('[class]')) {
    const permitted = [...element.classList].filter((name) =>
      /^(?:language-[a-z0-9_+-]+|hljs-[a-z0-9_-]+|task-list-item)$/.test(name));
    element.removeAttribute('class');
    if (permitted.length) element.className = permitted.join(' ');
  }
  for (const input of fragment.querySelectorAll('input')) {
    if (input.type !== 'checkbox') { input.remove(); continue; }
    input.disabled = true;
    input.tabIndex = -1;
  }
  for (const image of fragment.querySelectorAll('img')) {
    const src = image.getAttribute('src') || '';
    if (/^data:image\/(?:png|jpeg|gif|webp|bmp);base64,[a-z0-9+/=\s]+$/i.test(src)) continue;
    const local = documentURL(src, baseURL);
    if (!local || !imageExtensions.includes(local.pathname.split('.').pop().toLowerCase())) {
      imagePlaceholder(image, /^https?:|^\/\//i.test(src) ? 'Remote image blocked' : 'Image unavailable');
      continue;
    }
    image.src = local.href;
    image.addEventListener('error', () => imagePlaceholder(image, 'Image unavailable'), { once: true });
  }
  for (const link of fragment.querySelectorAll('a')) {
    const href = link.getAttribute('href') || '';
    if (href.startsWith('#')) continue;
    try {
      if (/^(?:https?:|mailto:)/i.test(href)) {
        const external = new URL(href);
        if (['https:', 'http:', 'mailto:'].includes(external.protocol)) {
          link.href = external.href;
          link.title ||= 'Open in your default app';
          continue;
        }
      }
      const local = documentURL(href, baseURL);
      if (localMarkdownLinks && local && /\.(?:md|markdown)$/i.test(local.pathname)) {
        link.href = local.href;
        continue;
      }
    } catch { /* Remove malformed links. */ }
    link.removeAttribute('href');
    link.title = 'This link is unavailable in the read-only viewer';
  }
  const ids = new Map();
  for (const heading of fragment.querySelectorAll('h1,h2,h3,h4,h5,h6')) {
    const base = heading.textContent.toLowerCase().trim()
      .replace(/[^\p{L}\p{N}\p{M}\s_-]/gu, '').replace(/\s/g, '-') || 'section';
    const count = ids.get(base) || 0;
    ids.set(base, count + 1);
    heading.id = `${headingPrefix}${base}${count ? `-${count}` : ''}`;
  }
  return fragment;
}

// Native hosts supply the local-document URL and supported raster formats.
// Parsing, sanitation, task lists, highlighting and anchors are shared unchanged.
export const apiVersion = 1;
export function render(markdown, options = {}) {
  const settings = {
    baseURL: 'mdviewer://document/', headingPrefix: 'heading-',
    imageExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'avif', 'svg'],
    localMarkdownLinks: true, ...options
  };
  const env = {}, tokens = md.parse(markdown, env);
  const positions = markSourceTokens(tokens);
  const fragment = prepare(DOMPurify.sanitize(md.renderer.render(tokens, md.options, env), sanitizeOptions), settings);
  attachSourcePositions(fragment, positions);
  typesetMath(fragment, env.math);
  return fragment;
}

export function showSource(element, markdown) {
  element.textContent = markdown;
}
