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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.naren.NESmartConnect/sms"
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
        android.Manifest.permission.READ_PHONE_NUMBERS
    )

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

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    
    // Check if we were started from SMS broadcast
    if (intent.hasExtra("sms_number")) {
        val phoneNumber = intent.getStringExtra("sms_number") ?: ""
        val messageBody = intent.getStringExtra("sms_body") ?: ""
        val timestamp = intent.getLongExtra("sms_timestamp", System.currentTimeMillis())
        
        Thread {
            try {
                // Process the SMS
                val params = parseSms(messageBody, phoneNumber, timestamp)
                
                // Update UI on main thread
                handler.post {
                    // Check if this is the active device we should display messages for
                    if (phoneNumber == activePhoneNumber || activePhoneNumber == null) {
                        channel.invokeMethod("onSmsReceived", params)
                        WebhookLogger.logEvent("SMS_PROCESSED_FOR_UI", mapOf(
                            "senderNumber" to phoneNumber, 
                            "activePhone" to activePhoneNumber, 
                            "source" to "onNewIntent",
                            "uiUpdated" to true
                        ), this)
                    }
                    
                    // Check if we're waiting for a response from this number
                    if (responsePending && phoneNumber == expectedPhoneNumber) {
                        channel.invokeMethod("responseReceived", null)
                        responsePending = false
                        expectedPhoneNumber = null
                        handler.removeCallbacksAndMessages(null)
                        WebhookLogger.logEvent("AWAIT_RESPONSE_RECEIVED", mapOf(
                            "expectedPhone" to expectedPhoneNumber, 
                            "actualPhone" to phoneNumber, 
                            "source" to "onNewIntent",
                            "trigger" to "dismiss"
                        ), this)
                    }
                }
                
                // Log to backend
                logSmsToBackend(messageBody, phoneNumber, activePhoneNumber ?: "")
            } catch (e: Exception) {
                WebhookLogger.logException("onNewIntent_smsProcessing", e, mapOf(
                    "phoneNumber" to phoneNumber,
                    "messageLength" to messageBody.length
                ), this)
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
                    "readInitialSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber != null) {
                            val smsData = readInitialSms(phoneNumber)
                            result.success(smsData)
                        } else {
                            result.error("INVALID_ARGUMENT", "Phone number is required", null)
                        }
                    }
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
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                WebhookLogger.logException("configureFlutterEngine", e, mapOf("method" to call.method), this)
                result.error("NATIVE_ERROR", "An unexpected error occurred in native code.", e.message)
            }
        }
    }

    private fun readInitialSms(phoneNumber: String): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        Thread {
            try {
                readInitialSmsInternal(phoneNumber)
            } catch (e: Exception) {
                WebhookLogger.logException("readInitialSms_Thread", e, mapOf("phoneNumber" to phoneNumber), this)
            }
        }.start()
        return result
    }

    private fun readInitialSmsInternal(phoneNumber: String): Map<String, Any?> {
        WebhookLogger.logEvent("READ_INITIAL_SMS_START", mapOf("phoneNumber" to phoneNumber), this)
        val smsList = mutableListOf<Map<String, String>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE)
        val normalizedNumber = phoneNumber.replace("+91", "0")
        val selection = "${Telephony.Sms.ADDRESS} = ? OR ${Telephony.Sms.ADDRESS} = ?"
        val selectionArgs = arrayOf(phoneNumber, normalizedNumber)
        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT 8"

        val cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)

        val latestParams = mutableMapOf<String, Any?>(
            "lowVoltage" to "N/A", "highVoltage" to "N/A", "lowCurrent" to "N/A", "highCurrent" to "N/A",
            "overloadTripTime" to "N/A", "voltageTripTime" to "N/A", "dryRunTripTime" to "N/A", "singlePhaseTripTime" to "N/A",
            "maxRunTime" to "N/A", "dryRunRestartTime" to "N/A", "feedbackDelayTime" to "N/A",
            "phoneNumber1" to "N/A", "phoneNumber2" to "N/A", "phoneNumber3" to "N/A", "hostNumber" to "N/A",
            "lastSync" to "N/A",
            "id" to "N/A",
            "lastPingAction" to "N/A", "lastPingInitiator" to "N/A", "lastPingTimestamp" to "N/A",
            "voltageRY" to "N/A", "voltageYB" to "N/A", "voltageBR" to "N/A",
            "currentR" to "N/A", "currentY" to "N/A", "currentB" to "N/A",
            "motorState" to null, "error" to null, "mode" to null,
            "cyclicOnTime" to "N/A", "cyclicOffTime" to "N/A", "dailyAutoTime" to "N/A", "shiftTimerTime" to "N/A",
            "countdownMode" to "N/A", "countdownStatus" to "N/A", "countdownSince" to "N/A",
            "countdownTarget" to "N/A", "countdownDismissed" to false
        )

        val paramsToFind = mutableSetOf<String>().apply {
            addAll(latestParams.keys.filter { it != "error" && it != "countdownDismissed" })
        }

        var newestVoltageCurrentTimestamp: Long? = null
        var isFirstMessage = true

        try {
            cursor?.use {
                while (it.moveToNext()) {
                    val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)).replace("+91", "")
                    val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY))
                    val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    val smsData = mapOf(
                        "sender" to address,
                        "body" to body,
                        "timestamp" to date.toString(),
                        "date" to formatDate(date)
                    )
                    smsList.add(smsData)

                    val params = parseSms(body, phoneNumber, date)

                    if (isFirstMessage) {
                        latestParams["error"] = params["error"]
                        latestParams["countdownDismissed"] = params["countdownDismissed"]
                        isFirstMessage = false
                        Log.d("READ_INITIAL_SMS", "Newest SMS error set to: ${latestParams["error"]}, countdownDismissed set to: ${latestParams["countdownDismissed"]}")
                    }

                    if (params.containsKey("voltageRY") && params["voltageRY"] != "N/A") {
                        if (newestVoltageCurrentTimestamp == null || date > newestVoltageCurrentTimestamp!!) {
                            newestVoltageCurrentTimestamp = date
                        }
                    }

                    for ((key, value) in params) {
                        if (key != "error" && key != "countdownDismissed" && value != "N/A" && value != null && (latestParams[key] == "N/A" || latestParams[key] == null)) {
                            latestParams[key] = value
                            paramsToFind.remove(key)
                        }
                    }

                    if (paramsToFind.isEmpty()) {
                        Log.d("READ_INITIAL_SMS", "All core parameters found, stopping scan at timestamp: ${formatDate(date)}")
                        break
                    }
                }
            }
        } catch (e: Exception) {
            WebhookLogger.logException("readInitialSmsInternal_Cursor", e, mapOf("phoneNumber" to phoneNumber), this)
        } finally {
            cursor?.close()
        }

        if (newestVoltageCurrentTimestamp != null) {
            latestParams["lastSync"] = formatDate(newestVoltageCurrentTimestamp!!)
        }
        WebhookLogger.logEvent("READ_INITIAL_SMS_COMPLETE", mapOf("phoneNumber" to phoneNumber, "foundParams" to latestParams.keys), this)
        return latestParams
    }

    private fun parseSms(message: String, phoneNumber: String, timestamp: Long = System.currentTimeMillis()): Map<String, Any?> {
        val params = mutableMapOf<String, Any?>()
        try {
            // This log is too frequent for webhooks, keep it for local debugging only.
            // WebhookLogger.logEvent("SMS_PARSE_STARTED", mapOf(
            //     "phoneNumber" to phoneNumber,
            //     "messageLength" to message.length,
            //     "timestamp" to formatDate(timestamp)
            // ), this)
            Log.d("SMS_PARSE", "Raw SMS Body: '$message'")

            val lines = message.split("\n")
            val lastLine = lines.lastOrNull()?.trim() ?: ""
            Log.d("LAST_LINE_DEBUG", "Last Line: '$lastLine'")

            // ... (All existing Regex and parsing logic remains here) ...
            val timestampPattern = Regex("[@¡](\\d{2}/\\d{2}-\\d{2}:\\d{2}(?::\\d{2})?)")
            val slideronPattern = Regex("(?i)(MOTOR:\\s*ON|Motor\\s+successfully\\s+Turned\\s+ON|Motor\\s+Turned\\s+ON)")
            val slideroffPattern = Regex("(?i)(MOTOR:\\s*OFF|Motor\\s+successfully\\s+Turned\\s+OFF|Motor\\s+Turned\\s+OFF|MOTOR:\\s*[^\\n]*(error|fail|failed|failure)[^\\n]*|Motor\\s+Turned\\s+Off\\s+[^\\n]*(error|fail|failed|failure)[^\\n]*|[^\\n]*(error|fail|failed|failure)[^\\n]*|^Power\\s+is\\s+back)")
            val IdPattern = Regex("(?i)(?:ID|Device ID):\\s*([A-Z]{2}\\d{4})")
            val IdMatch = IdPattern.find(message)
            if (IdMatch != null) {
                params["id"] = IdMatch.groups[1]?.value ?: "N/A"
            }
            val responsestamp: Long = try {
                if (lastLine.startsWith("@") || lastLine.startsWith("¡")) {
                    val timeString = lastLine.removePrefix("@").removePrefix("¡")
                    val (date, time) = timeString.split("-")
                    val (day, month) = date.split("/")
                    val (hour, minute) = time.split(":")
                    Calendar.getInstance().apply {
                        set(Calendar.YEAR, Calendar.getInstance().get(Calendar.YEAR))
                        set(Calendar.MONTH, month.toInt() - 1)
                        set(Calendar.DAY_OF_MONTH, day.toInt())
                        set(Calendar.HOUR_OF_DAY, hour.toInt())
                        set(Calendar.MINUTE, minute.toInt())
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }.timeInMillis
                } else {
                    timestamp
                }
            } catch (e: Exception) {
                timestamp
            }
            val initiatorPattern = Regex("(?i)(Initiated\\s+by:|Init\\s+by:|Motor Turned ON By)\\s*(.+?)(?:\\s*$|\\s*\\n)")
            val initiatorMatch = initiatorPattern.find(message)
            if (initiatorMatch != null) {
                val lines_ping = message.split("\n").map { it.trim() }
                val initiator = initiatorMatch.groups[2]?.value ?: "N/A"
                Log.d("LAST_PING_DEBUG", "Initiator found: $initiator, Receipt Timestamp: $timestamp")
                val fdrs = formatDate(responsestamp)
                val fdts = formatDate(timestamp)
                val drs = Date(responsestamp)
                val dts = Date(timestamp)
                val rrs = responsestamp
                val rts = timestamp
                Log.d("___________________________________", "$fdrs, $fdts, $drs, $dts, $rrs, $rts")
                if (lines_ping.size >= 2 && initiatorPattern.containsMatchIn(lines_ping[1])) {
                    params["lastPingAction"] = lines_ping[0]
                    params["lastPingInitiator"] = initiator
                    params["lastPingTimestamp"] = formatDate(responsestamp)
                    Log.d("LAST_PING_DEBUG", "Second line match - Action: ${params["lastPingAction"]}")
                } else {
                    val firstLine = lines_ping.getOrNull(0) ?: ""
                    params["lastPingInitiator"] = initiator
                    params["lastPingTimestamp"] = formatDate(responsestamp)
                    when {
                        firstLine.startsWith("OL time", ignoreCase = true) -> {
                            params["lastPingAction"] = "Timings Check"
                            Log.d("LAST_PING_DEBUG", "Timings Check")
                        }
                        firstLine.startsWith("RY:", ignoreCase = true) -> {
                            params["lastPingAction"] = "Status Check"
                            Log.d("LAST_PING_DEBUG", "Status Check")
                        }
                        firstLine.startsWith("V=", ignoreCase = true) -> {
                            params["lastPingAction"] = "Status Check"
                            Log.d("LAST_PING_DEBUG", "Status Check")
                        }
                        firstLine.startsWith("Low Voltage =", ignoreCase = true) -> {
                            params["lastPingAction"] = "Protection values check"
                            Log.d("LAST_PING_DEBUG", "Protection values check")
                        }
                        else -> {
                            params["lastPingAction"] = "N/A"
                            Log.d("LAST_PING_DEBUG", "No specific action matched")
                        }
                    }
                }
            }
            val format1Pattern = Regex("(?i)RY:(\\d+)\\s*V/(\\d+\\.\\d)\\s*A\\s*YB:(\\d+)\\s*V/(\\d+\\.\\d)\\s*A\\s*BR:(\\d+)\\s*V/(\\d+\\.\\d)\\s*A")
            val format2Pattern = Regex("(?i)V=(\\d+),(\\d+),(\\d+)\\s*A=(\\d+\\.\\d),(\\d+\\.\\d),(\\d+\\.\\d)")
            val format3Pattern = Regex("(?i)R Current:(\\d+\\.\\d)\\s*Y Current:(\\d+\\.\\d)\\s*B Current:(\\d+\\.\\d)")
            val voltagePattern = Regex("(?i)V=(\\d+),(\\d+),(\\d+)")
            val currentPattern = Regex("(?i)A=(\\d+\\.\\d),(\\d+\\.\\d),(\\d+\\.\\d)")
            val singlePhasePattern = Regex("(?i)V:(\\d+)\\s*V/(\\d+\\.\\d)\\s*A")
            val match1 = format1Pattern.find(message)
            val match2 = format2Pattern.find(message)
            val match3 = format3Pattern.find(message)
            val matchVoltage = voltagePattern.find(message)
            val matchCurrent = currentPattern.find(message)
            val singlePhaseMatch = singlePhasePattern.find(message)
            if (match1 != null) {
                params["voltageRY"] = "${match1.groups[1]?.value} V"
                params["voltageYB"] = "${match1.groups[3]?.value} V"
                params["voltageBR"] = "${match1.groups[5]?.value} V"
                params["currentR"] = "${match1.groups[2]?.value} A"
                params["currentY"] = "${match1.groups[4]?.value} A"
                params["currentB"] = "${match1.groups[6]?.value} A"
            } else if (match2 != null) {
                params["voltageRY"] = "${match2.groups[1]?.value} V"
                params["voltageYB"] = "${match2.groups[2]?.value} V"
                params["voltageBR"] = "${match2.groups[3]?.value} V"
                params["currentR"] = "${match2.groups[4]?.value} A"
                params["currentY"] = "${match2.groups[5]?.value} A"
                params["currentB"] = "${match2.groups[6]?.value} A"
            } else if (singlePhaseMatch != null) {
                params["voltageRY"] = "${singlePhaseMatch.groups[1]?.value} V"
                params["currentR"] = "${singlePhaseMatch.groups[2]?.value} A"
                params["voltageYB"] = "N/A"
                params["voltageBR"] = "N/A"
                params["currentY"] = "N/A"
                params["currentB"] = "N/A"
                Log.d("SMS_PARSE", "Single phase values detected: Voltage=${params["voltageRY"]}, Current=${params["currentR"]}")
            } else {
                if (matchVoltage != null) {
                    params["voltageRY"] = "${matchVoltage.groups[1]?.value} V"
                    params["voltageYB"] = "${matchVoltage.groups[2]?.value} V"
                    params["voltageBR"] = "${matchVoltage.groups[3]?.value} V"
                }
                if (matchCurrent != null) {
                    params["currentR"] = "${matchCurrent.groups[1]?.value} A"
                    params["currentY"] = "${matchCurrent.groups[2]?.value} A"
                    params["currentB"] = "${matchCurrent.groups[3]?.value} A"
                }
                if (match3 != null) {
                    params["currentR"] = "${match3.groups[1]?.value} A"
                    params["currentY"] = "${match3.groups[2]?.value} A"
                    params["currentB"] = "${match3.groups[3]?.value} A"
                }
            }
            val hasVoltagesOrCurrents = (match1 != null || match2 != null || match3 != null)
            if (hasVoltagesOrCurrents) {
                params["lastSync"] = formatDate(responsestamp)
                Log.d("LAST_SYNC_DEBUG", "Last Sync updated to receipt timestamp due to voltages/currents: ${params["lastSync"]}")
            } else {
                Log.d("LAST_SYNC_DEBUG", "Last Sync set to current time (no voltages/currents): ${params["lastSync"]}")
            }
fun calculateDailySmsCount(): Int {
    try {
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(Telephony.Sms.DATE)
        val selection = "${Telephony.Sms.ADDRESS} = ?"
        val selectionArgs = arrayOf(phoneNumber)
        val calendar = Calendar.getInstance()
        val currentDay = calendar.get(Calendar.DAY_OF_YEAR)
        
        // Reset counter if day has changed
        if (currentDay != lastCounterResetDay) {
            lastCounterResetDay = currentDay
            return 0
        }
        
        calendar.apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDay = calendar.timeInMillis
        calendar.apply {
            set(Calendar.HOUR_OF_DAY, 23)
            set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 59)
            set(Calendar.MILLISECOND, 999)
        }
        val endOfDay = calendar.timeInMillis
        val dateSelection = "$selection AND ${Telephony.Sms.DATE} BETWEEN ? AND ?"
        val dateSelectionArgs = arrayOf(phoneNumber, startOfDay.toString(), endOfDay.toString())
        val cursor = contentResolver.query(uri, projection, dateSelection, dateSelectionArgs, null)
        val count = cursor?.count ?: -1
        cursor?.close()
        return count
    } catch (e: SecurityException) {
        Log.e("DAILY_SMS_COUNT", "Security exception: $e")
        return -1
    } catch (e: Exception) {
        Log.e("DAILY_SMS_COUNT", "Exception: $e")
        return -1
    }
}
            val phoneNumbersPattern = Regex("(?i)Registered\\s+Phone\\s+Nos:\\s*1\\.(\\d{10})\\s*2\\.(\\d{10})\\s*3\\.(\\d{10})")
            val phoneNumbersMatch = phoneNumbersPattern.find(message)
            if (phoneNumbersMatch != null) {
                val numbers = listOf(phoneNumbersMatch.groups[1]?.value, phoneNumbersMatch.groups[2]?.value, phoneNumbersMatch.groups[3]?.value)
                    .filter { it != "0000000000" && it != null }
                val n = numbers.size
                params["phoneNumber1"] = phoneNumbersMatch.groups[1]?.value ?: "N/A"
                params["phoneNumber2"] = phoneNumbersMatch.groups[2]?.value ?: "N/A"
                params["phoneNumber3"] = phoneNumbersMatch.groups[3]?.value ?: "N/A"
                params["n"] = n
                Log.d("RESPPPPPPPPPPPPLLLLLLLLLLLLLLLLLLLLLLLLLL", "n=$n")
            }
            val d = calculateDailySmsCount()
            params["d"] = d
            Log.d("RESPPPPPPPPPPPPLLLLLLLLLLLLLLLLLLLLLLLLLL", "d=$d")
            if (slideronPattern.containsMatchIn(message)) {
                params["motorState"] = true
            } else if (slideroffPattern.containsMatchIn(message)) {
                params["motorState"] = false
                params["countdownMode"] = "N/A"
                params["countdownStatus"] = "N/A"
                params["countdownSince"] = "00:00:00"
                params["countdownTarget"] = "00:00:00"
                params["countdownDismissed"] = false
            }
            val errorPatterns = mapOf(
                "Single Phase Error" to Regex("(?i)Single Phase Error"),
                "Feedback Failed Error" to Regex("(?i)Feedback Failed|Feedback not received"),
                "Dry Run Error" to Regex("(?i)Dry Run Error"),
                "High Voltage Error" to Regex("(?i)High Voltage Error"),
                "Unhealthy Voltage Error" to Regex("(?i)not healthy"),
                "Low Voltage Error" to Regex("(?i)Low Voltage"),
                "Overload Error" to Regex("(?i)over load Error")
            )
            var containsError = false
            for ((errorKeyword, pattern) in errorPatterns) {
                if (pattern.containsMatchIn(message)) {
                    params["error"] = errorKeyword
                    containsError = true
                    break
                }
            }
            if (!containsError) {
                params["error"] = null
            }
            val modePattern = Regex("(?i)(MODE:|Mode Changed To:)\\s*(Manual|Auto|Auto Start|Cyclic|Daily Auto|Shift Timer)")
            val modeMatch = modePattern.find(message)
            params["mode"] = when (modeMatch?.groups?.get(2)?.value?.lowercase()) {
                "manual" -> 0
                "auto", "auto start" -> 1
                "cyclic" -> 2
                "daily auto" -> 3
                "shift timer" -> 4
                else -> null
            }
            val cyclicOnPattern = Regex("(?i)(Set\\s+ON\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})|Cyclic time updated:\\s*(\\d{2}:\\d{2}:\\d{2}))")
            val cyclicOnMatch = cyclicOnPattern.find(message)
            if (cyclicOnMatch != null && message.contains("Cyclic", ignoreCase = true)) {
                params["cyclicOnTime"] = cyclicOnMatch.groups[2]?.value ?: cyclicOnMatch.groups[3]?.value ?: "00:00:00"
            }
            val cyclicOffPattern = Regex("(?i)(Set\\s+OFF\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})|Cyclic time updated:\\s*(\\d{2}:\\d{2}:\\d{2}))")
            val cyclicOffMatch = cyclicOffPattern.find(message)
            if (cyclicOffMatch != null && message.contains("Cyclic", ignoreCase = true)) {
                params["cyclicOffTime"] = cyclicOffMatch.groups[2]?.value ?: cyclicOffMatch.groups[3]?.value ?: "00:00:00"
            }
            val dailyAutoPattern = Regex("(?i)(Set\\s+ON\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})|Day Run time updated:\\s*(\\d{2}:\\d{2}:\\d{2}))")
            val dailyAutoMatch = dailyAutoPattern.find(message)
            if (dailyAutoMatch != null && message.contains("Daily", ignoreCase = true)) {
                params["dailyAutoTime"] = dailyAutoMatch.groups[2]?.value ?: dailyAutoMatch.groups[3]?.value ?: "00:00:00"
            }
            val shiftTimerPattern = Regex("(?i)(Set\\s+ON\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})|Shift Timer Time updated:\\s*(\\d{2}:\\d{2}:\\d{2}))")
            val shiftTimerMatch = shiftTimerPattern.find(message)
            if (shiftTimerMatch != null && message.contains("Shift", ignoreCase = true)) {
                params["shiftTimerTime"] = shiftTimerMatch.groups[2]?.value ?: shiftTimerMatch.groups[3]?.value ?: "00:00:00"
            }
            val countdownModePattern = Regex("(?i)MODE:\\s*(Shift Timer|Cyclic|Daily Auto)")
            val countdownStatusPattern = Regex("(?i)(?:STATUS:\\s*)?(ON|OFF)\\s*(Since|since)\\s*[:]?\\s*(\\d{2}:\\d{2}:\\d{2}|\\d{2}:\\d{2}:)")
            val setOnPattern = Regex("(?i)Set\\s+ON\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})")
            val setOffPattern = Regex("(?i)Set\\s+OFF\\s*:\\s*(\\d{2}:\\d{2}:\\d{2})")
            val dismissPattern = Regex("(?i)Set Run Time Completed.!")
            if (dismissPattern.containsMatchIn(message)) {
                params["countdownDismissed"] = true
            } else if (countdownModePattern.containsMatchIn(message) && countdownStatusPattern.containsMatchIn(message)) {
                val mode = countdownModePattern.find(message)?.groups?.get(1)?.value ?: "N/A"
                val statusMatch = countdownStatusPattern.find(message)
                val status = statusMatch?.groups?.get(1)?.value ?: "N/A"
                val sinceTimeMatch = statusMatch?.groups?.get(3)?.value
                val sinceTime = if (sinceTimeMatch?.length ?: 0 < 8) "${sinceTimeMatch}00" else sinceTimeMatch ?: "00:00:00"
                val targetTime = when (mode.lowercase()) {
                    "cyclic" -> if (status == "ON") setOffPattern.find(message)?.groups?.get(1)?.value else setOnPattern.find(message)?.groups?.get(1)?.value
                    "shift timer" -> shiftTimerPattern.find(message)?.let { it.groups[2]?.value ?: it.groups[3]?.value }
                    "daily auto" -> dailyAutoPattern.find(message)?.let { it.groups[2]?.value ?: it.groups[3]?.value }
                    else -> "00:00:00"
                } ?: "00:00:00"
                if (sinceTime != "00:00:00" || targetTime != "00:00:00") {
                    Log.d("COUNTDOWN_DEBUG", "sinceTime: $sinceTime, targetTime: $targetTime")
                    if (!containsError) {
                        params["countdownMode"] = mode
                        params["countdownStatus"] = status
                        params["countdownSince"] = sinceTime
                        val motorontill = calculateMotorOnTill(Date(responsestamp), sinceTime, targetTime, mode)
                        val sdf = SimpleDateFormat("dd/MM/yy HH:mm:ss", Locale.getDefault())
                        params["countdownTarget"] = sdf.format(motorontill)
                        params["countdownDismissed"] = false
                    } else {
                        params["countdownMode"] = "N/A"
                        params["countdownStatus"] = "N/A"
                        params["countdownSince"] = "00:00:00"
                        params["countdownTarget"] = "00:00:00"
                        params["countdownDismissed"] = false
                    }
                } else {
                    params["countdownMode"] = "N/A"
                    params["countdownStatus"] = "N/A"
                    params["countdownSince"] = "00:00:00"
                    params["countdownTarget"] = "00:00:00"
                    params["countdownDismissed"] = false
                }
            }
            val lowVoltagePattern = Regex("(?i)Low\\s*Voltage\\s*=\\s*(\\d{1,3})\\s*V")
            val lowVoltageMatch = lowVoltagePattern.find(message)
            if (lowVoltageMatch != null) params["lowVoltage"] = lowVoltageMatch.groups[1]?.value ?: "N/A"
            val highVoltagePattern = Regex("(?i)High\\s*Voltage\\s*=\\s*(\\d{1,3})\\s*V")
            val highVoltageMatch = highVoltagePattern.find(message)
            if (highVoltageMatch != null) params["highVoltage"] = highVoltageMatch.groups[1]?.value ?: "N/A"
            val highCurrentPattern = Regex("(?i)(?:High\\s*Current|Set High Current)\\s*(?:Updated:|=)\\s*(\\d{1,2})\\s*Amp[sS]")
            val setHcPattern = Regex("(?i)Set HC:\\s*(\\d{1,2})\\s*A")
            val highCurrentMatch = highCurrentPattern.find(message)
            val setHcMatch = setHcPattern.find(message)
            if (highCurrentMatch != null) {
                params["highCurrent"] = highCurrentMatch.groups[1]?.value ?: "N/A"
            } else if (setHcMatch != null) {
                params["highCurrent"] = setHcMatch.groups[1]?.value ?: "N/A"
            }
            val lowCurrentPattern = Regex("(?i)(?:Low\\s*Current|Set Low Current)\\s*(?:Updated:|=)\\s*(\\d{1,2})\\s*Amp[sS]")
            val setLcPattern = Regex("(?i)Set LC:\\s*(\\d{1,2})\\s*A")
            val lowCurrentMatch = lowCurrentPattern.find(message)
            val setLcMatch = setLcPattern.find(message)
            if (lowCurrentMatch != null) {
                params["lowCurrent"] = lowCurrentMatch.groups[1]?.value ?: "N/A"
            } else if (setLcMatch != null) {
                params["lowCurrent"] = setLcMatch.groups[1]?.value ?: "N/A"
            }
            val overloadTripPattern = Regex("(?i)(?:OL\\s*Time\\s*=|Over load time updated:)\\s*(\\d{1,3})\\s*Sec")
            val overloadTripMatch = overloadTripPattern.find(message)
            if (overloadTripMatch != null) params["overloadTripTime"] = overloadTripMatch.groups[1]?.value ?: "N/A"
            val voltageTripPattern = Regex("(?i)(?:Votlage\\s*Trip\\s*Time\\s*|Voltage\\s*Trip\\s*Time\\s*)(?:updated:|=)\\s*(\\d{1,3})\\s*Sec")
            val voltageTripMatch = voltageTripPattern.find(message)
            if (voltageTripMatch != null) params["voltageTripTime"] = voltageTripMatch.groups[1]?.value ?: "N/A"
            val dryRunTripPattern = Regex("(?i)(?:DR\\s*Time\\s*=|Dry Run time updated:)\\s*(\\d{1,3})\\s*Sec")
            val dryRunTripMatch = dryRunTripPattern.find(message)
            if (dryRunTripMatch != null) params["dryRunTripTime"] = dryRunTripMatch.groups[1]?.value ?: "N/A"
            val singlePhaseTripPattern = Regex("(?i)(?:SP\\s*Time\\s*=|Single phase time updated:)\\s*(\\d{1,3})\\s*Sec")
            val singlePhaseTripMatch = singlePhaseTripPattern.find(message)
            if (singlePhaseTripMatch != null) params["singlePhaseTripTime"] = singlePhaseTripMatch.groups[1]?.value ?: "N/A"
            val maxRunTimePattern = Regex("(?i)Max\\s+ON\\s+time\\s*(?:updated:|=)\\s*(\\d{2}:\\d{2}:\\d{2})")
            val maxRunTimeMatch = maxRunTimePattern.find(message)
            if (maxRunTimeMatch != null) params["maxRunTime"] = maxRunTimeMatch.groups[1]?.value ?: "00:00:00"
            val dryRunRestartPattern = Regex("(?i)(?:Dry\\s+Run\\s+restart\\s+time\\s+updated:|RS Time =)\\s*(\\d{2}:\\d{2})\\s*(?:HR:MM)?")
            val dryRunRestartMatch = dryRunRestartPattern.find(message)
            if (dryRunRestartMatch != null) params["dryRunRestartTime"] = dryRunRestartMatch.groups[1]?.value ?: "00:00"
            val feedbackDelayPattern = Regex("(?i)Feed\\s*back\\s*Delay\\s*=\\s*(\\d{1,2})\\s*Sec")
            val feedbackDelayMatch = feedbackDelayPattern.find(message)
            if (feedbackDelayMatch != null) params["feedbackDelayTime"] = feedbackDelayMatch.groups[1]?.value ?: "N/A"
            val phoneNumbers = phoneNumbersPattern.find(message)
            if (phoneNumbers != null) {
                params["phoneNumber1"] = phoneNumbers.groups[1]?.value ?: "N/A"
                params["phoneNumber2"] = phoneNumbers.groups[2]?.value ?: "N/A"
                params["phoneNumber3"] = phoneNumbers.groups[3]?.value ?: "N/A"
            }
            if (message.contains("Initiated by:(\\d+)".toRegex())) {
                val hostMatch = Regex("(?i)Initiated\\s+by:\\s*(\\d+)").find(message)
                params["hostNumber"] = hostMatch?.groups?.get(1)?.value ?: "N/A"
            }
            // ... (End of existing parsing logic) ...

            if (params.containsKey("motorState")) {
                WebhookLogger.logEvent("MOTOR_STATE_EXTRACTED", mapOf("motorState" to params["motorState"], "source" to "parseSms"), this)
            }
            if (params.containsKey("countdownMode") && params["countdownMode"] != "N/A") {
                WebhookLogger.logEvent("COUNTDOWN_DATA_EXTRACTED", mapOf(
                    "mode" to params["countdownMode"], "status" to params["countdownStatus"],
                    "since" to params["countdownSince"], "target" to params["countdownTarget"],
                    "dismissed" to params["countdownDismissed"]
                ), this)
            }
            // This log is also too frequent for webhooks.
            // WebhookLogger.logEvent("SMS_PARSE_COMPLETED", mapOf(
            //     "phoneNumber" to phoneNumber,
            //     "extractedParams" to params.keys.joinToString(", ")
            // ), this)
            Log.d("SMS_PARSE", "Parsed Parameters: $params")
            return params
        } catch (e: Exception) {
            WebhookLogger.logException("parseSms", e, mapOf(
                "phoneNumber" to phoneNumber,
                "messageLength" to message.length,
                "timestamp" to formatDate(timestamp)
            ), this)
            return params // Return whatever was parsed so far to avoid breaking functionality
        }
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

                            val params = parseSms(messageBody, phoneNumber, timestamp)
                            WebhookLogger.logEvent("SMS_PARSED_VALUES", mapOf("senderNumber" to phoneNumber, "extractedParams" to params), context)

                            if (phoneNumber == activePhoneNumber || activePhoneNumber == null) {
                                channel.invokeMethod("onSmsReceived", params)
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