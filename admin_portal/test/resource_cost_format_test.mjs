import assert from 'node:assert/strict';
import test from 'node:test';
import {resourceMoneyUsd} from '../src/resource_cost_format.ts';
test('tiny nonzero storage estimates do not appear free and unknown values remain pending',()=>{
 assert.match(resourceMoneyUsd(0.000000001),/^< /);
 assert.match(resourceMoneyUsd(-0.000000001),/^> /);
 assert.doesNotMatch(resourceMoneyUsd(0),/^[<>]/);
 for(const value of [null,undefined,NaN,Infinity])assert.equal(resourceMoneyUsd(value),'Pendiente de confirmar');
 assert.match(resourceMoneyUsd(1),/1,00/);
});
