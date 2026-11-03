/** Public, bounded failure reasons. Never expose provider messages or document text. */
export type DocumentAnalysisIssue = "document-service-busy" | "document-analysis-timeout" | "document-analysis-failed";

export function documentAnalysisIssue(error: unknown): DocumentAnalysisIssue {
  const value = error as {status?: unknown; code?: unknown; name?: unknown} | null;
  const status = Number(value?.status ?? value?.code);
  if (status === 429 || status === 503) return "document-service-busy";
  if (status === 408 || status === 504 || value?.name === "AbortError" || value?.name === "TimeoutError") {
    return "document-analysis-timeout";
  }
  return "document-analysis-failed";
}

export function isDocumentAnalysisIssue(value: unknown): value is DocumentAnalysisIssue {
  return ["document-service-busy", "document-analysis-timeout", "document-analysis-failed"].includes(String(value));
}
