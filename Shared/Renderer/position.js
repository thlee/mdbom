// Positions belong to parser-created elements, never to attributes supplied by a document.
const blocks = new WeakMap();
const marker = 'data-mv-position';

export function markSourceTokens(tokens) {
  const prefix = Array.from(crypto.getRandomValues(new Uint32Array(4)), n => n.toString(16)).join('-');
  const entries = new Map();
  for (const token of tokens) {
    if (!token.map || token.hidden || !['paragraph_open', 'heading_open', 'list_item_open',
      'tr_open', 'fence', 'code_block', 'hr', 'html_block', 'front_matter'].includes(token.type)) continue;
    const id = `${prefix}-${entries.size}`;
    entries.set(id, { firstLine: token.map[0], endLine: token.map[1], fence: token.type === 'fence', frontMatter: token.type === 'front_matter' });
    token.attrSet(marker, id);
  }
  return entries;
}

export function attachSourcePositions(fragment, entries) {
  for (const element of fragment.querySelectorAll(`[${marker}]`)) {
    const id = element.getAttribute(marker), entry = entries.get(id);
    element.removeAttribute(marker);
    if (entry) {
      blocks.set(element, entry); entries.delete(id);
      if (entry.frontMatter) element.classList.add('front-matter');
    }
  }
}

function textIndex(root) {
  const nodes = []; let text = '', node;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while ((node = walker.nextNode())) {
    if (!node.length) continue;
    if (/^\s*$/.test(node.data) && ['TABLE', 'THEAD', 'TBODY', 'TFOOT', 'TR', 'UL', 'OL'].includes(node.parentElement.tagName)) continue;
    nodes.push({ node, start: text.length, end: text.length + node.length });
    text += node.data;
  }
  return { nodes, text };
}

function characterRect(index, offset) {
  offset = Math.max(0, Math.min(index.text.length - 1, offset));
  // Newline fragments can have no glyph at all. Use the following character's
  // geometry during the binary search, rather than treating a missing rect as below it.
  while (offset < index.text.length - 1 && /[\r\n]/.test(index.text[offset])) offset++;
  let lo = 0, hi = index.nodes.length - 1;
  while (lo < hi) { const mid = (lo + hi) >>> 1; if (index.nodes[mid].end <= offset) lo = mid + 1; else hi = mid; }
  const item = index.nodes[lo];
  if (!item) return null;
  const range = document.createRange();
  range.setStart(item.node, offset - item.start);
  range.setEnd(item.node, offset - item.start + 1);
  const rect = [...range.getClientRects()].find(rect => rect.height > 0 && rect.width > 0);
  if (rect) return rect;
  // A space collapsed at a wrapped line boundary also has no painted rectangle.
  if (/\s/.test(index.text[offset])) {
    let next = offset + 1;
    while (next < index.text.length && /\s/.test(index.text[next])) next++;
    if (next < index.text.length) return characterRect(index, next);
  }
  return null;
}

// Use laid-out characters, including wrapped source lines and highlighted code spans.
function topCharacter(index, top = 0) {
  let lo = 0, hi = index.text.length - 1;
  while (lo < hi) {
    const mid = (lo + hi) >>> 1, rect = characterRect(index, mid);
    if (!rect || rect.bottom <= top + 1) lo = mid + 1; else hi = mid;
  }
  // WebKit can place a CR/LF range on the following visual line. Anchor its
  // first actual character, so returning to highlighted code cannot move up a line.
  while (lo < index.text.length - 1 && /[\r\n]/.test(index.text[lo])) lo++;
  return lo;
}

// Match visible text runs within the parser's source block. Delimiters, link
// destinations and indentation have source characters but no rendered glyph.
// Unmatched syntax uses the nearest matched character in the same block.
function alignText(text, raw, start) {
  const offsets = new Uint32Array(text.length);
  let cursor = 0, i = 0, searches = 0;
  while (i < text.length) {
    if (++searches > 4096) {
      const remaining = text.length - i, begin = i;
      for (; i < text.length; i++) offsets[i] = start + cursor + Math.floor((raw.length - cursor) * (i - begin) / remaining);
      break;
    }
    let found = -1;
    const nearby = raw.slice(cursor, cursor + 8192);
    for (const length of [32, 16, 8, 4, 1]) {
      const local = nearby.indexOf(text.slice(i, i + Math.min(length, text.length - i)));
      found = local < 0 ? -1 : cursor + local;
      if (found >= 0) break;
    }
    if (found < 0) { offsets[i++] = start + Math.min(cursor, Math.max(0, raw.length - 1)); continue; }
    cursor = found;
    do { offsets[i++] = start + cursor++; } while (i < text.length && text[i] === raw[cursor]);
  }
  return offsets;
}

export function createPositionSync(reading, source, scrollRoot = () => window) {
  const root = view => scrollRoot(view);
  const y = view => root(view) === window ? window.scrollY : root(view).scrollTop;
  const top = view => root(view) === window ? 0 : root(view).getBoundingClientRect().top;
  const move = (view, value) => root(view).scrollTo(0, value);
  let entries = [], sourceIndex = { nodes: [], text: '' }, restored = null;
  const layout = view => `${innerWidth}/${innerHeight}/${document.documentElement.scrollHeight}/${(view === 'source' ? source : reading).getBoundingClientRect().width}`;
  function load() {
    restored = null;
    sourceIndex = textIndex(source);
    const lineStarts = [0];
    for (const match of sourceIndex.text.matchAll(/\r\n|\r|\n/g)) lineStarts.push(match.index + match[0].length);
    const lineOffset = n => lineStarts[n] ?? sourceIndex.text.length;
    entries = [...reading.querySelectorAll('*')].filter(el => blocks.has(el)).map(el => {
      const block = blocks.get(el);
      return { el, ...block, start: lineOffset(block.firstLine), end: lineOffset(block.endLine),
        textStart: lineOffset(block.firstLine + (block.fence || block.frontMatter ? 1 : 0)) };
    });
  }
  function indexed(entry) {
    if (!entry.index) {
      entry.index = textIndex(entry.frontMatter ? entry.el.querySelector('code') : entry.el);
      entry.offsets = alignText(entry.index.text, sourceIndex.text.slice(entry.textStart, entry.end), entry.textStart);
    }
    return entry.index;
  }
  function visibleEntries() {
    return entries.filter(e => e.el.getClientRects().length && e.el.getBoundingClientRect().height > 0);
  }
  function capture(view) {
    // Repeated toggles without scrolling must not creep backwards as lines wrap
    // differently. Reuse the semantic anchor only while its layout/scroll is intact.
    if (restored && restored.view === view && restored.layout === layout(view) && Math.abs(restored.y - y(view)) < 1)
      return restored.position;
    if (y(view) < 1 || !sourceIndex.text.length) return { top: true };
    if (view === 'source') {
      const offset = topCharacter(sourceIndex, top(view)), rect = characterRect(sourceIndex, offset);
      return { offset, inset: Math.min(0, (rect?.top ?? top(view)) - top(view)) };
    }
    const candidates = visibleEntries().filter(e => e.el.getBoundingClientRect().bottom > top(view) + 1);
    candidates.sort((a, b) => {
      const at = Math.max(0, a.el.getBoundingClientRect().top - top(view)), bt = Math.max(0, b.el.getBoundingClientRect().top - top(view));
      return at - bt || (a.end - a.start) - (b.end - b.start);
    });
    const entry = candidates[0];
    if (!entry) return { offset: sourceIndex.text.length - 1, inset: 0 };
    if (entry.frontMatter && !entry.el.open) return { offset: entry.start, inset: 0 };
    const index = indexed(entry), char = topCharacter(index, top(view)), rect = characterRect(index, char);
    return { offset: entry.offsets[char] ?? entry.start, inset: Math.min(0, (rect?.top ?? top(view)) - top(view)) };
  }
  function positionForRange(view, range) {
    const offsetIn = index => {
      const item = index.nodes.find(item => item.node === range.startContainer);
      return item ? item.start + range.startOffset : null;
    };
    if (view === 'source') {
      const offset = offsetIn(sourceIndex);
      return offset === null ? null : {offset};
    }
    const candidates = entries.filter(entry => entry.el.contains(range.startContainer));
    candidates.sort((a,b) => (a.end-a.start)-(b.end-b.start));
    for (const entry of candidates) {
      const offset = offsetIn(indexed(entry));
      if (offset !== null) return {offset:entry.offsets[offset] ?? entry.start};
    }
    return null;
  }
  function restore(position, view) {
    if (!position || position.top) { move(view, 0); return; }
    let rect;
    if (view === 'source') rect = characterRect(sourceIndex, position.offset);
    else {
      const candidates = visibleEntries();
      const distance = e => position.offset < e.start ? e.start - position.offset : Math.max(0, position.offset - e.end + 1);
      candidates.sort((a, b) => distance(a) - distance(b) || (a.end - a.start) - (b.end - b.start));
      const entry = candidates[0];
      if (entry) {
        if (entry.frontMatter && position.offset > entry.start) entry.el.open = true;
        indexed(entry);
        let lo = 0, hi = entry.offsets.length - 1;
        while (lo < hi) { const mid = (lo + hi) >>> 1; if (entry.offsets[mid] < position.offset) lo = mid + 1; else hi = mid; }
        rect = characterRect(entry.index, lo) || entry.el.getBoundingClientRect();
      }
    }
    if (rect) {
      move(view, y(view) + rect.top - top(view) - (position.inset || 0));
      restored = { position, view, y: y(view), layout: layout(view) };
    }
  }
  return Object.freeze({ load, capture, restore, positionForRange });
}
