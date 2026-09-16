// Search owns one result set per active pane, shared by both desktop hosts.
export function createSearch(workspace, reading, source) {
  let query = '', view = '', ranges = [], index = -1;
  function clear() {
    query = ''; view = ''; ranges = []; index = -1;
    CSS.highlights?.delete('find-matches'); CSS.highlights?.delete('current-match');
    window.getSelection()?.removeAllRanges();
  }
  function find(nextQuery, backwards = false) {
    const nextView = workspace.active;
    if (nextQuery !== query || nextView !== view || ranges.some(r => !r.startContainer.isConnected)) {
      clear(); query = nextQuery; view = nextView;
      const root = view === 'source' ? source : reading;
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      const nodes = []; let text = '', node;
      while ((node = walker.nextNode())) { nodes.push({node,start:text.length,end:text.length+node.length}); text += node.data; }
      if (query) {
        const pattern = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'giu');
        for (const match of text.matchAll(pattern)) {
          const first=nodes.find(n=>n.end>match.index), last=nodes.find(n=>n.end>=match.index+match[0].length);
          if (!first || !last) continue;
          const range = new Range(); range.setStart(first.node,match.index-first.start); range.setEnd(last.node,match.index+match[0].length-last.start);
          ranges.push(range); if(ranges.length===5000) break;
        }
      }
      if(CSS.highlights && window.Highlight) CSS.highlights.set('find-matches',new Highlight(...ranges));
    }
    CSS.highlights?.delete('current-match');
    if(ranges.length) {
      index=(index+(backwards?-1:1)+ranges.length)%ranges.length;
      const range=ranges[index];
      for(let parent=range.startContainer.parentElement;parent;parent=parent.parentElement) if(parent.tagName==='DETAILS') parent.open=true;
      if(CSS.highlights && window.Highlight) CSS.highlights.set('current-match',new Highlight(range));
      else { const selection=window.getSelection(); selection.removeAllRanges(); selection.addRange(range); }
      workspace.revealMatch(view,range);
    }
    return {matchFound:ranges.length>0,current:index+1,total:ranges.length};
  }
  return Object.freeze({clear,find});
}
