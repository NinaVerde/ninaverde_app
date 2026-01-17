package com.nicaraguaninaverde.theapp

import android.content.Intent
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "native_facebook_auth"
    private var callbackManager: CallbackManager? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callbackManager = CallbackManager.Factory.create()
        val manager = LoginManager.getInstance()
        manager.registerCallback(callbackManager, object : FacebookCallback<LoginResult> {
            override fun onSuccess(result: LoginResult) {
                pendingResult?.success(result.accessToken.token)
                pendingResult = null
            }

            override fun onCancel() {
                pendingResult?.error("cancelled", "Facebook login cancelled.", null)
                pendingResult = null
            }

            override fun onError(error: FacebookException) {
                pendingResult?.error("error", error.message, null)
                pendingResult = null
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "logIn" -> {
                        if (pendingResult != null) {
                            result.error(
                                "in_progress",
                                "Facebook login already in progress.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        manager.logIn(this, listOf("public_profile", "email"))
                    }
                    "logOut" -> {
                        manager.logOut()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        callbackManager?.onActivityResult(requestCode, resultCode, data)
        super.onActivityResult(requestCode, resultCode, data)
    }
}
