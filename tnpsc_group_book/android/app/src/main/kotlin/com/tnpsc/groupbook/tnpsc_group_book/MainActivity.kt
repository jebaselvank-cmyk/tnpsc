package com.tnpsc.groupbook.tnpsc_group_book

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.NativeAdFactory

class MainActivity : FlutterActivity() {
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
