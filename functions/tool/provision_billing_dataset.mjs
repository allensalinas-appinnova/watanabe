import {BigQuery} from '@google-cloud/bigquery';
const bq=new BigQuery({projectId:'lumiomoney'});const ds=bq.dataset('lumio_billing');
const retention=String(400*86400000);
const [exists]=await ds.exists();if(!exists)await ds.create({location:'US',description:'Private Cloud Billing export for operational cost reconciliation. Lumio queries always filter project.id=lumiomoney.',defaultPartitionExpirationMs:retention});
await ds.setMetadata({defaultTableExpirationMs:null,defaultPartitionExpirationMs:retention});
const [tables]=await ds.getTables();
for(const table of tables){
 const [metadata]=await table.getMetadata();
 if(table.id?.startsWith('gcp_billing_export_')&&metadata.timePartitioning)
  await table.setMetadata({expirationTime:null,timePartitioning:{...metadata.timePartitioning,expirationMs:retention}});
}
console.log(JSON.stringify({dataset:'lumiomoney.lumio_billing',existing:exists,location:'US'}));
