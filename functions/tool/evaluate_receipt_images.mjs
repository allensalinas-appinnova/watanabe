import sharp from 'sharp';
import {writeFile,mkdir} from 'node:fs/promises';
import {analyzeReceipt} from '../lib/document_ai.js';
if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FUNCTIONS_EMULATOR)throw Error('Synthetic production provider qualification only');
const rows=[];
for(const [i,locale] of ['es','en','pt'].entries()){
 const amount=48000+i*1000;
 const lines=['SYNTHETIC QA RECEIPT',`QA Market ${i+1}`,'2026-10-20',`Subtotal COP ${amount-1000}`,'Tax COP 1000',`TOTAL PAID COP ${amount}`,'Debit card **** 1234'];
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600"><rect width="100%" height="100%" fill="white"/><g fill="black" font-size="28" font-family="sans-serif">${lines.map((x,n)=>`<text x="40" y="${60+n*65}">${x}</text>`).join('')}</g></svg>`;
 const bytes=await sharp(Buffer.from(svg)).png().toBuffer(),start=Date.now();
 try{const r=await analyzeReceipt(bytes,'image/png',{locale,categories:[{id:'food',name:'Groceries'}]});rows.push({locale,format:'png',latencyMs:Date.now()-start,correct:{supported:r.extraction.supported===true,amount:r.extraction.amountMinor===amount,currency:r.extraction.currency==='COP',date:r.extraction.date==='2026-10-20'},usage:r.usage,model:r.model});}
 catch(e){rows.push({locale,format:'png',errorCode:e.status??e.code??'provider-failed',latencyMs:Date.now()-start});}
 console.log(JSON.stringify(rows.at(-1)));if(i<2)await new Promise(r=>setTimeout(r,13000));
}
await mkdir('artifacts/receipt-evaluation',{recursive:true});await writeFile('artifacts/receipt-evaluation/images.json',JSON.stringify(rows,null,2));
