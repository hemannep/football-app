allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

buildscript {
  dependencies {
    classpath("com.google.gms:google-services:4.4.2")
    classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
  }
}