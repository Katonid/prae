# Minification is disabled for the release build (see app/build.gradle.kts).
# The rules below are kept so that turning it back on stays a one-line change.
-keepattributes SourceFile,LineNumberTable
-keepclassmembers class de.dbo.alarm.data.model.** { *; }
