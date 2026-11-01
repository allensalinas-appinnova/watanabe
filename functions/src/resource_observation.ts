import {AsyncLocalStorage} from "node:async_hooks";
import {getFirestore, type Firestore, type Transaction} from "firebase-admin/firestore";

export type ServerObservation = {transactionAttempts:number; documentLookups:number; queryDocumentResults:number; committedWrites:number};
const context=new AsyncLocalStorage<ServerObservation>();
export function observeServerResources<T>(stats:ServerObservation,work:()=>Promise<T>) {return context.run(stats,work);}
export const newServerObservation=():ServerObservation=>({transactionAttempts:0,documentLookups:0,queryDocumentResults:0,committedWrites:0});

/** Counts public SDK transaction calls, not billing reads, index scans or direct reference writes. */
export function observeFirestore(db:Firestore,stats:ServerObservation):Firestore {
  return new Proxy(db,{get(target,key){
    if(key!=="runTransaction") {const value=Reflect.get(target,key,target);return typeof value==="function"?value.bind(target):value;}
    return async (work:(tx:Transaction)=>Promise<unknown>,options?:unknown)=>{
      let successfulWrites=0;
      const result=await target.runTransaction(async real=>{
        stats.transactionAttempts++;let writes=0;
        const proxy=new Proxy(real,{get(tx,method){
          const value=Reflect.get(tx,method,tx);
          if(["get","getAll"].includes(String(method)))return async (...args:unknown[])=>{
            const result=await Reflect.apply(value,tx,args);
            if(Array.isArray(result))stats.documentLookups+=result.length;
            else if(result && typeof result === "object" && "docs" in result && Array.isArray(result.docs))stats.queryDocumentResults+=result.docs.length;
            else stats.documentLookups++;
            return result;
          };
          if(["set","create","update","delete"].includes(String(method)))return (...args:unknown[])=>{
            const result=Reflect.apply(value,tx,args);writes++;return result===tx?proxy:result;
          };
          return typeof value==="function"?value.bind(tx):value;
        }});
        const value=await work(proxy);successfulWrites=writes;return value;
      },options as Parameters<Firestore["runTransaction"]>[1]);
      stats.committedWrites+=successfulWrites;return result;
    };
  }});
}
export function meteredFirestore():Firestore {const stats=context.getStore();return stats?observeFirestore(getFirestore(),stats):getFirestore();}
