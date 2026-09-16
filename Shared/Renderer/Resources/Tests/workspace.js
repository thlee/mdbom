window.runWorkspaceChecks = async function(workspace) {
  const checks = {};
  const tick = () => new Promise(resolve => setTimeout(resolve,120));
  const shell=document.getElementById('reader'), source=document.getElementById('sourcecontent'), reading=document.getElementById('content');
  const options={layout:'horizontal',toolbar:'always',sync:true,ratio:50,reading:920,source:1200};
  workspace.configure(options,'reading'); await tick();
  const rp=document.getElementById('reading-pane'), sp=document.getElementById('source-pane');
  checks.bothPanesVisible = !source.hidden && !reading.hidden && source.getBoundingClientRect().width>0 && reading.getBoundingClientRect().width>0;
  checks.horizontalLayout = sp.getBoundingClientRect().right < rp.getBoundingClientRect().left && Math.abs(sp.getBoundingClientRect().top-rp.getBoundingClientRect().top)<2;
  checks.sourceRemainsReadOnly = !source.isContentEditable && source.querySelector('input,textarea')===null;
  sp.scrollTop=500; await tick();
  checks.sourceDrivesReading = rp.scrollTop>20;
  const sourceAnchor=workspace.positions.capture('source'), readingAnchor=workspace.positions.capture('reading');
  checks.sameSourcePosition = Math.abs((sourceAnchor.offset||0)-(readingAnchor.offset||0))<80;
  const settled=rp.scrollTop; await tick();
  checks.noScrollFeedback = Math.abs(rp.scrollTop-settled)<2;
  rp.dispatchEvent(new WheelEvent('wheel')); rp.scrollTop+=250; await tick();
  checks.readingDrivesSource = sp.scrollTop>500;
  workspace.configure({...options,sync:false},'reading'); await tick();
  const before=rp.scrollTop; sp.scrollTop+=200; await tick();
  checks.syncCanBeDisabled = Math.abs(before-rp.scrollTop)<2;
  workspace.configure({...options,layout:'vertical',ratio:35},'reading'); await tick();
  checks.verticalLayout = sp.getBoundingClientRect().bottom < rp.getBoundingClientRect().top && Math.abs(sp.getBoundingClientRect().left-rp.getBoundingClientRect().left)<2;
  checks.splitRatio = sp.clientHeight < rp.clientHeight;
  checks.keyboardAccessibleDivider = document.getElementById('split-divider').tabIndex===0 && document.getElementById('split-divider').getAttribute('aria-orientation')==='horizontal';
  workspace.configure({...options,layout:'vertical',toolbar:'auto'},'reading'); await tick();
  const tools=document.getElementById('floating-tools'), reveal=document.getElementById('reveal-tools');
  tools.classList.remove('revealed');
  const rect=rp.getBoundingClientRect();
  checks.autoInitiallyHidden = getComputedStyle(tools).visibility==='hidden';
  reveal.dispatchEvent(new PointerEvent('pointerenter')); await tick();
  checks.autoReveals = getComputedStyle(tools).visibility==='visible';
  checks.revealDoesNotMoveDocument = Math.abs(rp.getBoundingClientRect().top-rect.top)<1 && Math.abs(rp.getBoundingClientRect().height-rect.height)<1;
  workspace.configure({...options,toolbar:'hidden'},'reading');
  reveal.click(); await tick();
  checks.legacyHiddenMigratesToAuto = document.documentElement.dataset.toolbar==='auto';
  checks.toolbarUsesButtons = !tools.querySelector('select,input[type=checkbox]') && tools.querySelectorAll('.view-segments button').length===4;
  checks.renderingLabel = tools.querySelector('[data-view=reading]').getAttribute('aria-label')==='문서';
  workspace.configure({...options,layout:'single',toolbar:'always'},'reading'); workspace.setView('reading',false); await tick();
  checks.singleViewRestored = reading.parentElement===shell && source.parentElement===shell && !reading.hidden && source.hidden;
  checks.floatingToolbarDefault = getComputedStyle(tools).position==='fixed' && getComputedStyle(tools).visibility==='visible';
  const fontPanel=document.getElementById('workspace-font'),fontButton=tools.querySelector('[aria-controls=workspace-font]');
  const widthButton=tools.querySelector('[aria-controls=workspace-width]'), widthPanel=document.getElementById('workspace-width');
  const clickWidthChild = selector => {
    const child=widthButton.querySelector(selector);
    child.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));
    child.dispatchEvent(new MouseEvent('click',{bubbles:true}));
  };
  clickWidthChild('span');
  checks.bothAppearanceSectionsVisible = [...widthPanel.querySelectorAll('fieldset')].length===2 && [...widthPanel.querySelectorAll('fieldset')].every(el=>el.getBoundingClientRect().width>0);
  checks.independentWidthControls = widthPanel.querySelectorAll('input[type=range][aria-label$="본문 폭"]').length===2;
  checks.independentFontControls = fontPanel.querySelectorAll('select[aria-label$="글꼴"]').length===2 && fontPanel.querySelectorAll('input[aria-label$="글자 크기"]').length===2;
  checks.widthToggleOpens = !widthPanel.hidden && widthButton.getAttribute('aria-expanded')==='true' && widthButton.getAttribute('aria-pressed')==='true';
  clickWidthChild('svg path');
  checks.widthToggleCloses = widthPanel.hidden && widthButton.getAttribute('aria-expanded')==='false' && widthButton.getAttribute('aria-pressed')==='false';
  widthButton.click();
  widthPanel.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));
  checks.widthPanelClickStaysOpen = !widthPanel.hidden;
  reading.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));
  checks.widthOutsideClickCloses = widthPanel.hidden && widthButton.getAttribute('aria-pressed')==='false';
  widthButton.click();
  document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
  checks.widthEscapeCloses = widthPanel.hidden && widthButton.getAttribute('aria-expanded')==='false';
  widthButton.click();fontButton.click();
  checks.fontOpensAndClosesWidth = widthPanel.hidden && !fontPanel.hidden && fontButton.getAttribute('aria-pressed')==='true';
  fontButton.click();checks.fontToggleCloses = fontPanel.hidden && fontButton.getAttribute('aria-expanded')==='false';
  fontButton.click();widthButton.click();checks.widthClosesFont = fontPanel.hidden && !widthPanel.hidden;
  const beforeHelp=source.textContent;
  tools.querySelector('[aria-controls=workspace-help]').click();
  const help=document.getElementById('workspace-help');
  checks.bundledMarkdownHelp = help.open && help.querySelector('h1').textContent==='엠디봄 사용설명서' && help.textContent.includes('1.0.0-beta.3') && help.querySelector('table')!==null;
  checks.helpPreservesDocument = source.textContent===beforeHelp && widthPanel.hidden && fontPanel.hidden;
  help.querySelector('button').click();checks.helpCloses = !help.open;
  // Search navigation must align the actual matched word, not the viewport top.
  const search=MarkdownViewerCore.createSearch(workspace,reading,source);
  function wordRect(root,word) {
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;
    while((node=walker.nextNode())){const at=node.data.indexOf(word);if(at>=0){const r=new Range();r.setStart(node,at);r.setEnd(node,at+word.length);return r.getBoundingClientRect();}}
    return null;
  }
  for(const layout of ['horizontal','vertical']) {
    workspace.configure({...options,layout,sync:false},'reading');await tick();
    for(const from of ['source','reading']) {
      (from==='source'?sp:rp).dispatchEvent(new Event('pointerdown'));
      const result=search.find('codeLine035');await tick();
      const sourceRect=wordRect(source,'codeLine035'),readingRect=wordRect(reading,'codeLine035');
      const inCenter=(rect,pane)=>rect && Math.abs(rect.top-pane.getBoundingClientRect().top-pane.clientHeight/2)<60;
      checks['search_'+layout+'_'+from+'_bothPanes']=result.matchFound && inCenter(sourceRect,sp) && inCenter(readingRect,rp);
      const highlight=[...CSS.highlights.get('current-match')][0];
      checks['search_'+layout+'_'+from+'_correctPane']=(from==='source'?source:reading).contains(highlight.startContainer);
    }
  }
  search.clear();
  workspace.configure({...options,layout:'single'},'reading');workspace.setView('reading',false);
  return checks;
};

window.runRefreshChecks = async function(workspace, render) {
  const checks = {}, tick = () => new Promise(resolve => setTimeout(resolve,120));
  const fixture = Array.from({length:160},(_,i)=>`Paragraph ${i}: unique refreshed content with **bold** and 한글.`).join('\n\n');
  const prefix = '# Inserted above the current reading position\n\n';
  for (const layout of ['horizontal','vertical','single']) {
    workspace.configure({layout,sync:false,ratio:40},'reading');
    await render(fixture,false); await tick();
    const rp=workspace.root('reading'), sp=workspace.root('source');
    rp.scrollTo(0,700); if(layout!=='single') sp.scrollTo(0,1400);
    await tick();
    const before=workspace.captureViewport();
    await render(prefix+fixture,true); await tick();
    const after=workspace.captureViewport();
    for (const [view,anchor] of Object.entries(before.anchors)) {
      checks[layout+'_'+view+'_followsText'] = Math.abs(after.anchors[view].offset-anchor.offset-prefix.length)<70;
    }
    checks[layout+'_activePanePreserved'] = before.active===after.active;
    checks[layout+'_layoutPreserved'] = workspace.layout===layout;
  }
  return checks;
};
