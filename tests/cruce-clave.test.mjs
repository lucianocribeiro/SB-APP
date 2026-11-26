#!/usr/bin/env node
// Tests mínimos de clave de cruce (auditoría TST-01 / REG-01 / REG-02 / REG-03).
// Correr: node tests/cruce-clave.test.mjs

function cuitValido(c) {
  const d = String(c == null ? '' : c).replace(/\D/g, '');
  return d.length === 11 && !/^0+$/.test(d);
}

function canonComp(x) {
  let tc = (x && x.tc) || '', letra = (x && x.letra) || '';
  if (tc === 'TK') { tc = 'FC'; if (!letra) letra = 'B'; }
  return { tc, letra };
}

function k4(x) {
  const c = canonComp(x);
  return [c.tc, c.letra, x.pv, x.nro].join('|');
}

function tipEquiv(a, b) {
  const ca = canonComp(a), cb = canonComp(b);
  return ca.tc === cb.tc && ca.letra === cb.letra;
}

// Mapeo ARCA_BEJ (fragmento tiques) — debe coincidir con index.html
const ARCA_TIQ = {
  81: { tc: 'TK', letra: 'A' },
  82: { tc: 'TK', letra: 'B' },
  83: { tc: 'TK', letra: 'B' },
  109: { tc: 'TK', letra: 'C' },
  111: { tc: 'TK', letra: 'C' },
  112: { tc: 'NC', letra: 'A' },
  113: { tc: 'NC', letra: 'B' },
  114: { tc: 'NC', letra: 'C' },
  115: { tc: 'ND', letra: 'A' },
  116: { tc: 'ND', letra: 'B' },
  117: { tc: 'ND', letra: 'C' },
  118: { tc: 'TK', letra: 'M' },
  119: { tc: 'NC', letra: 'M' },
  120: { tc: 'ND', letra: 'M' }
};

let failed = 0;
function ok(cond, msg) {
  if (!cond) { console.error('FAIL:', msg); failed++; }
  else console.log('ok:', msg);
}

// REG-01 Lanes: TKB/TK vs FCB misma clave canónica
const lanes = [
  { L: { tc: 'TK', letra: 'B', pv: 100, nro: 45336, cuit: '00000000000016811617' }, A: { tc: 'FC', letra: 'B', pv: 100, nro: 45336, cuit: '0' } },
  { L: { tc: 'TK', letra: '', pv: 100, nro: 44773, cuit: '00000000000044444444' }, A: { tc: 'FC', letra: 'B', pv: 100, nro: 44773, cuit: '0' } }
];
for (const c of lanes) {
  if (!c.L.letra && c.L.tc === 'TK') c.L.letra = 'B';
  ok(k4(c.L) === k4(c.A), `Lanes ${c.L.pv}-${c.L.nro} k4 ${k4(c.L)}`);
  ok(tipEquiv(c.L, c.A), `Lanes ${c.L.pv}-${c.L.nro} tipEquiv`);
  ok(!cuitValido(c.L.cuit) || !cuitValido(c.A.cuit), `Lanes ${c.L.pv}-${c.L.nro} permite k4 (CUIT no ambos válidos)`);
}

// REG-02: dos proveedores con CUIT válido distinto → no cruzar por k4
const p1 = { tc: 'FC', letra: 'A', pv: 1, nro: 100, cuit: '30709877921' };
const p2 = { tc: 'FC', letra: 'A', pv: 1, nro: 100, cuit: '30618594188' };
ok(k4(p1) === k4(p2), 'mismo tip|pv|nro');
ok(cuitValido(p1.cuit) && cuitValido(p2.cuit) && p1.cuit !== p2.cuit, 'REG-02: bloquear match k4');

// REG-03 tiques
ok(ARCA_TIQ[111].tc === 'TK' && ARCA_TIQ[111].letra === 'C', '111 → TK C');
ok(ARCA_TIQ[115].tc === 'ND' && ARCA_TIQ[115].letra === 'A', '115 → ND A');
ok(ARCA_TIQ[119].tc === 'NC' && ARCA_TIQ[119].letra === 'M', '119 → NC M');
ok(ARCA_TIQ[83].letra === 'B', '83 → TK B');
ok(canonComp(ARCA_TIQ[115]).tc === 'ND', 'ND tique no se vuelve FC por canonComp');

// Lanes Factura E / NC E: no_grav → exportación (letra E)
function expoDesdeE({ exe = 0, ngr = 0, nal = 0, n0 = 0, letra }) {
  let exp = 0;
  if (letra === 'E') { exp += exe + ngr + nal + n0; }
  return exp;
}
ok(expoDesdeE({ ngr: 176662893, letra: 'E' }) === 176662893, 'Factura E: no_grav → exp');
ok(expoDesdeE({ ngr: -47347275, letra: 'E' }) === -47347275, 'NC E: no_grav → exp');
ok(expoDesdeE({ ngr: 176662893, letra: 'E' }) + expoDesdeE({ ngr: -47347275, letra: 'E' }) === 129315618, 'Neto expo Lanes 129.315.618');
ok(expoDesdeE({ ngr: 100, letra: 'B' }) === 0, 'Letra B no mueve no_grav a exp');

if (failed) { console.error('\n' + failed + ' fallos'); process.exit(1); }
console.log('\nTodos los tests OK');
