package com.example.kamoos

import android.os.Build
import android.os.Bundle
import android.view.animation.DecelerateInterpolator
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Handle the splash screen transition for Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Provide a custom exit animation for the Android 12+ native splash
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                val duration = 600L
                // Fade out and subtly scale the icon
                val iconView = splashScreenView.iconView
                iconView?.animate()
                    ?.setDuration(duration)
                    ?.setInterpolator(DecelerateInterpolator())
                    ?.scaleX(1.1f)
                    ?.scaleY(1.1f)
                    ?.alpha(0f)
                    ?.withEndAction {
                        // Remove the splash once animation completes
                        splashScreenView.remove()
                    }
                    ?.start()

                // Also fade out the splash background for a smoother handoff
                splashScreenView.animate()
                    .setDuration(duration)
                    .alpha(0f)
                    .start()
            }
        }

        super.onCreate(savedInstanceState)
    }
}
