const view = document.querySelector('.demo-body');
const source = document.querySelector('#source');
const doc = document.querySelector('#document');
for (const button of document.querySelectorAll('[data-mode]')) {
  button.addEventListener('click', () => {
    const mode = button.dataset.mode;
    view.dataset.view = mode;
    source.hidden = mode === 'document';
    doc.hidden = mode === 'source';
    for (const other of document.querySelectorAll('[data-mode]')) other.setAttribute('aria-pressed', String(other === button));
  });
}
document.querySelector('#theme').addEventListener('click', (event) => {
  const dark = document.querySelector('.window').classList.toggle('dark');
  event.currentTarget.setAttribute('aria-pressed', String(dark));
  event.currentTarget.setAttribute('aria-label', dark ? '예시의 밝은 테마 켜기' : '예시의 어두운 테마 켜기');
});
