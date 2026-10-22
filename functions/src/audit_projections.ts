import {mkdirSync, realpathSync, writeFileSync} from "node:fs";
import {basename, dirname, join, resolve} from "node:path";
import {parseArgs} from "node:util";
import {deleteApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {auditExitCode, auditProjections} from "./projection_audit";
import {validId} from "./projection_model";

// Reports can contain financial values. Keep them under this Git-ignored folder.
const reportRoot = resolve(__dirname, "..", "..", ".local", "projection-audits");

async function main(): Promise<void> {
  const {values} = parseArgs({options: {
    project: {type: "string"}, user: {type: "string"}, output: {type: "string"},
  }, strict: true, allowPositionals: false});
  if (!values.project || !/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(values.project) || !validId(values.user)) {
    throw new Error("invalid_arguments");
  }
  if (process.env.FIRESTORE_EMULATOR_HOST && !values.project.startsWith("demo-")) throw new Error("emulator_requires_demo_project");
  if (values.project.startsWith("demo-") && !process.env.FIRESTORE_EMULATOR_HOST) throw new Error("demo_requires_emulator");
  let output: string | undefined;
  if (values.output !== undefined) {
    // Filename only: path traversal and writing reports into tracked directories are refused.
    if (values.output !== basename(values.output) || !/^[a-zA-Z0-9][a-zA-Z0-9_.-]*\.json$/.test(values.output)) throw new Error("invalid_output");
    mkdirSync(reportRoot, {recursive: true, mode: 0o700});
    if (realpathSync(reportRoot) !== reportRoot) throw new Error("invalid_output_directory");
    output = join(reportRoot, values.output);
    if (dirname(output) !== reportRoot) throw new Error("invalid_output");
  }
  const app = initializeApp({projectId: values.project}, "projection-audit");
  try {
    const report = await auditProjections(getFirestore(app), values.user);
    if (output) writeFileSync(output, JSON.stringify(report, null, 2) + "\n", {flag: "wx", mode: 0o600});
    console.log(JSON.stringify({complete: report.complete, ...report.counts}));
    process.exitCode = auditExitCode(report);
  } finally {
    await deleteApp(app);
  }
}

main().catch(() => {
  // SDK exception messages can contain document contents, paths and credentials.
  console.error(JSON.stringify({complete: false, errors: 1}));
  process.exitCode = 1;
});
