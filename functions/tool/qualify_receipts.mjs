import {mkdir, readFile, writeFile, rename, open, unlink} from 'node:fs/promises';
import {resolve, dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {analyzeReceipt} from '../lib/document_ai.js';
import {validateExtraction} from '../lib/document_imports.js';
import {evaluateUsageEventCost} from '../lib/resource_costs.js';
import {REVIEWED_RESOURCE_TARIFFS} from '../lib/resource_tariffs.js';
import {suiteVersion, categories, accounts, instruments, evaluationCases, renderCase, scoreExtraction, summarizeEvaluation} from './receipt_evaluation_cases.mjs';

export function providerFailureCode(error) {
  const value = Number(error?.status ?? error?.code);
  return [400, 401, 403, 404, 408, 429, 500, 502, 503, 504].includes(value) ? `http-${value}` : 'provider-failed';
}

export async function qualifyReceipts({output, live = false, analyzer = analyzeReceipt, delayMs = 1000}) {
  if (!live || process.env.GCLOUD_PROJECT !== 'lumiomoney' || process.env.FUNCTIONS_EMULATOR ||
      process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('explicit-live-synthetic-qualification-required');
  const cases = evaluationCases();
  const model = process.env.DOCUMENT_AI_MODEL ?? 'gemini-3.8-flash';
  const region = process.env.DOCUMENT_AI_LOCATION ?? 'global';
  const fingerprint = createHash('sha256').update(JSON.stringify({suiteVersion, cases, model, region})).digest('hex');
  const file = resolve(output);
  await mkdir(dirname(file), {recursive: true});
  const lock = await open(`${file}.lock`, 'wx', 0o600);
  try {
    let report = {suiteVersion, fingerprint, project: 'lumiomoney', model, region, synthetic: true,
      attribution: 'shared-qualification', userQuotaAffected: false, startedAt: new Date().toISOString(), results: []};
    try {
      const existing = JSON.parse(await readFile(file, 'utf8'));
      if (existing.fingerprint !== fingerprint || !Array.isArray(existing.results) ||
          new Set(existing.results.map(r => r.id)).size !== existing.results.length ||
          existing.results.some(row => !cases.some(c => c.id === row.id))) throw Error('qualification-resume-mismatch');
      report = existing;
      report.results = report.results.map(row => row.status === 'in-flight' ? {...row,
        status: 'technical-failure', errorCode: 'interrupted-attempt', latencyMs: null,
        cost: {knownSubtotalUsd: null, complete: false, pendingReasons: ['provider-usage-unavailable']}} : row);
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
    const save = async () => {
      report.summary = summarizeEvaluation(report.results, cases.length);
      report.updatedAt = new Date().toISOString();
      await writeFile(`${file}.tmp`, JSON.stringify(report, null, 2), {mode: 0o600});
      await rename(`${file}.tmp`, file);
    };
    await save();
    for (const fixture of cases) {
      // A recorded failure is an attempt too; restarting never silently retries it.
      if (report.results.some(row => row.id === fixture.id)) continue;
      const {bytes, mime, sha256} = await renderCase(fixture);
      const at = new Date();
      const checkpointIndex = report.results.length;
      report.results.push({id: fixture.id, locale: fixture.locale, scenario: fixture.scenario, mime,
        sha256, startedAt: at.toISOString(), latencyMs: 0, status: 'in-flight',
        cost: {knownSubtotalUsd: null, complete: false, pendingReasons: ['provider-usage-unavailable']}});
      await save();
      let row;
      try {
        const response = await analyzer(bytes, mime, {locale: fixture.locale, categories});
        const extraction = validateExtraction(response.extraction, categories, accounts, instruments);
        const usage = Object.fromEntries(Object.entries(response.usage).filter(([key, value]) =>
          ['inputTokens', 'outputTokens', 'cachedTokens', 'thinkingTokens', 'totalTokens'].includes(key) &&
          Number.isSafeInteger(value) && value >= 0));
        const units = {...usage,
          ...(typeof usage.inputTokens === 'number' ? {billableInputTokens: Math.max(0, usage.inputTokens - (usage.cachedTokens ?? 0))} : {}),
          ...(typeof usage.outputTokens === 'number' ? {billableOutputTokens: usage.outputTokens + (usage.thinkingTokens ?? 0)} : {}),
        };
        const cost = evaluateUsageEventCost({service: 'ai', model: response.model, region,
          createdAt: {toDate: () => at}, units}, REVIEWED_RESOURCE_TARIFFS);
        row = {status: 'response', model: response.model, usage, cost,
          score: scoreExtraction(fixture.expected, extraction),
          category: {assessed: !!fixture.expectedCategory, correct: fixture.expectedCategory ? extraction.categoryId === fixture.expectedCategory : null},
          account: {assessed: !!fixture.expectedAccount, correct: fixture.expectedAccount ? extraction.accountId === fixture.expectedAccount : null},
          warnings: extraction.warnings};
      } catch (error) {
        row = {status: 'technical-failure', errorCode: providerFailureCode(error),
          cost: {knownSubtotalUsd: null, complete: false, pendingReasons: ['provider-usage-unavailable']}};
      }
      report.results[checkpointIndex] = {id: fixture.id, locale: fixture.locale, scenario: fixture.scenario, mime,
        sha256, startedAt: at.toISOString(), latencyMs: Date.now() - at.getTime(), ...row};
      await save();
      // No document bytes, extracted merchant/details, account identifiers or tokens in logs.
      console.log(JSON.stringify({case: fixture.id, status: row.status, exact: row.score?.exact ?? null,
        latencyMs: report.results.at(-1).latencyMs}));
      if (delayMs) await new Promise(r => setTimeout(r, delayMs));
    }
    return report.summary;
  } finally { await lock.close(); await unlink(`${file}.lock`); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const output = process.argv.find(a => a.startsWith('--output='))?.slice('--output='.length);
  try {
    if (!output) throw Error('explicit-output-required');
    console.log(JSON.stringify(await qualifyReceipts({output, live: process.argv.includes('--live')})));
  } catch (error) {
    // Never print provider messages which may contain source documents or credentials.
    console.error(JSON.stringify({issue: 'qualification-failed', code: providerFailureCode(error)}));
    process.exitCode = 1;
  }
}
