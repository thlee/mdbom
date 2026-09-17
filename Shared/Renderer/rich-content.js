import katex from 'katex';
import mermaid from 'mermaid';
import createDOMPurify from 'dompurify';
const DOMPurify = createDOMPurify(window);

// Dollar math is parsed as Markdown tokens, never by scanning HTML/code spans.
export function installMath(md) {
  md.inline.ruler.before('escape','math_inline',(state,silent)=>{
    const start=state.pos;
    if(state.src[start]!=='$' || state.src[start+1]==='$' || state.src[start-1]==='$' || /\s/.test(state.src[start+1]||' ')) return false;
    let end=start+1;
    while((end=state.src.indexOf('$',end))!==-1) {
      let slashes=0;for(let i=end-1;i>start&&state.src[i]==='\\';i--)slashes++;
      if(slashes%2){end++;continue;}
      break;
    }
    if(end<0 || state.src[end+1]==='$' || end-start>4096 || /\s/.test(state.src[end-1]) || /\d/.test(state.src[end+1]||'') || /[\n`]/.test(state.src.slice(start,end)))return false;
    if(!silent){const token=state.push('math_inline','span',0);token.content=state.src.slice(start+1,end);}
    state.pos=end+1;return true;
  });
  md.block.ruler.before('fence','math_block',(state,start,end,silent)=>{
    const line=n=>state.src.slice(state.bMarks[n]+state.tShift[n],state.eMarks[n]);
    const first=line(start);if(!first.startsWith('$$') || state.sCount[start]-state.blkIndent>=4)return false;
    let last=start,content;
    if(first.length>3&&first.endsWith('$$'))content=first.slice(2,-2);
    else {
      if(first.trim()!=='$$')return false;
      for(last=start+1;last<end&&line(last).trim()!=='$$';last++);
      if(last===end)return false;
      content=state.getLines(start+1,last,state.blkIndent,false);
    }
    if(silent)return true;
    const token=state.push('math_block','div',0);token.block=true;token.map=[start,last+1];token.content=content;state.line=last+1;return true;
  },{alt:['paragraph','reference','blockquote','list']});
  for(const type of ['math_inline','math_block'])md.renderer.rules[type]=(tokens,index,options,env)=>{
    const t=tokens[index],block=type==='math_block',id=crypto.randomUUID();
    (env.math??=new Map()).set(id,{content:t.content,block});
    const position=t.attrGet('data-mv-position');
    return `<${block?'div':'span'} data-mv-math="${id}"${position?` data-mv-position="${position}"`:''}>${md.utils.escapeHtml(t.content)}</${block?'div':'span'}>`;
  };
}

export function typesetMath(fragment,entries) {
  for(const el of fragment.querySelectorAll('[data-mv-math]')) {
    const item=entries?.get(el.getAttribute('data-mv-math'));el.removeAttribute('data-mv-math');if(!item)continue;
    try {
      if(item.content.length>10000)throw Error('수식이 너무 깁니다');
      const html=katex.renderToString(item.content,{displayMode:item.block,output:'mathml',trust:false,throwOnError:true,maxExpand:1000,maxSize:10});
      const safe=DOMPurify.sanitize(html,{USE_PROFILES:{mathMl:true},RETURN_DOM_FRAGMENT:true});
      // MathML supplies accessible structure; omit duplicate hidden TeX from text search.
      safe.querySelectorAll('annotation,annotation-xml').forEach(n=>n.remove());
      el.replaceChildren(safe);el.className=item.block?'math-block':'math-inline';
    } catch {
      el.className='math-error';el.textContent=(item.block?'$$':'$')+item.content+(item.block?'$$':'$');
      el.title='수식을 표시할 수 없습니다. 원문을 확인하세요.';el.setAttribute('aria-label',el.title);
    }
  }
}

mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:'neutral',htmlLabels:false,
  flowchart:{htmlLabels:false},maxTextSize:20000,maxEdges:200,suppressErrorRendering:true,
  secure:['securityLevel','startOnLoad','maxTextSize','maxEdges','suppressErrorRendering','htmlLabels','flowchart','theme','themeCSS']});
let sequence=0;
let queue=Promise.resolve();
const cache=new Map();
async function diagram(source) {
  if(source.length>20000)throw Error('다이어그램은 20,000자 이하로 작성해 주세요.');
  if(/%%\s*\{|^\s*---|\b(?:click|href)\s|@\{|(?:https?:|javascript:|data:|file:|url\s*\()/i.test(source))throw Error('설정 지시문·링크·외부 리소스가 없는 다이어그램만 지원합니다.');
  const id='mdbom-diagram-'+(++sequence);
  const {svg}=await mermaid.render(id,source);
  // Generated SVG is sanitized and displayed as an inert image, not executable document HTML.
  const clean=DOMPurify.sanitize(svg,{USE_PROFILES:{svg:true,svgFilters:true},FORBID_TAGS:['foreignObject','script','a','image','animate','animateMotion','animateTransform','set'],RETURN_DOM_FRAGMENT:true});
  const root=clean.querySelector('svg');if(!root)throw Error('SVG를 생성하지 못했습니다.');
  for(const el of root.querySelectorAll('*'))for(const attr of [...el.attributes]) {
    if(/^(?:href|xlink:href)$/i.test(attr.name)&&!attr.value.startsWith('#'))el.removeAttribute(attr.name);
    if(/(?:https?:|javascript:|file:|data:|@import)/i.test(attr.value))el.removeAttribute(attr.name);
  }
  root.setAttribute('xmlns','http://www.w3.org/2000/svg');
  return 'data:image/svg+xml;charset=utf-8,'+encodeURIComponent(new XMLSerializer().serializeToString(root));
}
export async function enhanceDiagrams(root) {
  const blocks=[...root.querySelectorAll('pre > code.language-mermaid')];
  let index=0;
  for(const code of blocks) {
    const pre=code.parentElement,source=code.textContent;
    if(pre.dataset.diagram)continue;
    pre.dataset.diagram='pending';
    try {
      if(++index>20)throw Error('문서당 최대 20개 다이어그램을 표시합니다.');
      let pending=cache.get(source);
      if(!pending) {
        pending=queue.then(()=>diagram(source));queue=pending.catch(()=>{});
        cache.set(source,pending);if(cache.size>40)cache.delete(cache.keys().next().value);
      }
      const uri=await pending;if(!pre.isConnected)continue;
      const image=document.createElement('img');image.alt='Mermaid 다이어그램';image.src=uri;
      await image.decode();if(!pre.isConnected)continue;
      const details=document.createElement('details'),summary=document.createElement('summary');summary.textContent='다이어그램 원문';
      const original=document.createElement('pre');original.append(code);details.append(summary,original);
      pre.replaceChildren(image,details);pre.className='mermaid-diagram';pre.dataset.diagram='ready';
    } catch(error) {
      if(!pre.isConnected)continue;
      pre.dataset.diagram='error';const notice=document.createElement('div');notice.className='diagram-error';
      notice.textContent='다이어그램 표시 실패 — '+(error.message?.startsWith('다이어그램')||error.message?.startsWith('설정')||error.message?.startsWith('문서당')?error.message:'Mermaid 문법을 확인해 주세요.');pre.prepend(notice);
    }
  }
}
