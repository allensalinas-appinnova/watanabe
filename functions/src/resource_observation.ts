import {AsyncLocalStorage} from "node:async_hooks";
import {getFirestore, type Firestore, type Transaction} from "firebase-admin/firestore";

export type ServerObservation = {
  transactionAttempts: number;
  documentLookups: number;
  queryDocumentResults: number;
  committedWrites: number;
  committedDocumentWrites: number;
  committedDocumentDeletes: number;
  queryReadUnits: number;
};
const context=new AsyncLocalStorage<ServerObservation>();
export function observeServerResources<T>(stats:ServerObservation,work:()=>Promise<T>) {return context.run(stats,work);}
export const newServerObservation = (): ServerObservation => ({
  transactionAttempts: 0, documentLookups: 0, queryDocumentResults: 0, committedWrites: 0,
  committedDocumentWrites: 0, committedDocumentDeletes: 0, queryReadUnits: 0,
});

/** Counts public SDK transaction calls, not billing reads, index scans or direct reference writes. */
export function observeFirestore(db:Firestore,stats:ServerObservation):Firestore {
  return new Proxy(db,{get(target,key){
    if(key!=="runTransaction") {const value=Reflect.get(target,key,target);return typeof value==="function"?value.bind(target):value;}
    return async (work:(tx:Transaction)=>Promise<unknown>,options?:unknown)=>{
      let successfulWrites=0,successfulDeletes=0;
      const result=await target.runTransaction(async real=>{
        stats.transactionAttempts++;let writes=0,deletes=0;
        const proxy=new Proxy(real,{get(tx,method){
          const value=Reflect.get(tx,method,tx);
          if(["get","getAll"].includes(String(method)))return async (...args:unknown[])=>{
            const result=await Reflect.apply(value,tx,args);
            if(Array.isArray(result))stats.documentLookups+=result.length;
            else if(result && typeof result === "object" && "docs" in result && Array.isArray(result.docs)) {
              stats.queryDocumentResults += result.docs.length;
              stats.queryReadUnits += Math.max(1, result.docs.length);
            }
            else stats.documentLookups++;
            return result;
          };
          if(["set","create","update","delete"].includes(String(method)))return (...args:unknown[])=>{
            const result=Reflect.apply(value,tx,args);
            if(method === "delete") deletes++; else writes++;
            return result===tx?proxy:result;
          };
          return typeof value==="function"?value.bind(tx):value;
        }});
        const value=await work(proxy);successfulWrites=writes;successfulDeletes=deletes;return value;
      },options as Parameters<Firestore["runTransaction"]>[1]);
      stats.committedWrites += successfulWrites + successfulDeletes;
      stats.committedDocumentWrites += successfulWrites;
      stats.committedDocumentDeletes += successfulDeletes;
      return result;
    };
  }});
}
export function meteredFirestore():Firestore {const stats=context.getStore();return stats?observeFirestore(getFirestore(),stats):getFirestore();}
