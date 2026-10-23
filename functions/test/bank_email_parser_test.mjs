import assert from 'node:assert/strict';
import test from 'node:test';
import {bankEmailText, parseBankEmail} from '../lib/bank_email_parser.js';

// Manually synthesized from the structures observed in the supplied exports.
// No original HTML, amounts, dates, merchants, names or account digits copied.
const now = new Date('2026-10-22T20:00:00Z');
const purchase = 'Bancolombia: Compraste $12.345,00 en TIENDA SINTETICA con tu T.Deb *9876, el 20/10/2026 a las 09:12. Si tienes dudas, encuentranos aqui: 0000000000.';
const davivienda = (kind = 'Descuento Compra con llave') => `Fecha: 2026/10/20 Hora: 13:14:15 Valor Transacción: $123,456 Clase de Movimiento: ${kind} Lugar de Transacción: COMERCIO SINTETICO Atentamente, BANCO DAVIVIENDA S.A.`;
const bc = (body, extra = {}) => parseBankEmail({bank: 'bancolombia', sender: 'alertasynotificaciones@ayn.notificacionesbancolombia.com', body, now, ...extra});
const dv = (body, extra = {}) => parseBankEmail({bank: 'davivienda', sender: 'BANCO_DAVIVIENDA@davivienda.com', body, now, ...extra});

test('debit purchase extracts exact COP units, Colombia date and a card hint, not an account ID', () => {
  const result = bc(purchase);
  assert.equal(result.status, 'supported');
  assert.equal(result.formatVersion, 'bancolombia_debit_purchase_v1');
  assert.deepEqual(result.suggestion, {type: 'expense', amountMinor: 12345, currency: 'COP',
    occurredAt: '2026-10-20T14:12:00.000Z', description: 'TIENDA SINTETICA'});
  assert.deepEqual(result.accountHint, {kind: 'debit-card', suffix: '9876'});
  assert.equal(result.suggestion.accountId, undefined);
  assert(!result.evidence.includes('9876'));
  assert(!result.evidence.includes('0000000000'));
  assert(result.warnings.includes('sender-authentication-unverified'));
});

test('Davivienda key purchase uses comma thousands without changing the amount', () => {
  const result = dv(davivienda());
  assert.equal(result.status, 'supported');
  assert.equal(result.suggestion.amountMinor, 123456);
  assert.equal(result.suggestion.occurredAt, '2026-10-20T18:14:15.000Z');
  assert.equal(result.suggestion.type, 'expense');
});

test('transfer credit requires type review; it is not automatically income', () => {
  const result = dv(davivienda('Abono Transferencia,'));
  assert.equal(result.status, 'needs-review');
  assert.equal(result.suggestion.type, undefined);
  assert(result.warnings.includes('transfer-type-review-required'));
  assert.equal(result.suggestion.amountMinor, 123456);
});

test('rejects unrecognized senders, suspicious movements and malformed monetary groups', () => {
  assert.equal(bc(purchase, {sender: 'attacker@example.test'}).status, 'unsupported');
  for (const prefix of ['Compra rechazada ', 'Reverso ', 'Retiro ', 'Tarjeta de crédito ']) {
    assert.equal(bc(prefix + purchase).status, 'unsupported');
  }
  for (const amount of ['0', '1.23,00', '12.345,67', '1.000.000.001,00']) {
    const result = bc(purchase.replace('12.345,00', amount));
    assert.equal(result.status, 'needs-review');
    assert.equal(result.suggestion.amountMinor, undefined);
  }
});

test('invalid or future dates need correction and never fall back to email receipt date', () => {
  for (const date of ['30/02/2026', '23/10/2026']) {
    const result = bc(purchase.replace('20/10/2026', date));
    assert.equal(result.suggestion.occurredAt, undefined);
    assert(result.warnings.includes('date-review-required'));
  }
});

test('generic security footer mentioning credit cards does not misclassify a debit purchase', () => {
  const result = bc(`${purchase} Tu seguridad es nuestra prioridad. Tarjeta de crédito: no compartas tu clave.`);
  assert.equal(result.status, 'supported');
  assert.equal(result.suggestion.type, 'expense');
});

test('saved Outlook pages isolate the selected message; inbox previews are not transactions', () => {
  const html = `<html><link href="owa.mail.css"><div>${purchase}</div><div id="UniqueMessageBody_1"><p>${davivienda()}</p></div><div>${purchase}</div></html>`;
  const result = dv(html, {html: true});
  assert.equal(result.status, 'supported');
  assert.equal(result.suggestion.amountMinor, 123456);
  assert.equal(bc(`<link href="owa.mail.css"><div>${purchase}</div>`, {html: true}).status, 'unsupported');
});

test('HTML is inert, entities decode, external content is not followed, multiple rows are not guessed', () => {
  const html = `<script>${purchase}</script><style>${purchase}</style><iframe src="https://example.test">${purchase}</iframe><p>${purchase.replace('TIENDA SINTETICA', 'TIENDA &amp; HIJOS')}</p>`;
  const result = bc(html, {html: true});
  assert.equal(result.status, 'supported');
  assert.equal(result.suggestion.description, 'TIENDA & HIJOS');
  assert.equal(bc(`${purchase} ${purchase}`).status, 'unsupported');
  assert.equal(bankEmailText('x'.repeat(512001), true), null);
});
