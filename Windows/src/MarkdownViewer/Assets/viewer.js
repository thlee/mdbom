(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const content = $('content');
  const sourceContent = $('sourcecontent');
  let documentView = 'reading';
  const workspace = window.MarkdownViewerCore.createWorkspace(content, sourceContent, data => send({type:'workspace', ...data}));
  const positionSync = workspace.positions;
  let presentation = {};
  let documentBase = '';
  let dropDepth = 0;
  let renderCount = 0;
  const search = window.MarkdownViewerCore.createSearch(workspace, content, sourceContent);
  const send = payload => window.chrome.webview.postMessage(payload);
  function render(markdown, name, baseUrl, view = 'reading', preserveScroll = false) {
    const snapshot = preserveScroll ? workspace.captureViewport() : null;
    documentBase = baseUrl;
    const fragment = window.MarkdownViewerCore.render(markdown, {
      baseURL: baseUrl, headingPrefix: '', localMarkdownLinks: true,
      imageExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico']
    });
    content.replaceChildren(fragment);
    // Keep the exact decoded file text. Raw HTML in the source is never parsed.
    window.MarkdownViewerCore.showSource(sourceContent, markdown);
    if (!markdown.trim()) {
      const p = document.createElement('p'); p.className = 'empty-document'; p.textContent = 'This document is empty.'; content.append(p);
    }
    $('documentname').textContent = name;
    document.title = name + ' — 엠디봄';
    $('welcome').hidden = true;
    $('reader').hidden = false;
    $('notice').hidden = true;
    positionSync.load();
    setView(view, false);
    workspace.configure(presentation, documentView);
    if (snapshot) workspace.restoreViewport(snapshot);
    renderCount++;
    document.documentElement.dataset.renderCount = String(renderCount);
  }

  function setView(view, rememberScroll = true) {
    closeFind();
    workspace.setView(view, rememberScroll);
    documentView = view === 'source' ? 'source' : 'reading';
  }

  function showFind() { $('findbar').hidden = false; $('findinput').focus(); $('findinput').select(); }
  function closeFind() {
    $('findbar').hidden = true; $('findresult').textContent = ''; $('findinput').blur();
    search.clear();
  }
  function find(backward = false) {
    const query = $('findinput').value;
    const result = search.find(query, backward);
    $('findresult').textContent = result.total ? `${result.current} / ${result.total}${result.total===5000?'+':''}` : query ? 'No match' : '';
    $('findinput').focus();
  }
  $('findnext').addEventListener('click', () => find());
  $('findprevious').addEventListener('click', () => find(true));
  $('findclose').addEventListener('click', closeFind);
  $('findinput').addEventListener('keydown', e => {
    if (e.key === 'Enter') { e.preventDefault(); find(e.shiftKey); }
  });
  $('openfile').addEventListener('click', () => send({ type: 'open' }));
  $('notice').querySelector('button').addEventListener('click', () => $('notice').hidden = true);

  content.addEventListener('click', e => {
    const anchor = e.target.closest('a');
    if (!anchor) return;
    e.preventDefault();
    const href = anchor.getAttribute('href');
    if (!href) return;
    if (href.startsWith('#')) {
      try { content.querySelector('#' + CSS.escape(decodeURIComponent(href.slice(1))))?.scrollIntoView(); } catch {}
    } else send({ type: 'link', url: anchor.href });
  });
  content.addEventListener('auxclick', e => e.preventDefault());
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') { closeFind(); $('notice').hidden = true; return; }
    let command;
    if (e.ctrlKey) {
      command = ({ o: 'open', p: 'print', r: 'reload', f: 'find', u: 'source', '+': 'zoomIn', '=': 'zoomIn', '-': 'zoomOut', '0': 'zoomReset' })[e.key.toLowerCase()];
      if (e.shiftKey && e.key.toLowerCase() === 't') command = 'theme';
      // The document has no editing or save surface.
      if (['s'].includes(e.key.toLowerCase())) e.preventDefault();
    } else if (e.key === 'F5') command = 'reload';
    if (command) { e.preventDefault(); send({ type: 'command', command }); }
  });
  document.addEventListener('dragenter', e => { e.preventDefault(); if (e.dataTransfer.types.includes('Files')) { dropDepth++; $('dropoverlay').hidden = false; } });
  document.addEventListener('dragover', e => { e.preventDefault(); e.dataTransfer.dropEffect = 'copy'; });
  document.addEventListener('dragleave', e => { e.preventDefault(); if (--dropDepth <= 0) { dropDepth = 0; $('dropoverlay').hidden = true; } });
  document.addEventListener('drop', e => {
    e.preventDefault(); dropDepth = 0; $('dropoverlay').hidden = true;
    if (e.dataTransfer.files.length) window.chrome.webview.postMessageWithAdditionalObjects({ type: 'drop' }, e.dataTransfer.files);
  });
  window.chrome.webview.addEventListener('message', e => {
    try {
      const data = e.data;
      if (data.type === 'presentation') { presentation = data; workspace.configure(data, documentView); }
      else if (data.type === 'render') render(data.markdown, data.name, data.baseUrl, data.view, data.preserveScroll);
      else if (data.type === 'view') setView(data.view);
      else if (data.type === 'width') {
        for (const mode of ['reading', 'source']) {
          const value = data[mode];
          if (Number.isInteger(value) && (value === 0 || (value >= 600 && value <= 1800)))
            document.documentElement.style.setProperty(`--${mode}-width`, value === 0 ? 'none' : `${value}px`);
        }
      }
      else if (data.type === 'theme') document.documentElement.dataset.theme = data.theme;
      else if (data.type === 'find') showFind();
      else if (data.type === 'notice') { $('notice').querySelector('span').textContent = data.message; $('notice').hidden = false; }
    } catch (error) { send({ type: 'error', message: 'Could not render this document: ' + error.message }); }
  });
  window.workspace = workspace;
  send({ type: 'ready' });
})();
