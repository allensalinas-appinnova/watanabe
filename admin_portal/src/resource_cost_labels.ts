/** Explain server diagnostics without suggesting that unknown costs are zero. */
export function costReasonLabel(reason: string): string {
  const labels: Record<string, string> = {
    'measurement-unavailable': 'Faltan unidades reportadas o una fecha válida',
    'measurement-invalid': 'La medición no permite calcular un importe válido',
    'tariff-unavailable': 'Falta una tarifa vigente para este componente',
    'tariff-ambiguous': 'Hay tarifas vigentes en conflicto; se requiere revisión',
    'resource-location-unverified': 'Falta confirmar la ubicación del recurso; no se usa la región de la Function',
    'shared-compute-unattributed': 'CPU y memoria compartidas sin atribución por usuario',
    'legacy-query-measurement-incomplete': 'Consultas anteriores sin medición completa',
    'legacy-write-measurement-incomplete': 'Escrituras anteriores sin distinguir eliminaciones',
    'billing-route-unverified': 'Operaciones y transferencias sin ruta de facturación verificada',
    'advisory-not-billable-reads': 'Observaciones del cliente que no equivalen a lecturas facturadas',
    'service-unpriced': 'Servicio todavía sin valoración',
    'billing-export-not-configured': 'Exportación de facturación sin configurar',
    'billing-export-awaiting-data': 'Esperando datos de la exportación de facturación',
    'billing-query-unavailable': 'No se pudo actualizar la conciliación de facturación',
  };
  const parts = reason.split(':');
  const label = labels[parts.at(-1) ?? ''] ?? 'Componente pendiente de confirmar';
  return parts.length > 1 ? `${parts[0]} · ${label}` : label;
}
