package com.naren.NESmartConnect
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import kotlin.collections.mutableMapOf
import java.util.Calendar
import java.util.Date
import android.telephony.SubscriptionManager
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.provider.Settings
import android.app.AlertDialog
import java.net.URL
import java.net.HttpURLConnection
import java.net.URLEncoder
import android.os.PowerManager
import androidx.annotation.RequiresApi
import android.telephony.SmsManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.naren.NESmartConnect/sms"
    private fun startSmsFgService() = startService(Intent(this, SmsForegroundService::class.java))

    private fun stopSmsFgService() = stopService(Intent(this, SmsForegroundService::class.java))
    private lateinit var channel: MethodChannel // Store the channel to invoke Dart methods
    private val handler = Handler(Looper.getMainLooper())
    private var responsePending = false
    private val processedMessages = mutableSetOf<String>() // For deduplication
    private var expectedPhoneNumber: String? = null // Store the expected phone number
    private var activePhoneNumber: String? = null // Tracks the current device's phone number (NEW)

    private val PERMISSIONS_REQUEST_CODE = 123
    private val REQUIRED_PERMISSIONS = arrayOf(
        android.Manifest.permission.READ_SMS,
        android.Manifest.permission.SEND_SMS,
        android.Manifest.permission.RECEIVE_SMS,
        android.Manifest.permission.READ_PHONE_STATE,
        android.Manifest.permission.READ_PHONE_NUMBERS,
        android.Manifest.permission.INTERNET,
        android.Manifest.permission.WAKE_LOCK,
        android.Manifest.permission.FOREGROUND_SERVICE,
        android.Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
        android.Manifest.permission.RECEIVE_BOOT_COMPLETED,
        android.Manifest.permission.POST_NOTIFICATIONS,
        android.Manifest.permission.FOREGROUND_SERVICE_DATA_SYNC
    )
@RequiresApi(Build.VERSION_CODES.M)
private fun promptIgnoreBatteryOpt() {
    val pm = getSystemService(POWER_SERVICE) as PowerManager
    if (!pm.isIgnoringBatteryOptimizations(packageName)) {
        startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:$packageName"))
        )
    }
}

    private var receiverRegistered = false

    private var lastCounterResetDay = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            WebhookLogger.logEvent("APP_STARTED", mapOf(
                "packageName" to packageName,
                "versionCode" to packageManager.getPackageInfo(packageName, 0).versionCode,
                "versionName" to packageManager.getPackageInfo(packageName, 0).versionName
            ), this)

            if (!arePermissionsGranted()) {
                WebhookLogger.logEvent("PERMISSIONS_REQUESTED", mapOf(
                    "permissions" to REQUIRED_PERMISSIONS.joinToString(", ")
                ), this)
                requestPermissions(REQUIRED_PERMISSIONS, PERMISSIONS_REQUEST_CODE)
            } else {
                WebhookLogger.logEvent("PERMISSIONS_ALREADY_GRANTED", emptyMap(), this)
                initializeApp()
            }
        } catch (e: Exception) {
            WebhookLogger.logException("onCreate", e, emptyMap(), this)
            // Continue with normal app initialization to avoid breaking functionality
            if (!arePermissionsGranted()) {
                requestPermissions(REQUIRED_PERMISSIONS, PERMISSIONS_REQUEST_CODE)
            } else {
                initializeApp()
            }
        }
    }

        override fun onResume() {
        super.onResume()
        // This is called when the user returns to the app, e.g., from the settings screen.
        // We check permissions again and initialize if they've been granted.
        if (arePermissionsGranted() && !receiverRegistered) {
            WebhookLogger.logEvent("APP_RESUMED_WITH_PERMISSIONS", emptyMap(), this)
            initializeApp()
        }
    }

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    
    // Check if we were started from SMS broadcast
    if (intent.hasExtra("sms_number")) {
        val phoneNumber = intent.getStringExtra("sms_number") ?: ""
        val messageBody = intent.getStringExtra("sms_body") ?: ""
        val timestamp = intent.getLongExtra("sms_timestamp", System.currentTimeMillis())
        
        Thread {
            try {
                // Instead of: val params = mapOf()
                // Pass raw SMS data to Dart for parsing
                val rawSmsData = mapOf(
                    "phoneNumber" to phoneNumber,
                    "messageBody" to messageBody,
                    "timestamp" to timestamp
                )
                
                // Update UI on main thread
                handler.post {
                    // Check if this is the active device we should display messages for
                    if (phoneNumber == activePhoneNumber || activePhoneNumber == null) {
                        channel.invokeMethod("onRawSmsReceived", rawSmsData)
                        WebhookLogger.logEvent("SMS_PROCESSED_FOR_UI", mapOf(
                            "senderNumber" to phoneNumber,
                            "activePhone" to activePhoneNumber,
                            "source" to "onNewIntent",
                            "uiUpdated" to true
                        ), this)
                    }
                    
                    // ... rest of the existing logic
                }
            } catch (e: Exception) {
                // ... existing error handling
            }
        }.start()

    }
}


    private fun arePermissionsGranted(): Boolean {
        return REQUIRED_PERMISSIONS.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        try {
            if (requestCode == PERMISSIONS_REQUEST_CODE) {
                val permissionResults = permissions.zip(grantResults.map {
                    it == PackageManager.PERMISSION_GRANTED
                }).toMap()

                WebhookLogger.logEvent("PERMISSION_RESULTS", permissionResults, this)

                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    WebhookLogger.logEvent("ALL_PERMISSIONS_GRANTED", emptyMap(), this)
                    initializeApp()
                } else {
                    WebhookLogger.logEvent("SOME_PERMISSIONS_DENIED", emptyMap(), this)
                    showPermissionAlert()
                }
            }
        } catch (e: Exception) {
            WebhookLogger.logException("onRequestPermissionsResult", e, mapOf(
                "requestCode" to requestCode,
                "permissions" to permissions.joinToString(", ")
            ), this)
            // Continue with normal permission handling
            if (requestCode == PERMISSIONS_REQUEST_CODE) {
                if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    initializeApp()
                } else {
                    showPermissionAlert()
                }
            }
        }
    }

    private fun initializeApp() {
        WebhookLogger.logEvent("APP_INITIALIZED", emptyMap(), this)
        registerSmsReceiver()
    }

    private fun showPermissionAlert() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("Permissions Required")
            .setMessage("This app requires SMS and Phone permissions to function properly.")
            .setPositiveButton("Open Settings") { dialog, _ ->
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                val uri = Uri.fromParts("package", packageName, null)
                intent.data = uri
                startActivity(intent)
            }
            .setNegativeButton("Cancel") { dialog, _ ->
                dialog.dismiss()
            }
            .show()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            try {
                WebhookLogger.logEvent("FLUTTER_METHOD_CALL", mapOf("method" to call.method, "arguments" to call.arguments), this)
                when (call.method) {
                    "sendSmsAndWaitForResponse" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")
                        val senderNumber = call.argument<String>("senderNumber")
                        if (phoneNumber != null && message != null) {
                            sendSmsAndWaitForResponse(phoneNumber, message, senderNumber, result)
                        } else {
                            result.error("INVALID_ARGUMENT", "Phone number or message is missing", null)
                        }
                    }
                    "setActivePhoneNumber" -> {
                        activePhoneNumber = call.argument<String>("phoneNumber")?.replace("+91", "")
                        WebhookLogger.logEvent("SET_ACTIVE_PHONE", mapOf("newActiveNumber" to activePhoneNumber), this)
                        Log.d("SMS_ACTIVE", "Active phone number set to: $activePhoneNumber")
                        result.success(null)
                    }
                    "promptIgnoreBatteryOpt" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            promptIgnoreBatteryOpt()
                        }
                        result.success(null)
                    }
                    "getDailySmsCount" -> {
                        val num = call.argument<String>("phoneNumber") ?: ""
                        result.success(getDailySmsCount(num))
                    }
                    "startFg" -> { startSmsFgService(); result.success(null) }
                    "stopFg"  -> { stopSmsFgService();  result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                WebhookLogger.logException("configureFlutterEngine", e, mapOf("method" to call.method), this)
                result.error("NATIVE_ERROR", "An unexpected error occurred in native code.", e.message)
            }
        }
    }



private fun getDailySmsCount(address: String): Int {
    val clean = address.replace("+91", "").replace(" ", "")
    val uri = Telephony.Sms.Inbox.CONTENT_URI
    val cal = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }
    val start = cal.timeInMillis
    val end = start + TimeUnit.DAYS.toMillis(1) - 1
    val cursor = contentResolver.query(
        uri, arrayOf("date"),
        "${Telephony.Sms.ADDRESS} LIKE ? AND date BETWEEN ? AND ?",
        arrayOf("%$clean", start.toString(), end.toString()),
        null
    )
    val count = cursor?.count ?: 0
    cursor?.close()
    return count
}


fun parseDurationToMillis(timeStr: String): Long {
    try {
        val parts = timeStr.split(":")
        
        // Handle missing parts or malformed input
        if (parts.size < 3) {
            val paddedParts = parts.toMutableList()
            while (paddedParts.size < 3) {
                paddedParts.add("0")
            }
            val hours = paddedParts[0].toLongOrNull() ?: 0L
            val minutes = paddedParts[1].toLongOrNull() ?: 0L
            val seconds = paddedParts[2].toLongOrNull() ?: 0L
            return (hours * 3600 + minutes * 60 + seconds) * 1000
        }
        
        // Normal case
        val hours = parts[0].toLongOrNull() ?: 0L
        val minutes = parts[1].toLongOrNull() ?: 0L
        val seconds = parts[2].toLongOrNull() ?: 0L
        return (hours * 3600 + minutes * 60 + seconds) * 1000
    } catch (e: Exception) {
        Log.e("DURATION_ERROR", "Failed to parse duration: $timeStr", e)
        return 0L
    }
}
    fun calculateMotorOnTill(ts: Date, sinceTime: String, targetTime: String, mode: String): Date {
        try {
            WebhookLogger.logEvent("COUNTDOWN_CALCULATION_STARTED", mapOf(
                "timestamp" to formatDate(ts.time), "sinceTime" to sinceTime,
                "targetTime" to targetTime, "mode" to mode
            ), this)
            val sinceMillis = parseDurationToMillis(sinceTime)
            val targetMillis = parseDurationToMillis(targetTime)
            val calendar = Calendar.getInstance()
            calendar.time = ts
            if (mode.equals("Daily Auto", ignoreCase = true)) {
                val remainingMillis = targetMillis - sinceMillis
                if (remainingMillis > 0) {
                    calendar.add(Calendar.MILLISECOND, remainingMillis.toInt())
                }
            } else {
                calendar.add(Calendar.MILLISECOND, (-sinceMillis).toInt())
                calendar.add(Calendar.MILLISECOND, targetMillis.toInt())
            }
            WebhookLogger.logEvent("COUNTDOWN_CALCULATION_COMPLETED", mapOf(
                "timestamp" to formatDate(ts.time), "sinceTime" to sinceTime, "targetTime" to targetTime,
                "sinceMillis" to sinceMillis, "targetMillis" to targetMillis, "mode" to mode,
                "result" to formatDate(calendar.time.time)
            ), this)
            Log.d("CCCCCCCCCCCYCCCCCCCCCCCCC", "result of motorontill calc: ${calendar.time}")
            return calendar.time
        } catch (e: Exception) {
            WebhookLogger.logException("calculateMotorOnTill", e, mapOf(
                "timestamp" to formatDate(ts.time), "sinceTime" to sinceTime,
                "targetTime" to targetTime, "mode" to mode
            ), this)
            return ts // Return original timestamp to avoid breaking functionality
        }
    }

    private fun timeToSeconds(timeStr: String): Long {
        val parts = timeStr.split(":")
        if (parts.size != 3) return 0L
        val hours = parts[0].toLongOrNull() ?: 0L
        val minutes = parts[1].toLongOrNull() ?: 0L
        val seconds = parts[2].toLongOrNull() ?: 0L
        return (hours * 3600) + (minutes * 60) + seconds
    }

    private fun parseTimestamp(timestampStr: String): Long {
        return try {
            val sdf = SimpleDateFormat("dd/MM/yy-HH:mm", Locale.getDefault())
            val parts = timestampStr.replace("@", "").split("-")
            val dateTime = "${parts[0]}/25-${parts[1]}"
            sdf.parse(dateTime)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            Log.e("TIMESTAMP_ERROR", "Failed to parse timestamp: $e, str: $timestampStr")
            System.currentTimeMillis()
        }
    }

    private fun formatDate(timestamp: Long): String {
        val sdf = SimpleDateFormat("dd/MM/yy HH:mm:ss", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }

    private fun registerSmsReceiver() {
        if (!receiverRegistered) {
            try {
                val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
                registerReceiver(smsReceiver, filter)
                receiverRegistered = true
                WebhookLogger.logEvent("SMS_RECEIVER_REGISTERED", emptyMap(), this)
            } catch (e: Exception) {
                WebhookLogger.logException("registerSmsReceiver", e, emptyMap(), this)
            }
        }
    }

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                    val bundle = intent.extras
                    if (bundle != null) {
                        try {
                            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                            val fullMessage = StringBuilder()
                            for (message in messages) {
                                fullMessage.append(message.messageBody)
                            }
                            val phoneNumber = messages[0].originatingAddress?.replace("+91", "") ?: ""
                            val messageBody = fullMessage.toString()
                            val timestamp = messages[0].timestampMillis

                            WebhookLogger.logEvent("SMS_RECEIVED", mapOf(
                                "senderNumber" to phoneNumber, "messageBody" to messageBody,
                                "receivingNumber" to activePhoneNumber, "timestamp" to formatDate(timestamp)
                            ), context)

                            val messageKey = "$phoneNumber|$messageBody|$timestamp"
                            if (processedMessages.contains(messageKey)) {
                                Log.d("SMS_RECEIVER", "Duplicate message ignored: $messageKey")
                                WebhookLogger.logEvent("SMS_DUPLICATE", mapOf("senderNumber" to phoneNumber, "messageKey" to messageKey), context)
                                return
                            }
                            processedMessages.add(messageKey)
                            if (processedMessages.size > 100) {
                                processedMessages.remove(processedMessages.first())
                            }

                            val rawSmsData = mapOf(
                                "phoneNumber" to phoneNumber,
                                "messageBody" to messageBody,
                                "timestamp" to timestamp
                            )

                            WebhookLogger.logEvent("SMS_PARSED_VALUES", mapOf("senderNumber" to phoneNumber, "rawSmsData" to rawSmsData), context)

                            if (phoneNumber == activePhoneNumber || activePhoneNumber == null) {
                                channel.invokeMethod("onRawSmsReceived", rawSmsData)
                                WebhookLogger.logEvent("SMS_PROCESSED_FOR_UI", mapOf(
                                    "senderNumber" to phoneNumber, "activePhone" to activePhoneNumber, "uiUpdated" to true
                                ), context)
                                Log.d("SMS_RECEIVER", "UI updated for $phoneNumber (active: $activePhoneNumber)")
                            } else {
                                WebhookLogger.logEvent("SMS_IGNORED_NOT_ACTIVE", mapOf(
                                    "senderNumber" to phoneNumber, "activePhone" to activePhoneNumber
                                ), context)
                                Log.d("SMS_RECEIVER", "Ignoring SMS from $phoneNumber; active device is $activePhoneNumber")
                            }

                            if (responsePending && phoneNumber == expectedPhoneNumber) {
                                WebhookLogger.logEvent("AWAIT_RESPONSE_RECEIVED", mapOf(
                                    "expectedPhone" to expectedPhoneNumber, "actualPhone" to phoneNumber, "trigger" to "dismiss"
                                ), context)
                                channel.invokeMethod("responseReceived", null)
                                responsePending = false
                                expectedPhoneNumber = null
                                handler.removeCallbacksAndMessages(null)
                            }

                            logSmsToBackend(messageBody, phoneNumber, activePhoneNumber ?: "")
                        } catch (e: Exception) {
                            WebhookLogger.logException("smsReceiver.processMessage", e, mapOf("action" to (intent?.action ?: "null")), context)
                        }
                    }
                }
            } catch (e: Exception) {
                WebhookLogger.logException("smsReceiver.onReceive", e, mapOf("action" to (intent?.action ?: "null")), context)
            }
        }
    }

    private fun sendSmsAndWaitForResponse(phoneNumber: String, message: String, senderNumber: String?, result: MethodChannel.Result) {
        try {
            if (responsePending) {
                WebhookLogger.logEvent("SMS_SEND_REJECTED", mapOf(
                    "reason" to "Already awaiting response", "targetPhone" to phoneNumber, "message" to message
                ), this)
                result.error("BUSY", "Already awaiting a response", null)
                return
            }

            responsePending = true
            expectedPhoneNumber = phoneNumber.replace("+91", "")
            var smsManager = android.telephony.SmsManager.getDefault()

            if (senderNumber != null && ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                try {
                    val subscriptionManager = SubscriptionManager.from(this)
                    val subscriptions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        subscriptionManager.activeSubscriptionInfoList
                    } else {
                        @Suppress("DEPRECATION")
                        subscriptionManager.activeSubscriptionInfoList
                    }
                    var selectedSimId: Int? = null
                    subscriptions?.forEach { subscription ->
                        val simNumber = subscription.number?.replace("+91", "")
                        if (simNumber != null && simNumber == senderNumber.replace("+91", "")) {
                            selectedSimId = subscription.subscriptionId
                            smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                android.telephony.SmsManager.getSmsManagerForSubscriptionId(subscription.subscriptionId)
                            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                                @Suppress("DEPRECATION")
                                android.telephony.SmsManager.getSmsManagerForSubscriptionId(subscription.subscriptionId)
                            } else {
                                android.telephony.SmsManager.getDefault()
                            }
                            WebhookLogger.logEvent("SIM_SELECTION_SUCCESS", mapOf(
                                "simNumber" to simNumber, "subscriptionId" to subscription.subscriptionId
                            ), this)
                            Log.d("SMS_SENT", "Using SIM with number $simNumber for subscription ID ${subscription.subscriptionId}")
                        }
                    }
                    if (selectedSimId == null) {
                        WebhookLogger.logEvent("SIM_SELECTION_FAILED", mapOf(
                            "requestedNumber" to senderNumber, "availableSims" to (subscriptions?.map { it.number } ?: "N/A")
                        ), this)
                    }
                } catch (e: Exception) {
                    WebhookLogger.logException("simSelection", e, mapOf("senderNumber" to senderNumber), this)
                }
            }

            try {
                WebhookLogger.logEvent("SMS_SENDING", mapOf(
                    "receiverPhone" to phoneNumber, "message" to message, "senderNumber" to senderNumber
                ), this)
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                Log.d("SMS_SENT", "SMS sent to $phoneNumber: $message")
                WebhookLogger.logEvent("SMS_SENT_SUCCESS", mapOf("receiverPhone" to phoneNumber, "message" to message), this)

                WebhookLogger.logEvent("AWAIT_RESPONSE_TRIGGERED", mapOf(
                    "expectedPhone" to expectedPhoneNumber, "timeout" to "45s"
                ), this)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    handler.postDelayed({
                        if (responsePending) {
                            WebhookLogger.logEvent("AWAIT_RESPONSE_TIMEOUT", mapOf(
                                "expectedPhone" to expectedPhoneNumber, "originalMessage" to message, "trigger" to "dismiss"
                            ), this)
                            responsePending = false
                            expectedPhoneNumber = null
                            channel.invokeMethod("responseTimeout", null)
                            Log.d("SMS_TIMEOUT", "Response timed out for $phoneNumber")
                        }
                    }, 45000)
                } else {
                    @Suppress("DEPRECATION")
                    handler.postDelayed({
                        if (responsePending) {
                            WebhookLogger.logEvent("AWAIT_RESPONSE_TIMEOUT", mapOf(
                                "expectedPhone" to expectedPhoneNumber, "originalMessage" to message, "trigger" to "dismiss"
                            ), this)
                            responsePending = false
                            expectedPhoneNumber = null
                            channel.invokeMethod("responseTimeout", null)
                            Log.d("SMS_TIMEOUT", "Response timed out for $phoneNumber")
                        }
                    }, 45000)
                }
                result.success(null)
            } catch (e: Exception) {
                WebhookLogger.logException("sendSmsAttempt", e, mapOf(
                    "receiverPhone" to phoneNumber, "message" to message, "senderNumber" to senderNumber
                ), this)
                responsePending = false
                expectedPhoneNumber = null
                handler.removeCallbacksAndMessages(null)
                result.error("SMS_ERROR", "Failed to send SMS: ${e.message}", null)
            }
        } catch (e: Exception) {
            WebhookLogger.logException("sendSmsAndWaitForResponse", e, mapOf(
                "receiverPhone" to phoneNumber, "message" to message, "senderNumber" to senderNumber
            ), this)
            result.error("SMS_ERROR", "An unexpected error occurred: ${e.message}", null)
        }
    }

    private fun logSmsToBackend(message: String, senderNumber: String, receiverNumber: String) {
        Thread {
            try {
                val url = URL("https://nesmartconnect-uzggi.ondigitalocean.app/appuser/log-sms")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                
                val sharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val userId = sharedPreferences.getString("flutter.u_id", "")
                
                val postData = "sms_text=${URLEncoder.encode(message, "UTF-8")}" +
                              "&sender_phone=${URLEncoder.encode(senderNumber, "UTF-8")}" +
                              "&receiver_phone=${URLEncoder.encode(receiverNumber, "UTF-8")}" +
                              "&u_id=${URLEncoder.encode(userId ?: "", "UTF-8")}"
                
                val outputStream = connection.outputStream
                outputStream.write(postData.toByteArray())
                outputStream.flush()
                outputStream.close()
                
                val responseCode = connection.responseCode
                Log.d("SMS_LOGGING", "Backend response code: $responseCode")
                
            } catch (e: Exception) {
                Log.e("SMS_LOGGING", "Error logging SMS to backend: ${e.message}")
                WebhookLogger.logException("logSmsToBackend", e, mapOf("sender" to senderNumber, "receiver" to receiverNumber), this)
            }
        }.start()
    }

    override fun onDestroy() {
        WebhookLogger.logEvent("APP_DESTROYED", emptyMap(), this)
        if (receiverRegistered) {
            unregisterReceiver(smsReceiver)
            receiverRegistered = false
        }
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        super.onBackPressed()
    }
}