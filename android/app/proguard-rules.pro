# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Play Store integration classes
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }
-keep class com.google.android.play.core.** { *; }

# Health Connect
-keep class androidx.health.** { *; }
-keep class com.google.android.libraries.healthdata.** { *; }

# Credential Manager for Google Sign-In
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

# Google ID
-keep class com.google.android.libraries.identity.googleid.** { *; }

# Preserve the health permissions file
-keep class com.oseerapp.healthbridge.R$xml { *; }

# Keep kotlin classes
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Common exceptions from obfuscation
-keep class * implements java.io.Serializable { *; }
-keep class * implements android.os.Parcelable { *; }

# Preserve all native method names and the names of their classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep model classes
-keep class com.oseerapp.healthbridge.models.** { *; }

# Preserve all classes and methods in your app's main package.
# This prevents ProGuard/R8 from renaming native code that your Flutter
# platform channels might be trying to call by name.
-keep class com.oseerapp.healthbridge.** { *; }