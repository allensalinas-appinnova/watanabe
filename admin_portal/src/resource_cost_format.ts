export function resourceMoneyUsd(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'Pendiente de confirmar';
  const format = (n: number) => new Intl.NumberFormat('es-CO', {style: 'currency', currency: 'USD', maximumFractionDigits: 6}).format(n);
  if (value > 0 && value < 0.000001) return `< ${format(0.000001)}`;
  if (value < 0 && value > -0.000001) return `> ${format(-0.000001)}`;
  return format(value);
}
