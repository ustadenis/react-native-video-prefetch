package com.brentvatne.react;

import android.util.Log;

import androidx.annotation.NonNull;

import com.brentvatne.exoplayer.cache.CachingJobIntentService;
import com.brentvatne.exoplayer.cache.SharedExoPlayerCache;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

public class PrefetchModule extends ReactContextBaseJavaModule {

    ReactApplicationContext reactContext;
    private static final String TAG = "PrefetchModule";

    @NonNull
    @Override
    public String getName() {
        return "VideoPrefetcher";
    }

    @ReactMethod
    public void prefetch(String url) {
        Log.d(TAG, "prefetch: " + url);
        CachingJobIntentService.enqueuePrefetchWork(reactContext, url);
    }

    @ReactMethod
    public void setCacheMaxSize(long cacheSize) {
        if (reactContext == null) return;
        SharedExoPlayerCache.updateCacheSize(reactContext, cacheSize);
    }

    @ReactMethod
    public void clearCache() {
        SharedExoPlayerCache.releaseCache();
    }

}
