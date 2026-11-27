#!/usr/bin/env node
// REG-01 (auditoría 2026-11-27): el cruce 6 (Libro IVA Digital) tiene que sumar el IVA de las facturas T de ventas
// al Total del Crédito Fiscal, igual que la liquidación (liqCalc). Corre el código real de index.html y MyIVA.dc.html.
import assert from 'node:assert/strict';
import { cargarApp } from './app-loader.mjs';

const rec = (tc, letra, ngt, ivt) => ({ tc, letra, cuit: '30712345678', pv: 1, nro: Math.floor(Math.random() * 1e6), fecha: '15/10/2026', v: { ngt, ivt, n21: ngt, i21: ivt, tot: ngt + ivt } });
const ventas = { recs: [rec('FC', 'A', 1000000, 210000), rec('FC', 'T', 17451200, 3664752), rec('NC', 'A', 100000, 21000)] };
const compras = { recs: [rec('FC', 'A', 500000, 105000), rec('NC', 'A', 20000, 4200)] };

for (const archivo of ['index.html', 'MyIVA.dc.html']) {
  const app = cargarApp(archivo);
  app.perLiq = () => '10/2026';
  app.liqCli = () => 'CLIENTE TEST';
  app.prorrModo = () => 'general';
  app.state.cliFicha = {};

  const liq = app.liqCalc(ventas, compras, {}, false);
  const lib = { per: '10/2026', v: { tdf: liq.df, tcf: liq.cf } };   // LID que coincide con la liquidación
  const cr = app.cruzarLibro(lib, ventas, compras);
  const tcf = cr.filas.find(f => f.k === 'tcf'), tdf = cr.filas.find(f => f.k === 'tdf');

  assert.equal(cr.cfT, 3664752, archivo + ': IVA de facturas T');
  assert.equal(tcf.calc, liq.cf, archivo + ': crédito fiscal esperado del cruce 6 = crédito fiscal de la liquidación');
  assert.equal(tcf.est, 'ok', archivo + ': el Total del Crédito Fiscal coincide');
  assert.equal(tdf.calc, liq.df, archivo + ': el débito no cambia (ya incluía las T)');
  assert.ok(/Fact\. T/.test(tcf.origen), archivo + ': el origen menciona las facturas T');

  // Sin facturas T no cambia nada.
  const v2 = { recs: ventas.recs.filter(x => x.letra !== 'T') };
  const liq2 = app.liqCalc(v2, compras, {}, false);
  const cr2 = app.cruzarLibro({ per: '10/2026', v: { tdf: liq2.df, tcf: liq2.cf } }, v2, compras);
  assert.equal(cr2.cfT, 0);
  assert.equal(cr2.filas.find(f => f.k === 'tcf').calc, liq2.cf);
  console.log('ok:', archivo, '— cruce 6 suma las facturas T al crédito fiscal (', tcf.calc, ')');
}
console.log('\nTodos los tests OK');
