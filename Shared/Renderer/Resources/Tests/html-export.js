window.checkHTMLExport = html => {
  const doc = new DOMParser().parseFromString(html,'text/html');
  const main = doc.querySelector('main.markdown-body');
  const imgs = [...doc.querySelectorAll('img')];
  return {
    fullDocument: html.startsWith('<!doctype html>') && !!doc.querySelector('meta[charset]'),
    bodyOnly: !!main && !doc.querySelector('#floating-tools,#sourcecontent,#findbar'),
    offlineImages: imgs.length >= 3 && imgs.every(img=>img.getAttribute('src').startsWith('data:image/')),
    embeddedStyles: doc.querySelector('style')?.textContent.includes('.markdown-body'),
    mathPreserved: !!main?.querySelector('math'),
    diagramSource: !!main?.querySelector('.mermaid-diagram details'),
    titleEscaped: doc.title.length > 0 && !doc.querySelector('script,iframe,object,embed'),
    noAppLinks: ![...doc.querySelectorAll('a[href]')].some(a=>/mdviewer:|markdownviewer.invalid/.test(a.getAttribute('href'))),
    offlinePolicy: doc.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content.includes("default-src 'none'"),
    themePreserved: doc.documentElement.dataset.theme === (getComputedStyle(document.documentElement).colorScheme.includes('dark')?'dark':'light'),
  };
};
