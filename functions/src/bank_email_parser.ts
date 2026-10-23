import {Parser} from "htmlparser2";

export type SupportedBank = "bancolombia" | "davivienda";
export type BankEmailExtraction = {
  status: "supported" | "needs-review" | "unsupported";
  bank: SupportedBank; formatVersion: string | null;
  suggestion: Record<string, string | number>;
  warnings: string[]; evidence: string;
  accountHint?: {kind: "debit-card"; suffix: string};
};
const senders: Record<SupportedBank, readonly string[]> = {
  bancolombia: ["alertasynotificaciones@ayn.notificacionesbancolombia.com"],
  davivienda: ["bancodavivienda@davivienda.com", "banco_davivienda@davivienda.com"],
};

/** Parses inert text only. Saved Outlook pages must isolate the selected body. */
export function bankEmailText(body: string, html: boolean): string | null {
  if (body.length > 512_000) return null;
  if (!html) return body.replace(/\s+/gu, " ").trim();
  const exportedPage = /UniqueMessageBody_|owa\.mail|outlook\.office/iu.test(body);
  let depth = 0;
  let selectedDepth = -1;
  let ignoredDepth = -1;
  let selectedFound = false;
  const text: string[] = [];
  const parser = new Parser({
    onopentag(name, attributes) {
      depth++;
      if (ignoredDepth === -1 && ["script", "style", "iframe", "object", "noscript", "template"].includes(name)) ignoredDepth = depth;
      if (selectedDepth === -1 && /^UniqueMessageBody_/u.test(attributes.id ?? "")) {
        selectedDepth = depth;
        selectedFound = true;
      }
      if (ignoredDepth === -1 && (!exportedPage || selectedDepth !== -1) &&
          ["br", "p", "div", "td", "tr", "li"].includes(name)) text.push(" ");
    },
    ontext(value) {
      if (ignoredDepth === -1 && (!exportedPage || selectedDepth !== -1)) text.push(value);
    },
    onclosetag() {
      if (depth === ignoredDepth) ignoredDepth = -1;
      if (depth === selectedDepth) selectedDepth = -1;
      depth--;
    },
  }, {decodeEntities: true});
  parser.end(body);
  if (exportedPage && !selectedFound) return null;
  return text.join(" ").replace(/\s+/gu, " ").trim();
}

function copAmount(value: string, european: boolean): number | null {
  let integer = value;
  if (european) {
    if (!/^\d{1,3}(?:\.\d{3})*(?:,00)?$|^\d+(?:,00)?$/u.test(value)) return null;
    integer = value.replace(/,00$/u, "").replaceAll(".", "");
  } else {
    if (!/^\d{1,3}(?:,\d{3})*$|^\d+$/u.test(value)) return null;
    integer = value.replaceAll(",", "");
  }
  const amount = Number(integer);
  return Number.isSafeInteger(amount) && amount > 0 && amount <= 1_000_000_000 ? amount : null;
}

function localDate(year: string, month: string, day: string, time: string, now: Date): string | null {
  const local = `${year}-${month}-${day}T${time.length === 5 ? `${time}:00` : time}`;
  // These specific Colombian bank templates use local Colombia time. Never
  // substitute the email arrival date or the device time zone.
  const date = new Date(`${local}-05:00`);
  if (!Number.isFinite(date.getTime()) || date.getTime() > now.getTime() ||
      date.getTime() < Date.UTC(2000, 0, 1)) return null;
  const roundtrip = new Date(date.getTime() - 5 * 3600000).toISOString().slice(0, 19);
  return roundtrip === local ? date.toISOString() : null;
}

export function parseBankEmail(input: {
  bank: SupportedBank; sender: string; body: string; html?: boolean;
  senderAuthenticated?: boolean; now?: Date;
}): BankEmailExtraction {
  const result: BankEmailExtraction = {status: "unsupported", bank: input.bank,
    formatVersion: null, suggestion: {}, warnings: [], evidence: ""};
  if (!senders[input.bank]?.includes(input.sender.toLowerCase().trim())) {
    return {...result, warnings: ["sender-not-supported"]};
  }
  const text = bankEmailText(input.body, input.html === true);
  if (!text) return {...result, warnings: ["message-body-missing"]};
  // Restrict safety classification to the actual transaction and its heading,
  // not the bank's general security footer (which may mention credit cards).
  const unsafeMovement = (match: RegExpMatchArray) =>
    /rechazad|declinad|revers[oa]|anulad|retiraste|retiro|tarjeta de cr[eé]dito|T\.Cr[eé]d/iu
      .test(text.slice(Math.max(0, (match.index ?? 0) - 160), (match.index ?? 0) + match[0].length));
  let occurredAt: string | null = null;
  let amount: number | null = null;
  let description = "";
  const now = input.now ?? new Date();
  if (input.bank === "bancolombia") {
    const expression = /Bancolombia:\s*Compraste\s+\$([\d.,]+)\s+en\s+(.{1,160}?)\s+con tu T\.Deb\s+\*(\d{4}),\s+el\s+(\d{2})\/(\d{2})\/(\d{4})\s+a las\s+(\d{2}:\d{2})\./gu;
    const matches = [...text.matchAll(expression)];
    if (matches.length !== 1) return {...result, warnings: [matches.length > 1 ? "multiple-movements" : "format-not-supported"]};
    const match = matches[0];
    if (unsafeMovement(match)) return {...result, warnings: ["movement-needs-manual-entry"]};
    amount = copAmount(match[1], true);
    description = match[2];
    occurredAt = localDate(match[6], match[5], match[4], match[7], now);
    result.formatVersion = "bancolombia_debit_purchase_v1";
    result.suggestion.type = "expense";
    result.accountHint = {kind: "debit-card", suffix: match[3]};
    // Do not retain the debit-card suffix, service telephone numbers or footer
    // in the evidence snippet. Account association is an explicit user choice.
    result.evidence = `Bancolombia: Compraste $${match[1]} en ${description}, el ${match[4]}/${match[5]}/${match[6]} a las ${match[7]}.`;
  } else {
    const expression = /Fecha:\s*(\d{4})\/(\d{2})\/(\d{2})\s+Hora:\s*(\d{2}:\d{2}:\d{2})\s+Valor Transacci[oó]n:\s*\$([\d.,]+)\s+Clase de Movimiento:\s*(Descuento Compra con llave|Abono Transferencia),?\s+Lugar de Transacci[oó]n:\s*(.{1,160}?)\s+Atentamente,/gu;
    const matches = [...text.matchAll(expression)];
    if (matches.length !== 1) return {...result, warnings: [matches.length > 1 ? "multiple-movements" : "format-not-supported"]};
    const match = matches[0];
    if (unsafeMovement(match)) return {...result, warnings: ["movement-needs-manual-entry"]};
    amount = copAmount(match[5], false);
    occurredAt = localDate(match[1], match[2], match[3], match[4], now);
    description = match[7];
    result.formatVersion = match[6] === "Abono Transferencia" ?
      "davivienda_transfer_credit_v1" : "davivienda_key_purchase_v1";
    if (match[6] === "Abono Transferencia") result.warnings.push("transfer-type-review-required");
    else result.suggestion.type = "expense";
    result.evidence = `Fecha: ${match[1]}/${match[2]}/${match[3]} Hora: ${match[4]} Valor Transacción: $${match[5]} Clase de Movimiento: ${match[6]} Lugar de Transacción: ${description}`;
  }
  if (amount !== null) Object.assign(result.suggestion, {amountMinor: amount, currency: "COP"});
  else result.warnings.push("amount-review-required");
  if (occurredAt !== null) result.suggestion.occurredAt = occurredAt;
  else result.warnings.push("date-review-required");
  description = description.replace(/[<>\u0000-\u001f]/gu, "").trim();
  result.suggestion.description = description;
  result.evidence = result.evidence.replace(/[<>\u0000-\u001f]/gu, "").slice(0, 600);
  if (!input.senderAuthenticated) result.warnings.push("sender-authentication-unverified");
  result.warnings.push("account-selection-required", "category-selection-required");
  // Even a supported extraction is never a confirmed financial operation.
  result.status = amount !== null && occurredAt !== null && result.suggestion.type !== undefined ? "supported" : "needs-review";
  return result;
}
