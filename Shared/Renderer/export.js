import markdownCSS from './Resources/Web/markdown.css';
import presentationCSS from './Resources/Web/presentation.css';

// Snapshot only the sanitized document, never the application shell or source pane.
export function captureHTML(content, title) {
  const root = getComputedStyle(document.documentElement);
  const variables = {};
  for (const key of root) if (key.startsWith('--')) variables[key] = root.getPropertyValue(key);
  const body = getComputedStyle(content);
  return {
    html: content.innerHTML, title,
    theme: root.colorScheme.includes('dark') ? 'dark' : 'light',
    variables, font: body.fontFamily, size: body.fontSize,
    images: [...new Set([...content.querySelectorAll('img')].map(img => img.getAttribute('src')))]
  };
}

export function buildHTML(snapshot, images) {
  const doc = document.implementation.createHTMLDocument(snapshot.title);
  doc.documentElement.lang = document.documentElement.lang || 'en';
  doc.documentElement.dataset.theme = snapshot.theme;
  // Standalone documents use page scrolling, never the app's split-pane layout.
  doc.documentElement.dataset.layout = 'single';
  const charset = doc.createElement('meta'); charset.setAttribute('charset','utf-8');
  const viewport = doc.createElement('meta'); viewport.name='viewport'; viewport.content='width=device-width, initial-scale=1';
  const policy = doc.createElement('meta'); policy.httpEquiv='Content-Security-Policy';
  policy.content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src 'none'; base-uri 'none'; form-action 'none';";
  doc.head.prepend(charset, viewport, policy);
  const style = doc.createElement('style');
  style.textContent = markdownCSS + '\n' + presentationCSS + '\n' +
    'body{overflow:auto} main.markdown-body{max-width:var(--reading-width,920px);margin:0 auto;padding:32px;min-width:0} @media(max-width:600px){main.markdown-body{padding:20px}}';
  doc.head.append(style);
  for (const [key,value] of Object.entries(snapshot.variables)) doc.documentElement.style.setProperty(key,value);
  const main = doc.createElement('main'); main.className='markdown-body';
  main.style.fontFamily=snapshot.font; main.style.fontSize=snapshot.size;
  main.innerHTML=snapshot.html;
  // Defense in depth, retaining trusted MathML produced by the renderer.
  main.querySelectorAll('script,style,link,iframe,object,embed,form,base').forEach(el=>el.remove());
  for(const el of main.querySelectorAll('*')) for(const attr of [...el.attributes])
    if(attr.name.startsWith('on') || ['srcset','contenteditable'].includes(attr.name)) el.removeAttribute(attr.name);
  for(const img of main.querySelectorAll('img')) {
    const src=img.getAttribute('src');
    const embedded=src?.startsWith('data:image/') ? src : images[src];
    if(!embedded?.startsWith('data:image/')) throw Error('이미지를 포함할 수 없습니다: '+(img.alt||src));
    img.setAttribute('src',embedded);
  }
  for(const link of main.querySelectorAll('a[href]')) {
    const href=link.getAttribute('href');
    if(href.startsWith('#')) {
      try {
        const id=decodeURIComponent(href.slice(1));
        if(!main.querySelector('#'+CSS.escape(id)) && main.querySelector('#'+CSS.escape('heading-'+id)))
          link.setAttribute('href','#heading-'+id);
      } catch {}
    }
    if(!/^(#|https?:\/\/|mailto:)/i.test(href) || /^https?:\/\/(?:app|document)\.markdownviewer\.invalid(?:[:/]|$)/i.test(href)) {
      link.removeAttribute('href'); link.title='Local document links are not included in this export.';
    }
  }
  doc.body.append(main);
  return '<!doctype html>\n'+doc.documentElement.outerHTML;
}

