package com.brentvatne.exoplayer.cache;


import static android.content.Context.MODE_PRIVATE;

import android.content.Context;
import android.util.Log;

import com.google.android.exoplayer2.database.StandaloneDatabaseProvider;
import com.google.android.exoplayer2.upstream.cache.LeastRecentlyUsedCacheEvictor;
import com.google.android.exoplayer2.upstream.cache.SimpleCache;

import java.io.File;
import java.util.concurrent.atomic.AtomicReference;

public class SharedExoPlayerCache {

    private static final long exoPlayerCacheSize = 2000 * 1024 * 1024;
    private static final String CACHE_FOLDER = "/exoplayer/";
    private static final String TAG = "SharedExoPlayerCache";
    private static final String SHARED_PREF_NAME = TAG;
    private static final String SHARED_PREF_CACHE_SIZE = SHARED_PREF_NAME + "_Cache_Size";
    private static AtomicReference<SimpleCache> simpleCacheReference;

    public static void initCache(Context context) {
        if (context == null) {
            throw new IllegalArgumentException("Context is null");
        }

        if (simpleCacheReference != null) {
            Log.w(TAG, "initCache: cache already initialised");
            return;
        }

        long preferredCacheSize = context.getSharedPreferences(SHARED_PREF_NAME, MODE_PRIVATE).getLong(SHARED_PREF_CACHE_SIZE, exoPlayerCacheSize);

        LeastRecentlyUsedCacheEvictor lruCacheEvictor = new LeastRecentlyUsedCacheEvictor(preferredCacheSize);
        StandaloneDatabaseProvider databaseProvider = new StandaloneDatabaseProvider(context);
        File cacheFolder = new File(context.getCacheDir().getAbsolutePath() + CACHE_FOLDER);
        Log.d(TAG, "initCache() " + cacheFolder.getAbsolutePath());
        simpleCacheReference = new AtomicReference<>(new SimpleCache(cacheFolder, lruCacheEvictor, databaseProvider))
    }

    public static SimpleCache getCache() {
        Log.d(TAG, "getCache()");
        return simpleCacheReference.get();
    }

    public static void releaseCache() {
        Log.d(TAG, "releaseCache()");
        simpleCacheReference.get().release();
        simpleCacheReference = null;
    }

    public static void updateCacheSize(Context context, long cacheSize) {
        context.getSharedPreferences(SHARED_PREF_NAME, MODE_PRIVATE).edit()
                .putLong(SHARED_PREF_CACHE_SIZE, cacheSize)
                .apply();
    }

}