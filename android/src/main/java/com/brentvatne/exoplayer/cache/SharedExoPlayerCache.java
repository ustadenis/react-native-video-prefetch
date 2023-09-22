package com.brentvatne.exoplayer.cache;


import static android.content.Context.MODE_PRIVATE;

import android.content.Context;
import android.util.Log;

import com.google.android.exoplayer2.database.StandaloneDatabaseProvider;
import com.google.android.exoplayer2.upstream.cache.LeastRecentlyUsedCacheEvictor;
import com.google.android.exoplayer2.upstream.cache.SimpleCache;

import java.io.File;

public class SharedExoPlayerCache {

    private static SimpleCache simpleCache;
    private static final long exoPlayerCacheSize = 2000 * 1024 * 1024;
    private static final String TAG = "SharedExoPlayerCache";

    private static final String SHARED_PREF_NAME = TAG;

    private static final String SHARED_PREF_CACHE_SIZE = SHARED_PREF_NAME + "_Cache_Size";

    public static void initCache(Context context) {
        long cacheSize = context.getSharedPreferences(SHARED_PREF_NAME, MODE_PRIVATE).getLong(SHARED_PREF_CACHE_SIZE, exoPlayerCacheSize);

        LeastRecentlyUsedCacheEvictor leastRecentlyUsedCacheEvictor = new LeastRecentlyUsedCacheEvictor(cacheSize);
        StandaloneDatabaseProvider exoDatabaseProvider = new StandaloneDatabaseProvider(context);
        File cacheFolder = new File(context.getCacheDir().getAbsolutePath() + "/exoplayer/");
        Log.d(TAG, "initCache() " + cacheFolder.getAbsolutePath());
        simpleCache = new SimpleCache(cacheFolder, leastRecentlyUsedCacheEvictor, exoDatabaseProvider);
    }

    public static SimpleCache getCache() {
        Log.d(TAG, "getCache()");
        return simpleCache;
    }

    public static void releaseCache() {
        Log.d(TAG, "releaseCache()");
        simpleCache.release();
    }

    public static void updateCacheSize(Context context, long cacheSize) {
        context.getSharedPreferences(SHARED_PREF_NAME, MODE_PRIVATE).edit()
                .putLong(SHARED_PREF_CACHE_SIZE, cacheSize)
                .apply();
    }

}