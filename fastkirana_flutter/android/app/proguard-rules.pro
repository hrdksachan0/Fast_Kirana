# FastKirana Flutter App — ProGuard / R8 Rules
# Generated for production release builds with full obfuscation

# ──────────────────────────────────────────────
# Flutter Engine & Plugins
# ──────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ──────────────────────────────────────────────
# Firebase & FCM
# ──────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.**

# ──────────────────────────────────────────────
# Dio (HTTP Client)
# ──────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response

# ──────────────────────────────────────────────
# JSON Serialization (riverpod_generator, json_serializable)
# ──────────────────────────────────────────────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ──────────────────────────────────────────────
# Razorpay Payment Gateway
# ──────────────────────────────────────────────
-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# ──────────────────────────────────────────────
# Google Sign-In & Play Services Auth
# ──────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**
-dontwarn com.google.android.gms.**

# ──────────────────────────────────────────────
# Geocoding & Location Services
# ──────────────────────────────────────────────
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

# ──────────────────────────────────────────────
# Local Notifications
# ──────────────────────────────────────────────
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ──────────────────────────────────────────────
# Riverpod & Provider
# ──────────────────────────────────────────────
-keep class * extends io.flutter.plugin.platform.PlatformAware
-keep class * implements io.flutter.plugin.platform.PlatformAware
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin

# ──────────────────────────────────────────────
# Speech Recognition (Voice Search)
# ──────────────────────────────────────────────
-keep class android.speech.** { *; }
-dontwarn android.speech.**

# ──────────────────────────────────────────────
# Kotlin Coroutines
# ──────────────────────────────────────────────
-dontwarn kotlinx.coroutines.**
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}

# ──────────────────────────────────────────────
# Crashlytics & Analytics
# ──────────────────────────────────────────────
-keep class com.crashlytics.** { *; }
-keep class io.fabric.** { *; }
-dontwarn com.crashlytics.**
-dontwarn io.fabric.**

# ──────────────────────────────────────────────
# Network Security (OkHttp under the hood)
# ──────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ──────────────────────────────────────────────
# Keep application class for MainActivity reflection
# ──────────────────────────────────────────────
-keep class com.fastkirana.app.MainActivity { *; }

# ──────────────────────────────────────────────
# Suppress Notes
# ──────────────────────────────────────────────
-dontnote
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn javax.annotation.**
