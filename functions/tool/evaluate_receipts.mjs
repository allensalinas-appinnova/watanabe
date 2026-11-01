import {PDFDocument,StandardFonts} from 'pdf-lib';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {analyzeReceipt} from '../lib/document_ai.js';
const count=Number(process.env.RECEIPT_EVAL_COUNT??30);
if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FUNCTIONS_EMULATOR)throw Error('Explicit production project required, synthetic provider qualification only.');
const startIndex=Number(process.env.RECEIPT_EVAL_START??0);
const results=startIndex ? JSON.parse(await readFile('artifacts/receipt-evaluation/results.json','utf8')).results.filter(x=>x.case<=startIndex) : [];
for(let i=startIndex;i<count;i++) {
 if(i>startIndex) await new Promise(r=>setTimeout(r,13000));
 const locale=['es','en','pt'][i%3], amount=25000+i*1000;
 const labels={es:['COMPROBANTE SINTETICO QA','Fecha','Subtotal','Impuesto','TOTAL PAGADO'],en:['SYNTHETIC QA RECEIPT','Date','Subtotal','Tax','TOTAL PAID'],pt:['RECIBO SINTETICO QA','Data','Subtotal','Imposto','TOTAL PAGO']}[locale];
 const doc=await PDFDocument.create();const page=doc.addPage([420,380]);const font=await doc.embedFont(StandardFonts.Helvetica);
 const lines=[labels[0],`QA Market ${i+1}`,`${labels[1]}: 2026-10-20`,`${labels[2]}: COP ${amount-1000}`,`${labels[3]}: COP 1000`,`${labels[4]}: COP ${amount}`,'Visa debito **** 1234','Documento ficticio - no es una compra real'];
 lines.forEach((x,n)=>page.drawText(x,{x:25,y:340-n*35,font,size:13}));
 const bytes=Buffer.from(await doc.save());const start=Date.now();
 try{const r=await analyzeReceipt(bytes,'application/pdf',{locale,categories:[{id:'food',name:'Alimentos / Groceries / Alimentacao'}]});
 results.push({case:i+1,locale,latencyMs:Date.now()-start,correct:{supported:r.extraction.supported===true,amount:r.extraction.amountMinor===amount,currency:r.extraction.currency==='COP',date:r.extraction.date==='2026-10-20'},usage:r.usage,model:r.model});}
 catch(e){results.push({case:i+1,locale,errorCode:e.status??e.code??'provider-failed',latencyMs:Date.now()-start});}
 console.log(JSON.stringify(results.at(-1)));
 await mkdir('artifacts/receipt-evaluation',{recursive:true});
 await writeFile('artifacts/receipt-evaluation/results.json',JSON.stringify({synthetic:true,createdAt:new Date().toISOString(),results},null,2));
}
await mkdir('artifacts/receipt-evaluation',{recursive:true});
await writeFile('artifacts/receipt-evaluation/results.json',JSON.stringify({synthetic:true,createdAt:new Date().toISOString(),results},null,2));
