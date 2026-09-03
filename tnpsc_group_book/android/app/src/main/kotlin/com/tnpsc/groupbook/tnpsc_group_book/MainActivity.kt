package com.tnpsc.groupbook.tnpsc_group_book

import android.os.Bundle
import android.graphics.Color
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable edge-to-edge display using WindowCompat for best compatibility
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val smallFactory = ListTileNativeAdFactory(applicationContext, R.layout.small_native_ad)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "listTileSmall", smallFactory)

        val mediumFactory = ListTileNativeAdFactory(applicationContext, R.layout.medium_native_ad)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "listTileMedium", mediumFactory)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTileSmall")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTileMedium")
    }
}
