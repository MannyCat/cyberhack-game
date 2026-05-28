# CyberHack ProGuard Rules
# Required for Supabase Flutter in release builds

# Keep Supabase classes
-keep class supabase.** { *; }
-dontwarn supabase.**

# Keep GoTrue (auth) classes
-keep class io.supabase.gotrue.** { *; }
-dontwarn io.supabase.gotrue.**

# Keep Supabase real-time / WebSocket classes
-keep class io.supabase.realtime.** { *; }
-dontwarn io.supabase.realtime.**

# Keep PostgREST classes
-keep class io.supabase.postgrest.** { *; }
-dontwarn io.supabase.postgrest.**

# Keep Storage classes
-keep class io.supabase.storage.** { *; }
-dontwarn io.supabase.storage.**

# Keep function client
-keep class io.supabase.functions.** { *; }
-dontwarn io.supabase.functions.**

# Keep Flutter plugin registrations
-keep class io.flutter.plugins.** { *; }

# Keep generated plugin registrant
-keep class **.GeneratedPluginRegistrant { *; }

# Keep AppLifecycleObserver implementations
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Gson / JSON serialization (used by Supabase)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }

# Keep model classes used with Supabase (JSON serialization)
-keep class com.mannycat.cyberhack.** { *; }

# OkHttp (used by Supabase)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Keep enum values (used in Supabase filters)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Retrofit (if used internally by Supabase)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# WebSocket (Supabase Realtime)
-keep class org.java_websocket.** { *; }
-dontwarn org.java_websocket.**

# Kotlin coroutines (Supabase async)
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# Ktor (Supabase HTTP client)
-dontwarn io.ktor.**
-keep class io.ktor.** { *; }

# Keep all Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
}

# Prevent stripping of fields in data classes
-keepclassmembers class * {
    <fields>;
}
