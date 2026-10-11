// A stand-in for the design canvas runtime, just enough to render one
// artboard (.dc.html) in a plain browser so it can be screenshotted next to
// the simulator. It runs the artboard's Component.renderVals() once, then
// fills {{holes}}, <sc-for> and <sc-if>. No state, no events: the
// design-check agent only needs the first frame.
(function () {
  class DCLogic {
    constructor() { this.props = {}; this.state = {}; }
    setState(s) { Object.assign(this.state, s); }
    forceUpdate() {}
  }
  window.DCLogic = DCLogic;

  // Artboards carry no viewport tag; without one a browser lays them out at
  // 980 px and the screenshot comes out shrunk.
  if (!document.querySelector('meta[name=viewport]')) {
    const meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1';
    document.head.appendChild(meta);
  }

  const hole = /\{\{\s*([^}]+?)\s*\}\}/g;
  const literal = (p) => (p === 'true' ? true : p === 'false' ? false : undefined);
  const get = (path, scope) => {
    const lit = literal(path);
    if (lit !== undefined) return lit;
    return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope);
  };
  const fill = (text, scope) => text.replace(hole, (_, p) => {
    const v = get(p, scope);
    return v == null ? '' : String(v);
  });
  const single = (attr, scope) => {
    const m = attr && attr.match(/^\s*\{\{\s*([^}]+?)\s*\}\}\s*$/);
    return m ? get(m[1], scope) : undefined;
  };

  function walk(node, scope) {
    for (const child of [...node.childNodes]) {
      if (child.nodeType === Node.TEXT_NODE) {
        if (child.textContent.includes('{{')) child.textContent = fill(child.textContent, scope);
        continue;
      }
      if (child.nodeType !== Node.ELEMENT_NODE) continue;
      const tag = child.tagName.toLowerCase();
      if (tag === 'sc-for') {
        const list = single(child.getAttribute('list'), scope) || [];
        const as = child.getAttribute('as') || 'item';
        const out = document.createDocumentFragment();
        list.forEach((item, i) => {
          const inner = Object.assign(Object.create(scope), { [as]: item, $index: i });
          const box = document.createElement('div');
          box.innerHTML = child.innerHTML;
          walk(box, inner);
          while (box.firstChild) out.appendChild(box.firstChild);
        });
        child.replaceWith(out);
        continue;
      }
      if (tag === 'sc-if') {
        if (!single(child.getAttribute('value'), scope)) { child.remove(); continue; }
        walk(child, scope);
        child.replaceWith(...child.childNodes);
        continue;
      }
      for (const a of [...child.attributes]) {
        if (a.value.includes('{{')) child.setAttribute(a.name, fill(a.value, scope));
      }
      walk(child, scope);
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    let vals = {};
    const script = document.querySelector('script[data-dc-script]');
    if (script) {
      try {
        const Component = new Function('DCLogic', `${script.textContent}; return Component;`)(DCLogic);
        vals = new Component().renderVals() || {};
      } catch (e) {
        console.error('design-check: renderVals failed', e);
      }
    }
    const root = document.querySelector('x-dc');
    if (!root) return;
    const helmet = root.querySelector('helmet');
    if (helmet) {
      [...helmet.children].forEach((n) => document.head.appendChild(n));
      helmet.remove();
    }
    walk(root, vals);
    document.documentElement.dataset.rendered = 'true';
  });
})();
