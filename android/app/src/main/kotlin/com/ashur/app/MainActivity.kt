package com.ashur.app

import io.flutter.embedding.android.FlutterActivity
import android.content.res.Configuration
import android.os.Bundle

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // منع إعادة التشغيل عند تغيير الاتجاه
        // لا نفعل شيء هنا لتجنب إعادة التشغيل
    }
}
