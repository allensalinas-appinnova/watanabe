package co.appinnova.lumio.qa.sender;
import android.content.*;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.*;
public final class ReceiptProvider extends ContentProvider {
  private File file(Uri uri) throws FileNotFoundException {
    String name=uri.getLastPathSegment();
    if (!"receipt.pdf".equals(name)&&!"receipt.png".equals(name)) throw new FileNotFoundException();
    return new File(getContext().getCacheDir(),name);
  }
  @Override public boolean onCreate(){return true;}
  @Override public String getType(Uri u){return u.toString().endsWith("pdf")?"application/pdf":"image/png";}
  @Override public ParcelFileDescriptor openFile(Uri u,String mode)throws FileNotFoundException {
    if (!"r".equals(mode))throw new FileNotFoundException();
    return ParcelFileDescriptor.open(file(u),ParcelFileDescriptor.MODE_READ_ONLY);
  }
  @Override public Cursor query(Uri u,String[] projection,String selection,String[] args,String sort){
    MatrixCursor c=new MatrixCursor(new String[]{OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE});
    try{File f=file(u);c.addRow(new Object[]{f.getName(),f.length()});}catch(Exception e){} return c;
  }
  @Override public Uri insert(Uri u,ContentValues v){throw new UnsupportedOperationException();}
  @Override public int update(Uri u,ContentValues v,String s,String[] a){throw new UnsupportedOperationException();}
  @Override public int delete(Uri u,String s,String[] a){throw new UnsupportedOperationException();}
}
