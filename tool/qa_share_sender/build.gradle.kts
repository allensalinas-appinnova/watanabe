plugins { id("com.android.application") version "9.1.1" }
android {
    namespace = "co.appinnova.lumio.qa.sender"
    compileSdk = 37
    defaultConfig { applicationId = "co.appinnova.lumio.qa.sender"; minSdk = 23; targetSdk = 36; versionCode = 1; versionName = "1.0" }
    sourceSets.getByName("main").assets.srcDir("build/generated/assets")
}
