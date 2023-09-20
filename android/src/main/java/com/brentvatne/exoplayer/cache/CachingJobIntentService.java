package com.brentvatne.exoplayer.cache;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.JobIntentService;

import com.brentvatne.exoplayer.DataSourceUtil;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.offline.Downloader;
import com.google.android.exoplayer2.offline.StreamKey;
import com.google.android.exoplayer2.source.hls.offline.HlsDownloader;
import com.google.android.exoplayer2.source.hls.playlist.HlsMultivariantPlaylist;
import com.google.android.exoplayer2.upstream.DataSpec;
import com.google.android.exoplayer2.upstream.cache.CacheWriter;

import java.util.Collections;

public class CachingJobIntentService extends JobIntentService implements CacheWriter.ProgressListener {

    private static final int JOB_ID = 1070200;
    private static final String TAG = "CachingJobIntentService";
    private static final String JOB_NAME = "CachingJobIntentService.Prefetch";
    private static final String URL = "CachingJobIntentService.URL";

    public static void enqueuePrefetchWork(Context context, String url) {
        Log.d(TAG, "enqueuePrefetchWork: " + url);
        Intent intent = new Intent(JOB_NAME);
        intent.putExtra(URL, url);
        enqueueWork(context, CachingJobIntentService.class, JOB_ID, intent);
    }

    @Override
    protected void onHandleWork(@NonNull Intent intent) {
        String urlToPrefetch = intent.getStringExtra(URL);
        Log.d(TAG, "onHandleWork() called with: intent = [" + urlToPrefetch + "]");
        Uri uri = Uri.parse(urlToPrefetch);

        MediaItem mediaItem = new MediaItem.Builder()
                .setUri(uri)
                .setStreamKeys(Collections.singletonList(new StreamKey(HlsMultivariantPlaylist.GROUP_INDEX_VARIANT, 0)))
                .build();

        try {
            HlsDownloader hlsDownloader = new HlsDownloader(mediaItem, DataSourceUtil.cacheDataSourceAtomicReference.get());
            hlsDownloader.download(new Downloader.ProgressListener() {
                @Override
                public void onProgress(long contentLength, long bytesDownloaded, float percentDownloaded) {
                    Log.e("Denis", "onProgress() called with: contentLength = [" + contentLength + "], bytesDownloaded = [" + bytesDownloaded + "], percentDownloaded = [" + percentDownloaded + "]");
                }
            });
        } catch (Exception e) {
            Log.e("Denis", e.getMessage());
        }
    }

    @Override
    public void onProgress(long requestLength, long bytesCached, long newBytesCached) {
        Log.d(TAG, "onProgress() called with: requestLength = [" + requestLength + "], bytesCached = [" + bytesCached + "], newBytesCached = [" + newBytesCached + "]");
    }
}
