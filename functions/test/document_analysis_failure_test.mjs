import {test} from 'node:test';
import assert from 'node:assert/strict';
import {documentAnalysisIssue,isDocumentAnalysisIssue} from '../lib/document_analysis_failure.js';

test('analysis errors expose only safe categories',()=>{
  for(const status of [429,503]) assert.equal(documentAnalysisIssue({status}),'document-service-busy');
  for(const status of [408,504]) assert.equal(documentAnalysisIssue({code:status}),'document-analysis-timeout');
  assert.equal(documentAnalysisIssue({name:'AbortError'}),'document-analysis-timeout');
  for(const error of [null,undefined,{status:401,message:'document-service-busy'},new Error('private document text')]) {
    assert.equal(documentAnalysisIssue(error),'document-analysis-failed');
  }
  assert.equal(isDocumentAnalysisIssue('document-analysis-timeout'),true);
  assert.equal(isDocumentAnalysisIssue('private-provider-message'),false);
});
