import assert from 'node:assert/strict';
import test from 'node:test';
import {costReasonLabel} from '../src/resource_cost_labels.ts';
test('pending component reasons and billing states have a conservative readable fallback',()=>{
 assert.match(costReasonLabel('ai:billableOutputTokens:measurement-unavailable'),/^ai · Faltan unidades/);
 assert.match(costReasonLabel('functions:compute:shared-compute-unattributed'),/CPU y memoria compartidas/);
 assert.match(costReasonLabel('billing-export-awaiting-data'),/Esperando datos/);
 assert.equal(costReasonLabel('new-unknown-reason'),'Componente pendiente de confirmar');
});
