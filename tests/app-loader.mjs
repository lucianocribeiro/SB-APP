// Carga el componente real de la app (index.html) para testear sus funciones sin copiarlas.
// Toma el <script type="text/x-dc">, lo evalúa con stubs mínimos de navegador y devuelve una instancia.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

export function cargarApp(archivo = 'index.html') {
  const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
  const html = readFileSync(join(raiz, archivo), 'utf8');
  const i = html.indexOf('<script type="text/x-dc"'), a = html.indexOf('>', i) + 1, b = html.indexOf('</script>', a);
  if (i < 0) throw new Error('No se encontró el script de la app en ' + archivo);
  const code = html.slice(a, b).replace(/^\s*import[^\n]*\n/gm, '').replace(/class (\w+) extends DCLogic/, 'return class $1 extends DCLogic');
  class DCLogic { constructor() { this.state = {}; } setState(x) { Object.assign(this.state, typeof x === 'function' ? x(this.state) : x); } }
  const win = { location: { hash: '', search: '' }, addEventListener() {}, removeEventListener() {} };
  const doc = { addEventListener() {}, removeEventListener() {} };
  const ls = { getItem() { return null; }, setItem() {}, removeItem() {} };
  const Cls = new Function('DCLogic', 'window', 'document', 'localStorage', code)(DCLogic, win, doc, ls);
  return new Cls({});
}
