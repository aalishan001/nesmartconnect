package com.naren.NESmartConnect

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class WebhookLogger {
    companion object {
        // PASTE YOUR NEW SLACK WEBHOOK URL HERE
        private const val WEBHOOK_URL = "https://hooks.slack.com/services/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" 
        private val executorService: ExecutorService = Executors.newSingleThreadExecutor()

        private fun getCurrentTimestamp(): String {
            val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
            return sdf.format(Date())
        }

        fun logEvent(eventType: String, details: Map<String, Any?>, context: Context? = null) {
            executorService.execute {
                try {
                    val deviceInfo = getDeviceInfo(context)
                    val isException = eventType == "EXCEPTION"

                    // Format for Slack Blocks
                    val slackPayload = JSONObject()
                    val blocksArray = JSONArray()

                    // Header Block
                    val headerText = if (isException) ":rotating_light: EXCEPTION :rotating_light:" else ":loudspeaker: $eventType"
                    blocksArray.put(JSONObject().apply {
                        put("type", "header")
                        put("text", JSONObject().put("type", "plain_text").put("text", headerText).put("emoji", true))
                    })

                    // Details Block
                    val detailsCopy = details.toMutableMap()
                    val stackTrace = detailsCopy.remove("stackTrace")?.toString()

                    val fieldsArray = JSONArray()
                    fieldsArray.put(JSONObject().put("type", "mrkdwn").put("text", "*Device:* \n${deviceInfo["model"]}"))
                    fieldsArray.put(JSONObject().put("type", "mrkdwn").put("text", "*Android:* \n${deviceInfo["androidVersion"]}"))
                    
                    detailsCopy.forEach { (key, value) ->
                        fieldsArray.put(JSONObject().put("type", "mrkdwn").put("text", "*${key.capitalize()}:* \n${value?.toString() ?: "null"}"))
                    }

                    if (fieldsArray.length() > 0) {
                        blocksArray.put(JSONObject().apply {
                            put("type", "section")
                            put("fields", fieldsArray)
                        })
                    }

                    // Stack Trace Block (if it exists)
                    if (stackTrace != null) {
                        blocksArray.put(JSONObject().put("type", "section").put("text", JSONObject().put("type", "mrkdwn").put("text", "```\n$stackTrace\n```")))
                    }
                    
                    // Timestamp footer
                    blocksArray.put(JSONObject().put("type", "context").put("elements", JSONArray().put(
                        JSONObject().put("type", "plain_text").put("text", "Logged at: ${getCurrentTimestamp()}").put("emoji", true)
                    )))

                    slackPayload.put("blocks", blocksArray)

                    sendWebhook(slackPayload.toString())
                    Log.d("WebhookLogger", "Event logged to Slack: $eventType")
                } catch (e: Exception) {
                    Log.e("WebhookLogger", "Error logging event to Slack: ${e.message}")
                }
            }
        }

        fun logException(methodName: String, exception: Throwable, additionalDetails: Map<String, Any?> = emptyMap(), context: Context? = null) {
            val details = mutableMapOf<String, Any?>(
                "methodName" to methodName,
                "exceptionType" to exception.javaClass.simpleName,
                "exceptionMessage" to exception.message,
                "stackTrace" to exception.stackTraceToString()
            )
            details.putAll(additionalDetails)
            
            logEvent("EXCEPTION", details, context)
        }
        
        private fun getDeviceInfo(context: Context?): Map<String, Any?> {
            val info = mutableMapOf<String, Any?>(
                "androidVersion" to Build.VERSION.RELEASE,
                "apiLevel" to Build.VERSION.SDK_INT,
                "manufacturer" to Build.MANUFACTURER,
                "model" to Build.MODEL,
                "device" to Build.DEVICE
            )
            
            if (context != null) {
                try {
                    val requiredPermissions = arrayOf(
                        android.Manifest.permission.READ_SMS,
                        android.Manifest.permission.SEND_SMS,
                        android.Manifest.permission.RECEIVE_SMS,
                        android.Manifest.permission.READ_PHONE_STATE,
                        android.Manifest.permission.READ_PHONE_NUMBERS
                    )
                    
                    requiredPermissions.forEach { permission ->
                        val granted = ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
                        info["permission_${permission.substringAfterLast('.')}"] = granted
                    }
                } catch (e: Exception) {
                    info["permission_error"] = e.message
                }
            }
            
            return info
        }
        
        private fun sendWebhook(payload: String) {
            try {
                val url = URL(WEBHOOK_URL)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                connection.doOutput = true
                
                val writer = OutputStreamWriter(connection.outputStream)
                writer.write(payload)
                writer.flush()
                writer.close()
                
                val responseCode = connection.responseCode
                if (responseCode >= 300) {
                    Log.e("WebhookLogger", "HTTP error code: $responseCode, Message: ${connection.responseMessage}")
                    // You can also read the error stream from the connection for more details
                    val errorStream = connection.errorStream?.bufferedReader()?.readText()
                    Log.e("WebhookLogger", "Error Body: $errorStream")
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e("WebhookLogger", "Error sending webhook: ${e.message}")
            }
        }
        
        private fun String.capitalize(): String {
            return this.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() }
        }
    }
}