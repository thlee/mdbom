window.richFixture = String.raw`# 수식과 다이어그램

인라인 수식 $E = mc^2$ 과 분수 $\frac{a}{b}$.

$$
\int_0^1 x^2\,dx = \frac{1}{3}
$$

코드 속 수식은 그대로: \`$x^2$\`.

![로컬 SVG](rich.svg)

\`\`\`mermaid
flowchart LR
  A[문서 열기] --> B[수식과 그림]
  B --> C[인쇄]
\`\`\`

\`\`\`mermaid
sequenceDiagram
  사용자->>엠디봄: 파일 열기
  엠디봄-->>사용자: 문서 표시
\`\`\`
`.replaceAll('\\`','`');
window.runRichChecks = async function(root, render) {
  const checks={};
  await render(window.richFixture);
  const images=[...root.querySelectorAll('img')];
  await Promise.all(images.map(img=>img.decode().catch(()=>{})));
  checks.mathInline=root.querySelectorAll('.math-inline math').length===2;
  checks.mathBlock=!!root.querySelector('.math-block math mfrac');
  checks.mathAccessible=root.querySelector('math')?.namespaceURI==='http://www.w3.org/1998/Math/MathML' && !root.querySelector('annotation');
  checks.codeMathLiteral=root.querySelector('code')?.textContent==='$x^2$';
  checks.svgLocal=images.some(img=>img.alt==='로컬 SVG'&&img.naturalWidth===240);
  checks.svgInert=!window.__mdbomRichAttack && !window.compromised;
  checks.mermaidFlowAndSequence=root.querySelectorAll('[data-diagram=ready] > img').length===2;
  checks.mermaidImageDimensions=[...root.querySelectorAll('[data-diagram=ready] > img')].every(img=>img.naturalWidth>0&&img.naturalHeight>0&&img.getBoundingClientRect().width>0);
  checks.mermaidSource=root.querySelectorAll('.mermaid-diagram details code.language-mermaid').length===2;
  const core=window.MarkdownViewerCore;
  const workspace=window.viewer?.workspace||window.workspace;
  const search=core.createSearch(workspace,root,document.getElementById('sourcecontent'));
  const found=search.find('문서 열기');
  checks.diagramSourceSearch=found.total>0&&!!root.querySelector('.mermaid-diagram details[open]');
  search.clear();
  const fragment=core.render(String.raw`Literal \$x\$ and $5 and $10. \`$z$\`

$$
\unknowncommand{x}
$$

$\href{javascript:alert(1)}{bad}$

<svg onload="window.__mdbomRichAttack=true"><script>window.__mdbomRichAttack=true</script></svg>` .replaceAll('\\`','`'));
  checks.invalidMathFallback=!!fragment.querySelector('.math-error')&&fragment.textContent.includes('unknowncommand');
  checks.doubleDollarInlineLiteral=!core.render('text $$x$$ text').querySelector('.math-inline');
  checks.currencyLiteral=fragment.textContent.includes('$5 and $10');
  checks.mathNoActiveContent=!fragment.querySelector('a,script,svg,[href],[onload]');
  checks.mathDelimitersEscaped=fragment.textContent.includes('$x$')&&!core.render(String.raw`Literal \$x\$ and $5 and $10.`).querySelector('.math-inline');
  await render('```mermaid\nflowchart INVALID\n```\n\n```mermaid\n%%{init: {"securityLevel":"loose"}}%%\nflowchart LR\nA-->B\n```\n\n```mermaid\nflowchart LR\nA-->B\nclick A "https://example.com"\n```');
  checks.badDiagramsPreserveSource=root.querySelectorAll('[data-diagram=error] code.language-mermaid').length===3;
  checks.noActiveSVG=!root.querySelector('svg,script,iframe')&&!window.__mdbomRichAttack;
  await render(window.richFixture);
  return checks;
};
