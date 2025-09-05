package com.oseerapp.healthbridge

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.health.connect.client.HealthConnectClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Main Activity for the HealthBridge app.
 * Extends FlutterFragmentActivity instead of FlutterActivity to ensure
 * proper compatibility with Health Connect permission handling.
 */
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.oseerapp.healthbridge/health"
    private lateinit var healthConnector: HealthConnector
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        healthConnector = HealthConnector(this)
        // Register for activity results immediately at creation
        healthConnector.registerForActivityResult(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkHealthConnectAvailability" -> {
                    result.success(healthConnector.checkAvailability())
                }
                "requestPermissions" -> {
                    val perms = call.argument<List<String>>("permissions")
                    if (perms != null) {
                        try {
                            println("Requesting permissions: ${perms.joinToString()}")
                            healthConnector.requestPermissions(perms) { granted ->
                                CoroutineScope(Dispatchers.Main).launch {
                                    println("Permission request result: $granted")
                                    result.success(granted)
                                }
                            }
                        } catch (e: Exception) {
                            println("Error requesting permissions: ${e.message}")
                            result.error(
                                "PERMISSION_REQUEST_ERROR",
                                "Error requesting Health Connect permissions: ${e.message}",
                                e.toString()
                            )
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Permissions list required", null)
                    }
                }
                "checkPermissions" -> {
                    val perms = call.argument<List<String>>("permissions")
                    if (perms != null) {
                        try {
                            val permissionStatus = healthConnector.checkPermissions(perms)
                            result.success(permissionStatus)
                        } catch (e: Exception) {
                            result.error(
                                "PERMISSION_CHECK_ERROR",
                                "Error checking Health Connect permissions: ${e.message}",
                                e.toString()
                            )
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Permissions list required", null)
                    }
                }
                "openHealthConnectSettings" -> {
                    try {
                        val success = healthConnector.openSettings()
                        result.success(success)
                    } catch (e: Exception) {
                        result.error(
                            "SETTINGS_ERROR",
                            "Could not open Health Connect settings: ${e.message}",
                            e.toString()
                        )
                    }
                }
                "installHealthConnect" -> {
                    try {
                        val success = healthConnector.installProvider()
                        result.success(success)
                    } catch (e: Exception) {
                        result.error(
                            "PLAYSTORE_ERROR",
                            "Could not open Play Store: ${e.message}",
                            e.toString()
                        )
                    }
                }
                "getDeviceId" -> {
                    val deviceId = android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ANDROID_ID
                    )
                    result.success(deviceId)
                }
                "checkDataSources" -> {
                    val dataTypes = call.argument<List<String>>("dataTypes")
                    if (dataTypes != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val sources = healthConnector.checkDataSources(dataTypes)
                                runOnUiThread { result.success(sources) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error(
                                        "DATA_SOURCE_CHECK_ERROR",
                                        "Error checking data sources: ${e.message}",
                                        e.toString()
                                    )
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "dataTypes list is required.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        methodChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}