// Loaded only by explicit native self-test modes; never served to document pages.
window.scrollChecks = (() => {
  const filler = Array.from({length: 35}, (_, i) => `Paragraph ${i}: readable text with **bold**, [links](https://example.com/${i}) and 한글.`).join('\n\n');
  const metadata = '---\nname: Sample document\nunsafe: "<img src=x onerror=alert(1)>"\n' + Array.from({length:80}, (_,i) => `field${i}: metadataValue${String(i).padStart(3,'0')}`).join('\n') + '\n---\n\n';
  const fixture = (metadata + [filler, '## Position heading', 'A paragraph with **strong words**, `inline code` and &amp; entities.',
    '```javascript\n' + Array.from({length: 70}, (_, i) => `const codeLine${String(i).padStart(3, '0')} = "value ${i}";`).join('\n') + '\n```',
    '| Name | Value |\n| --- | ---: |\n' + Array.from({length: 25}, (_, i) => `| TableRow${i} | ${i} |`).join('\n'),
    '- [x] Parent item\n  - Nested item position\n  - Other child\n\n' + Array.from({length: 100}, (_, i) => `wrapped${String(i).padStart(3, '0')}`).join(' '),
    '<div data-mv-position="forged" onclick="window.scrollInjected=true">HTML position</div>',
    filler].join('\n\n')).replace(/\n/g, '\r\n');
  function range(root, needle) {
    const nodes = []; let text = '', node;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while ((node = walker.nextNode())) { nodes.push({node, start:text.length, end:text.length + node.length}); text += node.data; }
    const offset = text.indexOf(needle);
    if (offset < 0) throw new Error('Missing test text: ' + needle);
    const first = nodes.find(n => n.end > offset), last = nodes.find(n => n.end >= offset + needle.length);
    const result = document.createRange();
    result.setStart(first.node, offset - first.start); result.setEnd(last.node, offset + needle.length - last.start);
    return result;
  }
  const active = () => document.getElementById(document.documentElement.dataset.view === 'source' ? 'sourcecontent' : 'content');
  const settle = () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  // WebKit includes zero-width CRLF fragments in bounding boxes. Measure painted
  // text, so the assertion checks the line a reader actually sees.
  const top = needle => Math.min(...[...range(active(), needle).getClientRects()].filter(r => r.width > 0 && r.height > 0).map(r => r.top));
  async function run(toggle) {
    const checks = {}, details = {};
    const info = document.querySelector('#content details.front-matter');
    checks.metadataCollapsed = Boolean(info && !info.open && info.querySelector('summary').textContent === '문서 정보 · YAML');
    checks.metadataInert = Boolean(info && !info.querySelector('img') && info.querySelector('code').textContent.includes('<img src=x onerror=alert(1)>'));
    checks.ordinaryRulePreserved = !MarkdownViewerCore.render('---\n\nA normal paragraph.\n\n---').querySelector('details');
    checks.unclosedHeaderPreserved = !MarkdownViewerCore.render('---\nname: incomplete\n# Body').querySelector('details');
    checks.laterDelimiterPreserved = !MarkdownViewerCore.render('# First\n\n---\nname: body\n---').querySelector('details');
    checks.quotedDelimiterPreserved = !MarkdownViewerCore.render('> ---\n> name: quoted\n> ---').querySelector('details');
    checks.yamlEndMarker = Boolean(MarkdownViewerCore.render('---\nname: sample\n...\n# Body').querySelector('details.front-matter'));
    const switchTo = async view => {
      if (document.documentElement.dataset.view !== view) await toggle();
      await settle();
    };
    const moveTo = async needle => { window.getSelection()?.removeAllRanges(); scrollBy(0, top(needle) + 3); await settle(); };
    for (const [name, needle, tolerance] of [
      ['heading', 'Position heading', 3], ['highlightedCode', 'const codeLine035', 3],
      ['tableRow', 'TableRow12', 3], ['nestedTaskList', 'Nested item position', 3],
      ['wrappedParagraph', 'wrapped045', 32], ['rawHTML', 'HTML position', 3]
    ]) {
      await switchTo('reading'); await moveTo(needle);
      await switchTo('source');
      details[name + 'ToSource'] = top(needle);
      checks[name + 'ToSource'] = Math.abs(top(needle) + 3) < tolerance;
      // Move elsewhere first: the return position must follow this view, not a cached offset.
      await moveTo('const codeLine055'); await switchTo('reading');
      checks[name + 'ReturnFollowsSource'] = Math.abs(top('const codeLine055') + 3) < 3;
      await switchTo('source'); await moveTo(needle);
      const probe = MarkdownViewerCore.createPositionSync(document.getElementById('content'), document.getElementById('sourcecontent'));
      probe.load();
      const anchor = probe.capture('source');
      details[name + 'SourceAnchorOffset'] = anchor.offset - fixture.indexOf(needle);
      details[name + 'SourceAnchorInset'] = anchor.inset;
      if (name === 'highlightedCode') {
        for (const [label, offset] of [['anchor', anchor.offset], ['target', fixture.indexOf(needle)], ['previous', fixture.indexOf(needle) - 33]]) {
          const char = document.createRange();
          char.setStart(document.getElementById('sourcecontent').firstChild, offset);
          char.setEnd(document.getElementById('sourcecontent').firstChild, offset + 1);
          details[label + 'BoundsTop'] = char.getBoundingClientRect().top;
          [...char.getClientRects()].forEach((rect, i) => { details[label + 'Rect' + i + 'Top'] = rect.top; details[label + 'Rect' + i + 'Width'] = rect.width; });
        }
      }
      await switchTo('reading');
      details[name + 'ToReading'] = top(needle);
      checks[name + 'ToReading'] = Math.abs(top(needle) + 3) < tolerance;
    }
    await switchTo('reading'); await moveTo('wrapped045');
    const beforeRepeatedToggle = top('wrapped045');
    for (let i = 0; i < 6; i++) { await switchTo('source'); await switchTo('reading'); }
    checks.repeatedTogglesDoNotDrift = Math.abs(top('wrapped045') - beforeRepeatedToggle) < 2;
    await switchTo('source'); scrollTo(0, 0); await settle(); await switchTo('reading');
    checks.documentStart = scrollY === 0;
    await switchTo('source');
    checks.exactCRLFSource = active().textContent === fixture && active().children.length === 0;
    checks.noUntrustedMarkers = !document.querySelector('[data-mv-position]') && !window.scrollInjected;
    await moveTo('metadataValue030'); await switchTo('reading');
    checks.metadataSourcePosition = info.open && Math.abs(top('metadataValue030') + 3) < 3;
    info.open = false;
    await switchTo('reading');
    return {checks, details};
  }
  return {fixture, run, top};
})();
