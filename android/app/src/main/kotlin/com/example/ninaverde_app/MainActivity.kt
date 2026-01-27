package com.example.ninaverde_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "native_facebook_auth"
    private var callbackManager: CallbackManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        callbackManager = CallbackManager.Factory.create()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "logIn") {
                LoginManager.getInstance().logInWithReadPermissions(this, listOf("public_profile", "email"))
                LoginManager.getInstance().registerCallback(callbackManager, object : FacebookCallback<LoginResult> {
                    override fun onSuccess(loginResult: LoginResult) {
                        result.success(loginResult.accessToken.token)
                    }
                    override fun onCancel() {
                        result.error("cancelled", "User cancelled", null)
                    }
                    override fun onError(error: FacebookException) {
                        result.error("failed", error.message, null)
                    }
                })
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        callbackManager?.onActivityResult(requestCode, resultCode, data)
        super.onActivityResult(requestCode, resultCode, data)
    }
}

