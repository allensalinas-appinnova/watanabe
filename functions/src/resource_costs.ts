import {BigQuery} from "@google-cloud/bigquery";
import {Timestamp, type Firestore} from "firebase-admin/firestore";
import type {Data} from "./resource_usage";

/** Rates are explicit USD/unit records, never an assumed zero price. */
export function priceUsageEvent(event: Data, tariffs: Data[]) {
  const at = event.createdAt.toDate().toISOString();
  const rates = tariffs.filter(t => t.service === event.service && (!t.model || t.model === event.model) &&
    (!t.region || t.region === event.region) && typeof t.effectiveFrom === "string" && Date.parse(t.effectiveFrom) <= Date.parse(at) &&
    (!t.effectiveUntil || Date.parse(t.effectiveUntil) > Date.parse(at))).sort((a,b) => b.effectiveFrom.localeCompare(a.effectiveFrom));
  const units = event.units ?? {};
  const required = event.service === "ai" ? ["billableInputTokens", "billableOutputTokens", "cachedTokens"] :
    event.service === "storage" ? Object.keys(units).filter(k => units[k] > 0) : [];
  if (!required.length || event.quality === "pending") return null;
  let amount = 0;
  for (const key of required) {
    const rate = rates.find(t => t.unit === key);
    if (!rate || typeof units[key] !== "number" || !Number.isFinite(rate.usdPerUnit) || rate.usdPerUnit < 0) return null;
    amount += units[key] * rate.usdPerUnit;
  }
  return amount;
}

export async function estimateUserCosts(db: Firestore, month = new Date().toISOString().slice(0,7)) {
  const tariffs = (await db.collection("resourceTariffs").get()).docs.map(d => ({id:d.id,...d.data()}));
  const subjects = await db.collection("resourceUsage").get();
  for (const subject of subjects.docs) {
    const events = await subject.ref.collection("events").where("createdAt", ">=", Timestamp.fromDate(new Date(`${month}-01T00:00:00Z`)))
      .where("createdAt", "<", Timestamp.fromDate(new Date(Date.UTC(Number(month.slice(0,4)),Number(month.slice(5,7)),1)))).get();
    let pricedEvents=0,amountUsd=0;
    const byService: Record<string,number>={}, days: Record<string,Data>={};
    for (const event of events.docs) {
      const d=event.data(),cost=priceUsageEvent(d,tariffs),day=d.createdAt.toDate().toISOString().slice(0,10);
      const daily=days[day]??={totalEvents:0,pricedEvents:0,knownSubtotalUsd:0,byService:{}};
      daily.totalEvents++;
      if(cost!==null) {
        pricedEvents++;amountUsd+=cost;byService[d.service]=(byService[d.service]??0)+cost;
        daily.pricedEvents++;daily.knownSubtotalUsd+=cost;daily.byService[d.service]=(daily.byService[d.service]??0)+cost;
      }
    }
    const expiry=Timestamp.fromMillis(Date.now()+400*86400000);
    await subject.ref.collection("costs").doc(month).set({quality:events.size>0&&pricedEvents===events.size?"estimated":"pending",
      amountUsd:events.size>0&&pricedEvents===events.size?amountUsd:null,knownSubtotalUsd:pricedEvents?amountUsd:null,
      byService,pricedEvents,totalEvents:events.size,coverage:events.size?pricedEvents/events.size:null,
      tariffVersions:tariffs.map(t=>t.id),updatedAt:Timestamp.now(),expiresAt:expiry});
    for(const [day,daily] of Object.entries(days)) await subject.ref.collection("costDays").doc(day).set({...daily,day,expiresAt:expiry,updatedAt:Timestamp.now()});
  }
}

function serviceKey(service: string) {
  if(/vertex|gemini|generative/i.test(service))return "ai";
  if(/firestore/i.test(service))return "firestore";
  if(/storage/i.test(service))return "storage";
  if(/functions|cloud run/i.test(service))return "functions";
  return null;
}
export async function reconcileProjectBilling(db: Firestore) {
  const table=process.env.RESOURCE_BILLING_EXPORT_TABLE??(await db.doc("servicePolicies/billing").get()).get("exportTable");
  const status=db.doc("resourceBilling/status");
  if(typeof table!=="string"||!/^[a-z][a-z0-9-]+\.[A-Za-z_][\w]*\.[A-Za-z_][\w]*$/.test(table)) {
    await status.set({available:false,issue:"billing-export-not-configured",updatedAt:Timestamp.now()});return;
  }
  try {
    const [rows]=await new BigQuery({projectId: process.env.GCLOUD_PROJECT ?? "lumiomoney"}).query({query:`SELECT DATE(usage_start_time) AS day, service.description AS service, currency,
      SUM(cost) AS grossCost, SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c),0)) AS credits
      FROM \`${table}\` WHERE project.id=@projectId AND usage_start_time>=TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 7 DAY)
      GROUP BY day,service,currency`,params:{projectId:process.env.GCLOUD_PROJECT??"lumiomoney"},maximumBytesBilled:"1000000000"});
    const users=await db.collection("resourceUsage").get();
    for(const row of rows) {
      const day=String(row.day?.value??row.day),key=serviceKey(row.service),id=Buffer.from(`${day}:${row.service}:${row.currency}`).toString("base64url");
      let knownSubtotalUsd=0,pricedUsers=0;
      if(key)for(const user of users.docs) {
        const cost=await user.ref.collection("costDays").doc(day).get();
        if(typeof cost.get(`byService.${key}`)==="number"){knownSubtotalUsd+=cost.get(`byService.${key}`);pricedUsers++;}
      }
      const netCost=Number(row.grossCost)+Number(row.credits);
      await db.doc(`resourceBilling/daily/services/${id}`).set({day,service:row.service,currency:row.currency,grossCost:Number(row.grossCost),credits:Number(row.credits),netCost,
        knownSubtotalUsd:pricedUsers?knownSubtotalUsd:null,unattributedDifferenceUsd:pricedUsers&&row.currency==="USD"?netCost-knownSubtotalUsd:null,
        quality:"provider-aggregate-with-partial-user-estimates",updatedAt:Timestamp.now()});
    }
    await status.set({available:rows.length>0,issue:rows.length?null:"billing-export-awaiting-data",quality:"provider-aggregate",updatedAt:Timestamp.now(),
      attribution:"Shared resources, credits, missing measurements and provider adjustments are not assigned blindly to users."});
  }catch(error) {
    await status.set({available:false,issue:(error as {code?:number}).code===404?"billing-export-awaiting-data":"billing-query-unavailable",updatedAt:Timestamp.now()});
  }
}
