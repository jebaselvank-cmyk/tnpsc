package com.tnpsc.groupbook.tnpsc_group_book

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            // Enable edge-to-edge display using the Activity 1.8+ API
            enableEdgeToEdge()
        } catch (e: Throwable) {
            // Safely ignore edge-to-edge on OEM Android 10/11 devices (OPPO, Vivo, Xiaomi)
            // that throw UnsupportedOperationException: Unknown windowLayoutInDisplayCutoutMode: 3
        }
        super.onCreate(savedInstanceState)
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
