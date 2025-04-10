package com.oseerapp.healthbridge

import androidx.health.connect.client.HealthConnectClient
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * A connector class for Health Connect functionality.
 */
class HealthConnector {
    companion object {
        private const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
        
        /**
         * Check if Health Connect is available on this device
         */
        fun isAvailable(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // For Android 13+ use the package check method
                isPackageInstalled(context, HEALTH_CONNECT_PACKAGE)
            } else {
                // For older versions, we can try to resolve the Health Connect activity
                val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
                val activities = context.packageManager.queryIntentActivities(intent, 0)
                activities.isNotEmpty()
            }
        }

        /**
         * Get the Health Connect client
         */
        fun getClient(context: Context): HealthConnectClient? {
            return if (isAvailable(context)) {
                try {
                    HealthConnectClient.getOrCreate(context)
                } catch (e: Exception) {
                    null
                }
            } else {
                null
            }
        }
        
        /**
         * Check if a specific package is installed
         */
        private fun isPackageInstalled(context: Context, packageName: String): Boolean {
            return try {
                context.packageManager.getPackageInfo(packageName, 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }
}