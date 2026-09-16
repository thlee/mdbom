import { createPositionSync } from './position.js';
import spec from './Resources/Web/interface.json';
import helpMarkdown from '../../HELP.md';

// Shared document workspace. Native hosts own files, preferences and window commands.
export function createWorkspace(reading, source, send) {
  const shell = document.getElementById('reader');
  const pane = (id, label) => {
    const el = document.createElement('section'); el.id = id; el.className = 'document-pane';
    el.tabIndex = 0; el.setAttribute('aria-label', label); return el;
  };
  const readingPane = pane('reading-pane', '문서 화면');
  const sourcePane = pane('source-pane', '소스 화면');
  const split = document.createElement('div'); split.id = 'split-workspace'; split.hidden = true;
  const divider = document.createElement('div'); divider.id = 'split-divider'; divider.tabIndex = 0;
  divider.setAttribute('role', 'separator'); divider.setAttribute('aria-label', '분할 비율');
  divider.setAttribute('aria-valuemin', '20'); divider.setAttribute('aria-valuemax', '80');
  split.append(sourcePane, divider, readingPane); document.body.append(split);
  let layout = 'single', active = 'reading', synced = true, ratio = 50, mode = 'always';
  let suppress = null, unlockFrame = 0, pendingFrame = 0;
  const root = view => layout === 'single' ? window : view === 'source' ? sourcePane : readingPane;
  const positions = createPositionSync(reading, source, root);
  const emit = (key, value) => send({action:'workspace', key, value:String(value)});
  const release = () => { cancelAnimationFrame(unlockFrame); unlockFrame = requestAnimationFrame(() => { unlockFrame = requestAnimationFrame(() => { suppress = null; }); }); };
  function captureViewport() {
    const text = source.textContent;
    const anchors = {};
    for (const view of layout === 'single' ? [active] : ['reading','source']) {
      const p = positions.capture(view);
      const start = Math.max(0, (p.offset || 0) - 48);
      anchors[view] = {...p, context:text.slice(start, start + 128), delta:(p.offset || 0)-start};
    }
    return {active, anchors};
  }
  function restoreViewport(snapshot) {
    if (!snapshot) return;
    suppress = 'both'; cancelAnimationFrame(pendingFrame);
    active = snapshot.active;
    const text = source.textContent;
    for (const [view, anchor] of Object.entries(snapshot.anchors)) {
      let offset = anchor.offset;
      // Follow unchanged nearby text when an editor inserts/deletes content above it.
      if (!anchor.top && anchor.context) {
        const index = text.indexOf(anchor.context);
        if (index >= 0 && text.indexOf(anchor.context, index+1) < 0) offset = index + anchor.delta;
      }
      positions.restore({...anchor, offset:Math.min(offset || 0, Math.max(0,text.length-1))}, view);
    }
    release();
  }
  function synchronize(from = active) {
    if (layout === 'single' || !synced) return;
    const to = from === 'reading' ? 'source' : 'reading';
    suppress = to; positions.restore(positions.capture(from), to); release();
  }
  function revealMatch(view, range) {
    // Search is explicit navigation: move both panes even when free scrolling is selected.
    active = view; suppress = 'both'; cancelAnimationFrame(pendingFrame);
    const scrollRoot = root(view);
    const viewportTop = scrollRoot === window ? 0 : scrollRoot.getBoundingClientRect().top;
    const height = scrollRoot === window ? innerHeight : scrollRoot.clientHeight;
    const position = positions.positionForRange(view, range);
    scrollRoot.scrollBy(0, range.getBoundingClientRect().top - viewportTop - height / 2);
    if (layout !== 'single' && position) {
      const other = view === 'source' ? 'reading' : 'source';
      positions.restore({...position, inset:root(other).clientHeight/2},other);
    }
    release();
  }
  for (const [view, el] of [['reading',readingPane],['source',sourcePane]]) {
    const activate = () => { active = view; split.dataset.active = view; };
    el.addEventListener('pointerdown', activate); el.addEventListener('focusin', activate);
    el.addEventListener('wheel', () => { suppress = null; activate(); }, {passive:true});
    el.addEventListener('scroll', () => {
      if (suppress === 'both' || suppress === view || layout === 'single') return;
      activate(); cancelAnimationFrame(pendingFrame);
      pendingFrame = requestAnimationFrame(() => synchronize(view));
    }, {passive:true});
  }
  function setRatio(value, save = false) {
    ratio = Math.max(20, Math.min(80, Number(value) || 50));
    split.style.setProperty('--split-ratio', `${ratio}%`);
    divider.setAttribute('aria-valuenow', String(Math.round(ratio)));
    if (save) emit('ratio', Math.round(ratio));
  }
  divider.addEventListener('pointerdown', e => { if (e.button === 0) { divider.focus(); divider.setPointerCapture(e.pointerId); e.preventDefault(); } });
  divider.addEventListener('pointermove', e => {
    if (!divider.hasPointerCapture(e.pointerId)) return;
    const rect = split.getBoundingClientRect();
    setRatio(layout === 'horizontal' ? (e.clientX-rect.left)/rect.width*100 : (e.clientY-rect.top)/rect.height*100);
  });
  divider.addEventListener('pointerup', e => {
    if (divider.hasPointerCapture(e.pointerId)) { divider.releasePointerCapture(e.pointerId); setRatio(ratio,true); synchronize(); }
  });
  divider.addEventListener('keydown', e => {
    const delta = {ArrowLeft:-2,ArrowUp:-2,ArrowRight:2,ArrowDown:2}[e.key];
    if (delta || e.key === 'Home') { e.preventDefault(); setRatio(e.key === 'Home' ? 50 : ratio+delta,true); synchronize(); }
  });
  function configure(options, view) {
    const next = ['horizontal','vertical'].includes(options.layout) ? options.layout : 'single';
    const changed = next !== layout;
    const saved = changed ? positions.capture(layout === 'single' ? view : active) : null;
    suppress = 'both';
    if (changed) {
      if (next === 'single') { shell.insertBefore(reading, document.getElementById('sourceempty')); reading.after(source); }
      else { sourcePane.append(source); readingPane.append(reading); }
      layout = next;
    }
    split.hidden = layout === 'single' || shell.hidden;
    document.documentElement.dataset.layout = layout;
    split.dataset.layout = layout;
    sourcePane.setAttribute('data-label','소스 · 읽기 전용'); readingPane.setAttribute('data-label','문서');
    divider.setAttribute('aria-orientation', layout === 'vertical' ? 'horizontal' : 'vertical');
    if (layout !== 'single') { reading.hidden = false; source.hidden = false; }
    synced = options.sync !== false;
    setRatio(options.ratio ?? ratio);
    if (changed) {
      if (layout === 'single') positions.restore(saved,view);
      else { positions.restore(saved,'source'); positions.restore(saved,'reading'); }
    }
    release();
    mode = options.toolbar === 'auto' || options.toolbar === 'hidden' ? 'auto' : 'always';
    document.documentElement.dataset.toolbar = mode;
    floating.hidden = false; reveal.hidden = mode === 'always';
    updateToolbar(layout === 'single' ? view : layout);
    widths = {reading:options.reading ?? widths.reading, source:options.source ?? widths.source};
    for (const view of ['reading','source']) if(widths[view]>0) rememberedWidths[view]=widths[view];
    applyFonts(options);
    updateWidth();
  }
  function setView(view, remember = true) {
    const previous = document.documentElement.dataset.view === 'source' ? 'source' : 'reading';
    const saved = remember ? positions.capture(layout === 'single' ? previous : active) : null;
    active = view === 'source' ? 'source' : 'reading';
    reading.hidden = layout === 'single' && active === 'source';
    source.hidden = layout === 'single' && active !== 'source';
    document.getElementById('sourceempty').hidden = layout !== 'single' || active !== 'source' || source.textContent.length !== 0;
    document.getElementById('documentmode').textContent = active === 'source' ? 'MARKDOWN SOURCE · READ ONLY' : 'LOCAL DOCUMENT';
    shell.dataset.view = active; document.documentElement.dataset.view = active;
    updateToolbar(layout === 'single' ? active : layout);
    if (layout === 'single') positions.restore(saved,active);
    split.hidden = layout === 'single' || shell.hidden;
    if (layout !== 'single') { reading.hidden = false; source.hidden = false; }
  }
  // An overlay in the WebView avoids WPF airspace issues and never changes the viewport on reveal.
  const floating = document.createElement('nav'); floating.id = 'floating-tools'; floating.hidden = true;
  floating.setAttribute('aria-label','문서 도구');
  const icons = {
    open:'M3 7h6l2 2h10l-2 11H3z M3 7V4h6l2 3',
    print:'M6 9V3h12v6 M6 17H3V9h18v8h-3 M6 14h12v7H6z M17 12h1',
    reload:'M20 7v5h-5 M20 12a8 8 0 1 0-2 6',
    find:'M10 17a7 7 0 1 1 0-14 7 7 0 0 1 0 14 M15 15l6 6',
    reading:'M4 3h16v18H4z M8 8h8 M8 12h8 M8 16h5',
    source:'M8 7l-5 5 5 5 M16 7l5 5-5 5 M14 4l-4 16',
    horizontal:'M3 4h18v16H3z M12 4v16',
    vertical:'M3 4h18v16H3z M3 12h18',
    link:'M9 15l6-6 M8 17l-1 1a4 4 0 0 1-6-6l5-5a4 4 0 0 1 6 0 M16 7l1-1a4 4 0 0 1 6 6l-5 5a4 4 0 0 1-6 0',
    font:'M4 20L10 4l6 16 M6 14h8 M17 10h6 M20 10v10',
    help:'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20 M9 8a3 3 0 1 1 5 2c-2 1-2 2-2 4 M12 17v1',
    width:'M4 4v16 M20 4v16 M5 12h14 M8 9l-3 3 3 3 M16 9l3 3-3 3',
    theme:'M12 3a9 9 0 1 0 9 9 7 7 0 0 1-9-9',
    fullscreen:'M8 3H3v5 M16 3h5v5 M3 16v5h5 M21 16v5h-5',
    pin:'M8 3h8 M9 3v6l-3 5h12l-3-5V3 M12 14v7'
  };
  function icon(name) {
    const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
    svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('aria-hidden','true');
    const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',icons[name]);svg.append(path);return svg;
  }
  function tool(label, glyph, callback, text = false, parent = floating) {
    const b=document.createElement('button');b.type='button';b.title=label;b.setAttribute('aria-label',label);b.className='tool-button';
    b.append(icon(glyph));if(text){const span=document.createElement('span');span.textContent=label;b.append(span);}
    b.addEventListener('click',callback);parent.append(b);return b;
  }
  const command = name => () => send({action:'command',command:name});
  const separator=()=>{const el=document.createElement('span');el.className='tool-separator';el.setAttribute('aria-hidden','true');floating.append(el);};
  tool('열기','open',command('open'),true);tool('새로고침','reload',command('reload'));tool('인쇄 · PDF','print',command('print'));tool('검색','find',command('find'));
  separator();
  const viewGroup=document.createElement('div');viewGroup.className='view-segments';viewGroup.setAttribute('role','group');viewGroup.setAttribute('aria-label','문서 보기');floating.append(viewGroup);
  const viewButtons=new Map();
  for(const [value,label] of [['reading','문서'],['source','소스'],['horizontal','좌우 분할'],['vertical','상하 분할']]) {
    const b=tool(label,value,()=>emit('view',value),value==='reading'||value==='source',viewGroup);b.dataset.view=value;viewButtons.set(value,b);
  }
  const syncButton=tool('스크롤 연결','link',()=>emit('sync',!synced));
  separator();
  const widthButton=tool('폭','width',()=>{setWidthPanel(widthPanel.hidden);updateWidth();},true);
  widthButton.setAttribute('aria-controls','workspace-width');
  widthButton.setAttribute('aria-expanded','false');
  widthButton.setAttribute('aria-pressed','false');
  const fontButton=tool('글꼴','font',()=>{setFontPanel(fontPanel.hidden);updateWidth();},true);
  fontButton.setAttribute('aria-controls','workspace-font');fontButton.setAttribute('aria-expanded','false');fontButton.setAttribute('aria-pressed','false');
  tool('테마 전환','theme',command('theme'));tool('전체화면','fullscreen',command('fullscreen'));
  separator();
  const pinButton=tool('항상 표시','pin',()=>emit('toolbar',mode==='always'?'auto':'always'));
  separator();
  const helpButton=tool('도움말','help',()=>{setWidthPanel(false);setFontPanel(false);helpDialog.showModal();});
  helpButton.setAttribute('aria-controls','workspace-help');

  function updateToolbar(selected) {
    for(const [value,b] of viewButtons)b.setAttribute('aria-pressed',String(value===selected));
    syncButton.hidden=layout==='single';syncButton.setAttribute('aria-pressed',String(synced));
    syncButton.title=synced?'스크롤 연결 켜짐 — 클릭해서 해제':'스크롤 연결 꺼짐 — 클릭해서 연결';
    pinButton.setAttribute('aria-pressed',String(mode==='always'));
    pinButton.setAttribute('aria-label',mode==='always'?'도구바 고정 해제 · 자동 숨김':'도구바 고정 · 항상 표시');
    pinButton.title=mode==='always'?'항상 표시 · 클릭하면 자동 숨김':'자동 숨김 · 클릭하면 항상 표시';
  }
  const reveal=document.createElement('button'); reveal.id='reveal-tools'; reveal.textContent='도구 ▾'; reveal.hidden=true;
  reveal.setAttribute('aria-label','숨긴 도구 표시');
  let hideTimer;
  const show=()=>{clearTimeout(hideTimer);floating.classList.add('revealed');};
  const hide=()=>{clearTimeout(hideTimer);hideTimer=setTimeout(()=>{if (!floating.matches(':focus-within,:hover')) floating.classList.remove('revealed');},700);};
  reveal.addEventListener('click',show); reveal.addEventListener('pointerenter',()=>{if(mode==='auto')show();});
  floating.addEventListener('pointerenter',show); floating.addEventListener('pointerleave',hide);
  floating.addEventListener('focusin',show); floating.addEventListener('focusout',hide);
  document.addEventListener('pointermove',e=>{if(mode==='auto' && e.clientY<8)show();},{passive:true});
  document.addEventListener('pointerdown',e=>{if(!floating.contains(e.target)&&e.target!==reveal)floating.classList.remove('revealed');});
  document.addEventListener('keydown',e=>{
    if(e.key==='Escape' && helpDialog.open) { e.preventDefault();helpDialog.close();return; }
    if(e.key==='Escape' && !fontPanel.hidden) { e.preventDefault();setFontPanel(false);fontButton.focus();return; }
    if(e.key==='Escape' && !widthPanel.hidden) { e.preventDefault(); setWidthPanel(false); widthButton.focus(); return; }
    if(e.key==='Escape') { floating.classList.remove('revealed'); send({action:'command',command:'exitFullscreen'}); }
    if((e.ctrlKey||e.metaKey)&&e.shiftKey&&e.key.toLowerCase()==='h') {e.preventDefault();emit('toolbar',mode==='always'?'auto':'always');}
  });
  let widths = {reading:920,source:1200};
  const rememberedWidths = {...widths};
  const widthPanel=document.createElement('section'); widthPanel.id='workspace-width'; widthPanel.hidden=true;
  widthPanel.setAttribute('aria-label','본문 폭 설정');
  const fontPanel=document.createElement('section');fontPanel.id='workspace-font';fontPanel.hidden=true;fontPanel.setAttribute('aria-label','글꼴 설정');
  function setFontPanel(open) {
    if(open) setWidthPanel(false);
    fontPanel.hidden=!open;fontButton.setAttribute('aria-expanded',String(open));fontButton.setAttribute('aria-pressed',String(open));
  }
  function setWidthPanel(open) {
    if(open) setFontPanel(false);
    widthPanel.hidden=!open;
    widthButton.setAttribute('aria-expanded',String(open));
    widthButton.setAttribute('aria-pressed',String(open));
  }
  const fonts = {readingFont:'system',sourceFont:'mono',readingFontSize:16,sourceFontSize:14};
  const families = {
    system:'-apple-system, BlinkMacSystemFont, "Segoe UI", "Malgun Gothic", sans-serif',
    sans:'Arial, "Apple SD Gothic Neo", "Malgun Gothic", sans-serif',
    serif:'Georgia, "AppleMyungjo", "Batang", serif',
    mono:'ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace'
  };
  const controls = {};
  function applyFonts(options) {
    for (const [view,element] of [['reading',reading],['source',source]]) {
      const key=view+'Font', sizeKey=view+'FontSize';
      if(Object.hasOwn(families,options[key])) fonts[key]=options[key];
      if(Number.isFinite(options[sizeKey])) fonts[sizeKey]=Math.max(12,Math.min(28,options[sizeKey]));
      document.documentElement.style.setProperty('--'+view+'-font',families[fonts[key]]);
      document.documentElement.style.setProperty('--'+view+'-font-size',fonts[sizeKey]+'px');
    }
  }
  const heading=document.createElement('h2');heading.textContent='본문 폭';
  const hint=document.createElement('p');hint.className='appearance-hint';hint.textContent='두 화면의 설정을 각각 기억합니다.';
  const sections=document.createElement('div');sections.className='appearance-sections';
  const fontHeading=document.createElement('h2');fontHeading.textContent='글꼴';
  const fontHint=hint.cloneNode(true);
  const fontSections=document.createElement('div');fontSections.className='appearance-sections';
  for(const [view,title] of [['reading','문서'],['source','소스']]) {
    const section=document.createElement('fieldset');section.dataset.appearance=view;
    const legend=document.createElement('legend');legend.textContent=title;section.append(legend);
    const row=document.createElement('div');row.className='appearance-row';
    const caption=document.createElement('span');caption.textContent='본문 폭';
    const valueLabel=document.createElement('output');row.append(caption,valueLabel);
    const slider=document.createElement('input');slider.type='range';slider.min=spec.width.minimum;slider.max=spec.width.maximum;slider.step=spec.width.step;slider.setAttribute('aria-label',title+' 본문 폭');
    slider.addEventListener('input',()=>emit(view+'Width',slider.value));
    const presets=document.createElement('div');presets.className='width-presets';
    for(const preset of spec.presets){const b=document.createElement('button');b.textContent=preset.title;b.addEventListener('click',()=>emit(view+'Width',preset.value));presets.append(b);}
    const fit=document.createElement('input');fit.type='checkbox';fit.addEventListener('change',()=>emit(view+'Width',fit.checked?0:rememberedWidths[view]));
    const fitLabel=document.createElement('label');fitLabel.append(fit,' 창 너비에 맞춤');
    const font=document.createElement('select');font.setAttribute('aria-label',title+' 글꼴');
    for(const [value,label] of [['system','시스템 기본'],['sans','고딕'],['serif','명조'],['mono','고정폭']]) {const o=document.createElement('option');o.value=value;o.textContent=label;font.append(o);}
    font.addEventListener('change',()=>emit(view+'Font',font.value));
    const fontLabel=document.createElement('label');fontLabel.className='appearance-row';fontLabel.append('글꼴',font);
    const size=document.createElement('input');size.type='range';size.min=12;size.max=28;size.step=1;size.setAttribute('aria-label',title+' 글자 크기');
    size.addEventListener('input',()=>emit(view+'FontSize',size.value));
    const sizeRow=document.createElement('div');sizeRow.className='appearance-row';const sizeValue=document.createElement('output');sizeRow.append('글자 크기',sizeValue);
    const reset=document.createElement('button');reset.textContent='기본값으로';reset.setAttribute('aria-label',title+' 설정 초기화');
    reset.addEventListener('click',()=>emit(view+'Width',spec.width[view+'Default']));
    const fontSection=document.createElement('fieldset');fontSection.append(legend.cloneNode(true));
    const fontReset=document.createElement('button');fontReset.textContent='기본값으로';fontReset.setAttribute('aria-label',title+' 글꼴 초기화');
    fontReset.addEventListener('click',()=>{emit(view+'Font',view==='reading'?'system':'mono');emit(view+'FontSize',view==='reading'?16:14);});
    section.append(row,slider,presets,fitLabel,reset);sections.append(section);
    fontSection.append(fontLabel,sizeRow,size,fontReset);fontSections.append(fontSection);
    controls[view]={valueLabel,slider,fit,font,size,sizeValue};
  }
  const close=document.createElement('button');close.textContent='닫기';close.className='appearance-close';close.addEventListener('click',()=>{setWidthPanel(false);widthButton.focus();});
  function updateWidth(){
    for(const view of ['reading','source']) {
      const c=controls[view],value=widths[view];
      c.valueLabel.textContent=value===0?'창에 맞춤':value+' px';c.slider.disabled=value===0;c.slider.value=value||rememberedWidths[view];c.fit.checked=value===0;
      c.font.value=fonts[view+'Font'];c.size.value=fonts[view+'FontSize'];c.sizeValue.textContent=fonts[view+'FontSize']+' px';
    }
  }
  const fontClose=close.cloneNode(true);fontClose.addEventListener('click',()=>{setFontPanel(false);fontButton.focus();});
  fontPanel.append(fontHeading,fontHint,fontSections,fontClose);
  const helpDialog=document.createElement('dialog');helpDialog.id='workspace-help';helpDialog.setAttribute('aria-label','엠디봄 사용설명서');
  const helpClose=document.createElement('button');helpClose.textContent='도움말 닫기';helpClose.autofocus=true;helpClose.addEventListener('click',()=>helpDialog.close());
  const helpBody=document.createElement('article');helpBody.className='markdown-body';
  helpBody.append(window.MarkdownViewerCore.render(helpMarkdown));helpDialog.append(helpClose,helpBody);
  helpDialog.addEventListener('close',()=>helpButton.focus());
  widthPanel.setAttribute('aria-label','본문 폭 설정');
  widthPanel.append(heading,hint,sections,close);
  document.addEventListener('pointerdown',e=>{if(!widthPanel.contains(e.target)&&!widthButton.contains(e.target))setWidthPanel(false);});
  document.addEventListener('pointerdown',e=>{if(!fontPanel.contains(e.target)&&!fontButton.contains(e.target))setFontPanel(false);});
  document.body.append(floating,reveal,widthPanel,fontPanel,helpDialog);
  return Object.freeze({positions,captureViewport,restoreViewport,configure,setView,root,synchronize,revealMatch,get active(){return active;},get layout(){return layout;}});
}
