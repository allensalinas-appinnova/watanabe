import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {evaluationCases, renderCase, scoreExtraction, summarizeEvaluation} from '../tool/receipt_evaluation_cases.mjs';
import {qualifyReceipts, providerFailureCode} from '../tool/qualify_receipts.mjs';

test('30 synthetic multilingual cases cover three formats and exclusions', async () => {
  const cases = evaluationCases();
  assert.equal(cases.length, 30);
  assert.equal(new Set(cases.map(c => c.id)).size, 30);
  for (const locale of ['es', 'en', 'pt']) assert.equal(cases.filter(c => c.locale === locale).length, 10);
  for (const format of ['pdf', 'png', 'jpeg']) {
    assert.equal(cases.filter(c => c.format === format).length, 10);
    const first = await renderCase(cases.find(c => c.format === format));
    const repeat = await renderCase(cases.find(c => c.format === format));
    assert.equal(first.sha256, repeat.sha256);
    assert.ok(first.bytes.length > 100);
  }
  assert.equal(cases.filter(c => !c.expected.supported).length, 6);
});
test('scoring treats omission as correct and invented missing values as wrong', () => {
  assert.equal(scoreExtraction({date: null}, {}).exact, true);
  assert.equal(scoreExtraction({date: null}, {date: '2026-10-20'}).exact, false);
  assert.equal(scoreExtraction({amountMinor: 12345}, {amountMinor: 123.45}).exact, false);
});
test('technical failure is not an accuracy success or zero cost', () => {
  const summary = summarizeEvaluation([
    {status: 'response', latencyMs: 5, score: {exact: false, fields: {amountMinor: false}}},
    {status: 'technical-failure', latencyMs: 100},
  ]);
  assert.equal(summary.responses, 1);
  assert.equal(summary.exactResponses, 0);
  assert.equal(summary.technicalFailures, 1);
  assert.equal(summary.knownTokenCostSubtotalUsd, null);
  assert.equal(summary.attemptsWithIncompleteCost, 2);
  assert.equal(summary.complete, false);
  assert.equal(summary.medianLatencyMs, 52.5);
  assert.equal(summary.p95LatencyMs, 100);
});
test('provider errors are restricted codes, never messages', () => {
  assert.equal(providerFailureCode({status: 403, message: 'sensitive'}), 'http-403');
  assert.equal(providerFailureCode({message: 'sensitive'}), 'provider-failed');
});
test('live runner requires explicit opt-in before any cloud request', async () => {
  await assert.rejects(qualifyReceipts({output: '/unused'}), /explicit-live/);
});
test('checkpoint resumes without repeating technical failures or completed cases', async () => {
  const prior = process.env.GCLOUD_PROJECT;
  const emulatorNames = ['FUNCTIONS_EMULATOR', 'FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST'];
  const emulators = emulatorNames.map(n => process.env[n]);
  process.env.GCLOUD_PROJECT = 'lumiomoney';
  emulatorNames.forEach(n => delete process.env[n]);
  const dir = await mkdtemp(join(tmpdir(), 'lumio-eval-'));
  const output = join(dir, 'result.json');
  let calls = 0;
  const analyzer = async () => { calls++; throw {status: 504, message: 'do not retain this'}; };
  try {
    const summary = await qualifyReceipts({output, live: true, analyzer, delayMs: 0});
    assert.equal(calls, 30);
    assert.equal(summary.technicalFailures, 30);
    const report = await readFile(output, 'utf8');
    assert.ok(!report.includes('do not retain this'));
    await qualifyReceipts({output, live: true, analyzer, delayMs: 0});
    assert.equal(calls, 30);
    const interrupted = JSON.parse(report); interrupted.results[0].status = 'in-flight';
    await writeFile(output, JSON.stringify(interrupted));
    await qualifyReceipts({output, live: true, analyzer, delayMs: 0});
    assert.equal(calls, 30);
    assert.equal(JSON.parse(await readFile(output, 'utf8')).results[0].errorCode, 'interrupted-attempt');
    await writeFile(`${output}.lock`, '');
    await assert.rejects(qualifyReceipts({output, live: true, analyzer}), {code: 'EEXIST'});
    await rm(`${output}.lock`);
    const changed = JSON.parse(report); changed.fingerprint = 'wrong';
    await writeFile(output, JSON.stringify(changed));
    await assert.rejects(qualifyReceipts({output, live: true, analyzer}), /resume-mismatch/);
  } finally {
    if (prior === undefined) delete process.env.GCLOUD_PROJECT; else process.env.GCLOUD_PROJECT = prior;
    emulatorNames.forEach((n, i) => { if (emulators[i] === undefined) delete process.env[n]; else process.env[n] = emulators[i]; });
    await rm(dir, {recursive: true, force: true});
  }
});
test('summary distinguishes required fields from category and account suggestions', () => {
  const summary = summarizeEvaluation([
    {status: 'response', locale: 'es', mime: 'image/png', latencyMs: 8,
      score: {exact: true, fields: {amountMinor: true}},
      category: {assessed: true, correct: false}, account: {assessed: true, correct: true},
      cost: {knownSubtotalUsd: 0.01, complete: false}},
    {status: 'technical-failure', locale: 'en', mime: 'application/pdf', latencyMs: null},
  ], 2);
  assert.deepEqual(summary.suggestions.category, {assessed: 1, correct: 0});
  assert.deepEqual(summary.suggestions.account, {assessed: 1, correct: 1});
  assert.equal(summary.byLocale.en.failures, 1);
  assert.equal(summary.byMime['image/png'].exact, 1);
  assert.equal(summary.knownTokenCostSubtotalUsd, 0.01);
  assert.equal(summary.attemptsWithIncompleteCost, 2);
  assert.equal(summary.medianLatencyMs, 8);
});
