package co.appinnova.lumio.qa.sender;
import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.content.ClipData;
import android.net.Uri;
import java.io.*;
public final class MainActivity extends Activity {
  @Override public void onCreate(Bundle state) {
    super.onCreate(state);
    String kind = getIntent().getStringExtra("kind");
    String name = "pdf".equals(kind) ? "receipt.pdf" : "receipt.png";
    try (InputStream input = getAssets().open(name); OutputStream out = new FileOutputStream(new File(getCacheDir(),name))) {
      byte[] buffer = new byte[8192]; int n; while ((n=input.read(buffer))!=-1) out.write(buffer,0,n);
    } catch(IOException e) { throw new IllegalStateException("Synthetic fixture unavailable",e); }
    Intent send = new Intent(Intent.ACTION_SEND);
    send.setType(name.endsWith("pdf")?"application/pdf":"image/png");
    Uri uri=Uri.parse("content://co.appinnova.lumio.qa.sender.receipts/"+name);
    send.putExtra(Intent.EXTRA_STREAM,uri);
    send.setClipData(ClipData.newUri(getContentResolver(),"QA receipt",uri));
    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
    startActivity(Intent.createChooser(send,"QA receipt"));
    // Keep the grant-owning activity alive until the receiving app copies its URI.
  }
}
