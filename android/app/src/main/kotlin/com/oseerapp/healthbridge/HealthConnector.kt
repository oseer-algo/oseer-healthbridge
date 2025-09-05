// android/app/src/main/kotlin/com/oseerapp/healthbridge/HealthConnector.kt
package com.oseerapp.healthbridge

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.runBlocking
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Health Connect integration for HealthBridge
 * Uses the official PermissionController API for requesting permissions
 */
class HealthConnector(private val context: Context) {
    // Permission callback and tracking
    private var permissionCallback: ((Boolean) -> Unit)? = null
    private var requestedPermissions: Set<String> = emptySet()
    private val handler = Handler(Looper.getMainLooper())
    
    // SDK-provided permission launcher
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null

    // Constants for Health Connect
    private val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
    private val ACTION_HEALTH_CONNECT_SETTINGS = "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"

    // Health Connect client with lazy initialization
    private val client: HealthConnectClient? by lazy {
        try {
            HealthConnectClient.getOrCreate(context)
        } catch (e: Exception) {
            println("Failed to create HealthConnectClient: ${e.message}")
            null
        }
    }

    /**
     * Register permission launcher for permission flow
     * Must be called during activity creation
     */
    fun registerForActivityResult(activity: ComponentActivity) {
        try {
            // Use the PermissionController to create the correct contract
            val contract = PermissionController.createRequestPermissionResultContract()
            
            // Register the launcher with the created contract
            permissionLauncher = activity.registerForActivityResult(contract) { granted: Set<String> ->
                // This callback receives the set of granted permissions directly
                println("Permission result received with ${granted.size} granted permissions")
                
                // Store the result and process it
                val allGranted = requestedPermissions.all { granted.contains(it) }
                println("All requested permissions granted: $allGranted")
                
                // Invoke the callback with the result
                permissionCallback?.invoke(allGranted)
                permissionCallback = null
                requestedPermissions = emptySet()
            }
            
            println("Successfully registered permission launcher")
        } catch (e: Exception) {
            println("Error registering permission launcher: ${e.message}")
        }
    }

    /**
     * Check Health Connect availability status
     */
    fun checkAvailability(): Map<String, Any> {
        // Try to get SDK status if available
        val sdkStatus = try {
            HealthConnectClient.getSdkStatus(context)
        } catch (e: Exception) {
            println("Error getting SDK status: ${e.message}")
            -1 // Custom error code
        }
        
        // Map SDK status to readable string
        val status = when (sdkStatus) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            HealthConnectClient.SDK_UNAVAILABLE -> "not_installed"
            else -> "not_available"
        }
        
        // Check if Health Connect is installed
        val isInstalled = try {
            context.packageManager.getPackageInfo(HEALTH_CONNECT_PACKAGE, 0)
            true
        } catch (e: Exception) {
            false
        }
        
        // Check if the standard intent can be resolved
        val isSupported = try {
            val intent = Intent(ACTION_HEALTH_CONNECT_SETTINGS)
            val info = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            info != null
        } catch (e: Exception) {
            false
        }
        
        // Check if direct app-specific permissions are supported
        val directPermissionsSupported = try {
            val directIntent = Intent(ACTION_HEALTH_CONNECT_SETTINGS).apply {
                putExtra("android.intent.extra.PACKAGE_NAME", context.packageName)
            }
            val directInfo = context.packageManager.resolveActivity(directIntent, PackageManager.MATCH_DEFAULT_ONLY)
            directInfo != null
        } catch (e: Exception) {
            false
        }
        
        return mapOf(
            "availability" to status,
            "installed" to isInstalled,
            "supported" to isSupported,
            "directPermissionsSupported" to directPermissionsSupported
        )
    }

    /**
     * Map Flutter health type strings to Health Connect permissions
     * Complete and accurate mapping is crucial for proper permission handling
     */
    private fun getPermissionsForType(type: String): Set<String> {
        // Convert to lowercase for case-insensitive matching
        return when (type.lowercase()) {
            // Activity & Movement
            "steps" -> setOf(HealthPermission.getReadPermission(StepsRecord::class))
            "distance_delta" -> setOf(HealthPermission.getReadPermission(DistanceRecord::class))
            "flights_climbed" -> setOf(HealthPermission.getReadPermission(FloorsClimbedRecord::class))
            "active_energy_burned" -> setOf(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))
            "workout", "exercise" -> setOf(HealthPermission.getReadPermission(ExerciseSessionRecord::class))
            "total_energy_burned" -> setOf(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))
            
            // Energy & Metabolism
            "basal_energy_burned" -> setOf(HealthPermission.getReadPermission(BasalMetabolicRateRecord::class))
            "total_calories_burned" -> setOf(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))
            
            // Body Measurements
            "weight" -> setOf(HealthPermission.getReadPermission(WeightRecord::class))
            "height" -> setOf(HealthPermission.getReadPermission(HeightRecord::class))
            "body_fat_percentage", "body_fat" -> setOf(HealthPermission.getReadPermission(BodyFatRecord::class))
            "body_water_mass" -> setOf(HealthPermission.getReadPermission(BodyWaterMassRecord::class))
            "lean_body_mass" -> setOf(HealthPermission.getReadPermission(LeanBodyMassRecord::class))
            "body_mass_index" -> setOf(HealthPermission.getReadPermission(WeightRecord::class), 
                                        HealthPermission.getReadPermission(HeightRecord::class))
            
            // Vitals
            "heart_rate" -> setOf(HealthPermission.getReadPermission(HeartRateRecord::class))
            "resting_heart_rate" -> setOf(HealthPermission.getReadPermission(RestingHeartRateRecord::class))
            "heart_rate_variability", "heart_rate_variability_rmssd" -> 
                setOf(HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class))
            "blood_pressure", "blood_pressure_systolic", "blood_pressure_diastolic" -> 
                setOf(HealthPermission.getReadPermission(BloodPressureRecord::class))
            "blood_glucose" -> setOf(HealthPermission.getReadPermission(BloodGlucoseRecord::class))
            "body_temperature" -> setOf(HealthPermission.getReadPermission(BodyTemperatureRecord::class))
            "oxygen_saturation", "blood_oxygen" -> setOf(HealthPermission.getReadPermission(OxygenSaturationRecord::class))
            "respiratory_rate" -> setOf(HealthPermission.getReadPermission(RespiratoryRateRecord::class))
            
            // Sleep - all map to SleepSessionRecord since Health Connect uses a unified sleep API
            "sleep", "sleep_asleep", "sleep_session", "sleep_deep", "sleep_rem", "sleep_light", 
            "sleep_awake", "sleep_awake_in_bed", "sleep_out_of_bed", "sleep_in_bed", "sleep_unknown" -> 
                setOf(HealthPermission.getReadPermission(SleepSessionRecord::class))
            
            // Nutrition & Hydration
            "water" -> setOf(HealthPermission.getReadPermission(HydrationRecord::class))
            "nutrition" -> setOf(HealthPermission.getReadPermission(NutritionRecord::class))
            
            // Menstrual health
            "menstruation", "menstruation_flow" -> setOf(HealthPermission.getReadPermission(MenstruationFlowRecord::class))
            
            // Physical Activity (IMPORTANT: Added for explicit physical activity permission)
            "physical_activity" -> setOf(
                HealthPermission.getReadPermission(StepsRecord::class),
                HealthPermission.getReadPermission(ExerciseSessionRecord::class),
                HealthPermission.getReadPermission(DistanceRecord::class),
                HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
                HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)
                // ActivitySession was causing issues - removing this reference
            )
            
            // Special compound types - for convenience when requesting multiple related permissions
            "body_composition" -> setOf(
                HealthPermission.getReadPermission(WeightRecord::class),
                HealthPermission.getReadPermission(HeightRecord::class),
                HealthPermission.getReadPermission(BodyFatRecord::class),
                HealthPermission.getReadPermission(LeanBodyMassRecord::class)
            )
            "cardiovascular" -> setOf(
                HealthPermission.getReadPermission(HeartRateRecord::class),
                HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
                HealthPermission.getReadPermission(RestingHeartRateRecord::class),
                HealthPermission.getReadPermission(BloodPressureRecord::class)
            )
            
            // ALL_HEALTH_PERMISSIONS - for requesting all available health permissions (similar to Samsung Health, Fitbit)
            "all_health_permissions" -> getAllHealthPermissions()
            
            // Fallback for unrecognized types
            else -> {
                println("WARNING: Unknown health data type: $type")
                emptySet()
            }
        }
    }
    
    /**
     * Get all available Health Connect read permissions for comprehensive access
     */
    private fun getAllHealthPermissions(): Set<String> {
        val allPermissions = mutableSetOf<String>()
        
        // Activity & Movement
        allPermissions.add(HealthPermission.getReadPermission(StepsRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(DistanceRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(FloorsClimbedRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(ExerciseSessionRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))
        
        // Energy & Metabolism
        allPermissions.add(HealthPermission.getReadPermission(BasalMetabolicRateRecord::class))
        
        // Body Measurements
        allPermissions.add(HealthPermission.getReadPermission(WeightRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(HeightRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(BodyFatRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(LeanBodyMassRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(BodyWaterMassRecord::class))
        
        // Vitals
        allPermissions.add(HealthPermission.getReadPermission(HeartRateRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(RestingHeartRateRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(BloodPressureRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(BloodGlucoseRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(BodyTemperatureRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(OxygenSaturationRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(RespiratoryRateRecord::class))
        
        // Sleep
        allPermissions.add(HealthPermission.getReadPermission(SleepSessionRecord::class))
        
        // Nutrition & Hydration
        allPermissions.add(HealthPermission.getReadPermission(HydrationRecord::class))
        allPermissions.add(HealthPermission.getReadPermission(NutritionRecord::class))
        
        // Menstrual health
        allPermissions.add(HealthPermission.getReadPermission(MenstruationFlowRecord::class))
        
        // Removed ActivitySession reference that was causing issues

        return allPermissions
    }

    /**
     * Check which of the requested permission types have been granted
     */
    fun checkPermissions(types: List<String>): Map<String, Boolean> {
        val healthClient = client ?: return types.associateWith { false }
        
        // Get currently granted permissions
        val grantedPermissions = runBlocking {
            try {
                healthClient.permissionController.getGrantedPermissions()
            } catch (e: Exception) {
                println("Error checking permissions: ${e.message}")
                setOf<String>()
            }
        }
        
        // Debug output of all granted permissions
        println("DEBUG: Granted permissions - ${grantedPermissions.joinToString()}")
        
        // Map each requested type to its permission status
        return types.associateWith { type ->
            val permissions = getPermissionsForType(type)
            val hasPermission = permissions.isNotEmpty() && permissions.all { grantedPermissions.contains(it) }
            
            // Debug output for individual permission
            println("DEBUG: Permission for $type: $hasPermission (${permissions.joinToString()})")
            
            hasPermission
        }
    }
    
    /**
     * Request Health Connect permissions using the official PermissionController API
     */
    fun requestPermissions(types: List<String>, callback: (Boolean) -> Unit) {
        // Verify prerequisites
        if (context !is ComponentActivity) {
            println("Cannot request permissions: context is not a ComponentActivity")
            callback(false)
            return
        }
        
        // Register launcher if not already done
        if (permissionLauncher == null) {
            registerForActivityResult(context)
        }

        // Map requested types to Health Connect permissions, adding 'all_health_permissions' if 'physical_activity' is present
        val typesToRequest = if (types.any { it.equals("physical_activity", ignoreCase = true) }) {
            types + "all_health_permissions"
        } else {
            types + "physical_activity" + "all_health_permissions"
        }
        
        // Map requested types to Health Connect permissions
        val permissionSet = typesToRequest.flatMap { getPermissionsForType(it) }.toSet()
        if (permissionSet.isEmpty()) {
            println("No valid permissions to request for types: ${types.joinToString()}")
            callback(false)
            return
        }
        
        // Save requested permissions and callback for later processing
        requestedPermissions = permissionSet
        permissionCallback = callback
        
        try {
            println("Requesting permissions: ${permissionSet.joinToString()}")
            
            // Launch the permission request using the SDK-provided launcher
            permissionLauncher?.launch(permissionSet) ?: run {
                println("Permission launcher is null, cannot request permissions")
                permissionCallback?.invoke(false)
                permissionCallback = null
                requestedPermissions = emptySet()
            }
        } catch (e: Exception) {
            println("Error launching permission request: ${e.message}")
            
            // Try to open Health Connect settings as fallback
            try {
                println("Attempting fallback to Health Connect settings")
                val fallbackIntent = Intent(ACTION_HEALTH_CONNECT_SETTINGS).apply {
                    putExtra("android.intent.extra.PACKAGE_NAME", context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallbackIntent)
                
                // Set a delay to check permissions after user returns
                handler.postDelayed({
                    checkPermissionsAndNotifyCallback()
                }, 5000) // 5 second delay for user interaction
            } catch (e2: Exception) {
                println("Fallback to settings also failed: ${e2.message}")
                permissionCallback?.invoke(false)
                permissionCallback = null
                requestedPermissions = emptySet()
            }
        }
    }
    
    /**
     * Fallback method to manually check permissions
     * Only used when normal flow fails
     */
    private fun checkPermissionsAndNotifyCallback() {
        val healthClient = client
        if (healthClient == null || requestedPermissions.isEmpty() || permissionCallback == null) {
            permissionCallback?.invoke(false)
            permissionCallback = null
            return
        }
        
        // Check if all requested permissions are granted
        val grantedPermissions = runBlocking {
            try {
                healthClient.permissionController.getGrantedPermissions()
            } catch (e: Exception) {
                println("Error getting granted permissions: ${e.message}")
                setOf<String>()
            }
        }
        
        // Debug output of all granted permissions
        println("DEBUG: Granted permissions - ${grantedPermissions.joinToString()}")
        
        val allGranted = requestedPermissions.all { grantedPermissions.contains(it) }
        permissionCallback?.invoke(allGranted)
        
        // Clear callback and requested permissions after handling
        permissionCallback = null
        requestedPermissions = emptySet()
    }
    
    /**
     * Opens Health Connect installation page in Play Store
     */
    fun installProvider(): Boolean {
        val intent = Intent(Intent.ACTION_VIEW)
        intent.data = android.net.Uri.parse("market://details?id=$HEALTH_CONNECT_PACKAGE")
        
        try {
            context.startActivity(intent)
            return true
        } catch (e: Exception) {
            // Fallback to browser
            try {
                val browserIntent = Intent(Intent.ACTION_VIEW)
                browserIntent.data = android.net.Uri.parse(
                    "https://play.google.com/store/apps/details?id=$HEALTH_CONNECT_PACKAGE"
                )
                context.startActivity(browserIntent)
                return true
            } catch (e2: Exception) {
                return false
            }
        }
    }
    
    /**
     * Opens Health Connect settings
     */
    fun openSettings(): Boolean {
        try {
            // Standard Health Connect settings intent with package hint
            val intent = Intent(ACTION_HEALTH_CONNECT_SETTINGS).apply {
                putExtra("android.intent.extra.PACKAGE_NAME", context.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            return true
        } catch (e: Exception) {
            println("Could not open Health Connect settings: ${e.message}")
            return false
        }
    }

    /**
     * Checks which applications have provided data for the given types.
     * This is critical for determining if data sources are available.
     */
    suspend fun checkDataSources(types: List<String>): Map<String, List<String>> {
        val healthClient = client ?: return emptyMap()
        val sourcesMap = mutableMapOf<String, MutableSet<String>>()

        val grantedPermissions = healthClient.permissionController.getGrantedPermissions()
        val endTime = Instant.now()
        val startTime = endTime.minus(24, ChronoUnit.HOURS)

        // Check for each requested type
        for (type in types) {
            val permissions = getPermissionsForType(type)
            
            for (permission in permissions) {
                if (!grantedPermissions.contains(permission)) {
                    continue
                }

                try {
                    // Determine the record type based on the permission
                    when {
                        permission == HealthPermission.getReadPermission(StepsRecord::class) -> {
                            val request = ReadRecordsRequest(
                                recordType = StepsRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                            )
                            val response = healthClient.readRecords(request)
                            response.records.forEach { record ->
                                sourcesMap.getOrPut(type) { mutableSetOf() }.add(record.metadata.dataOrigin.packageName)
                            }
                        }
                        permission == HealthPermission.getReadPermission(HeartRateRecord::class) -> {
                            val request = ReadRecordsRequest(
                                recordType = HeartRateRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                            )
                            val response = healthClient.readRecords(request)
                            response.records.forEach { record ->
                                sourcesMap.getOrPut(type) { mutableSetOf() }.add(record.metadata.dataOrigin.packageName)
                            }
                        }
                        permission == HealthPermission.getReadPermission(SleepSessionRecord::class) -> {
                            val request = ReadRecordsRequest(
                                recordType = SleepSessionRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                            )
                            val response = healthClient.readRecords(request)
                            response.records.forEach { record ->
                                sourcesMap.getOrPut(type) { mutableSetOf() }.add(record.metadata.dataOrigin.packageName)
                            }
                        }
                        permission == HealthPermission.getReadPermission(ExerciseSessionRecord::class) -> {
                            val request = ReadRecordsRequest(
                                recordType = ExerciseSessionRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                            )
                            val response = healthClient.readRecords(request)
                            response.records.forEach { record ->
                                sourcesMap.getOrPut(type) { mutableSetOf() }.add(record.metadata.dataOrigin.packageName)
                            }
                        }
                        permission == HealthPermission.getReadPermission(WeightRecord::class) -> {
                            val request = ReadRecordsRequest(
                                recordType = WeightRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                            )
                            val response = healthClient.readRecords(request)
                            response.records.forEach { record ->
                                sourcesMap.getOrPut(type) { mutableSetOf() }.add(record.metadata.dataOrigin.packageName)
                            }
                        }
                        permission == HealthPermission.getReadPermission(HeightRecord::class) -> {
                            val request = ReadRecordsRequest(
                                recordType = HeightRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                            )
                            val response = healthClient.readRecords(request)
                            response.records.forEach { record ->
                                sourcesMap.getOrPut(type) { mutableSetOf() }.add(record.metadata.dataOrigin.packageName)
                            }
                        }
                        // Add more record types as needed
                    }
                } catch (e: Exception) {
                    println("Error reading records for $type with permission $permission: ${e.message}")
                }
            }
        }
        
        return sourcesMap.mapValues { it.value.toList() }
    }
}