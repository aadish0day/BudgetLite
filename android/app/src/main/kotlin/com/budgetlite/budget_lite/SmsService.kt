package com.budgetlite.budget_lite

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.Cursor
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.auth.api.phone.SmsRetrieverClient
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class SmsService(private val activity: Activity, private val engine: FlutterEngine) {
    companion object {
        private const val TAG = "SmsService"
        private const val CHANNEL = "budget_lite/sms"
        private const val SMS_EVENTS = "budget_lite/sms_events"
        private const val READ_SMS_PERMISSION = Manifest.permission.READ_SMS
        private const val RECEIVE_SMS_PERMISSION = Manifest.permission.RECEIVE_SMS
        private const val REQUEST_CODE = 9001
        private const val SMS_CONSENT_REQUEST = 9002
    }

    private var methodChannel: MethodChannel
    private var eventChannel: EventChannel
    private var smsReceiver: SmsBroadcastReceiver? = null
    private var consentReceiver: SmsUserConsentReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var smsRetrieverClient: SmsRetrieverClient? = null
    private var isUsingRetriever = false

    init {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, SMS_EVENTS)

        smsRetrieverClient = SmsRetriever.getClient(activity)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> requestSmsPermission(result)
                "isSmsPermissionGranted" -> result.success(isSmsPermissionGranted())
                "startListening" -> startListening(result)
                "stopListening" -> stopListening(result)
                "scanInbox" -> scanInbox(result)
                "startSmsRetriever" -> startSmsRetriever(result)
                "stopSmsRetriever" -> stopSmsRetriever(result)
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun isSmsPermissionGranted(): Boolean {
        val readOk = ContextCompat.checkSelfPermission(activity, READ_SMS_PERMISSION) == PackageManager.PERMISSION_GRANTED
        val receiveOk = ContextCompat.checkSelfPermission(activity, RECEIVE_SMS_PERMISSION) == PackageManager.PERMISSION_GRANTED
        return readOk && receiveOk
    }

    private fun requestSmsPermission(result: Result) {
        if (isSmsPermissionGranted()) {
            result.success(true)
            return
        }
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(READ_SMS_PERMISSION, RECEIVE_SMS_PERMISSION),
            REQUEST_CODE
        )
        result.success(false)
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode == REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            eventSink?.success(mapOf("type" to "permission_result", "granted" to granted))
        } else if (requestCode == SMS_CONSENT_REQUEST) {
            // SMS User Consent result handled in SmsUserConsentReceiver
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == SMS_CONSENT_REQUEST) {
            consentReceiver?.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun startListening(result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ — use SMS Retriever API (one-time consent)
            // Broadcast receiver doesn't work without being default SMS app
            startSmsRetriever(result)
            return
        }

        // Android 12 and below — use broadcast receiver
        if (smsReceiver == null) {
            smsReceiver = SmsBroadcastReceiver { body, timestamp ->
                eventSink?.success(mapOf("type" to "sms_received", "body" to body, "timestamp" to timestamp))
            }
            val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
            filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY - 1
            ContextCompat.registerReceiver(activity, smsReceiver, filter, ContextCompat.RECEIVER_EXPORTED)
        }
        isUsingRetriever = false
        result.success(true)
    }

    private fun stopListening(result: Result) {
        smsReceiver?.let {
            activity.unregisterReceiver(it)
            smsReceiver = null
        }
        stopSmsRetriever(object : Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
        isUsingRetriever = false
        result.success(true)
    }

    /** Start SMS Retriever for one-time user consent (Android 13+) */
    private fun startSmsRetriever(result: Result) {
        if (isUsingRetriever) {
            result.success(true)
            return
        }

        val client = smsRetrieverClient ?: return result.success(false)

        // Start listening for SMS Retriever intent
        val task = client.startSmsUserConsent(null) // null = any sender

        task.addOnSuccessListener {
            isUsingRetriever = true
            Log.d(TAG, "SMS Retriever started successfully")
            result.success(true)
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start SMS Retriever", e)
            result.success(false)
        }
    }

    /** Stop SMS Retriever */
    private fun stopSmsRetriever(result: Result) {
        consentReceiver?.let {
            activity.unregisterReceiver(it)
            consentReceiver = null
        }
        isUsingRetriever = false
        result.success(true)
    }

    private fun scanInbox(result: Result) {
        if (ContextCompat.checkSelfPermission(activity, READ_SMS_PERMISSION) != PackageManager.PERMISSION_GRANTED) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val messages = mutableListOf<Map<String, Any>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        // UPI-related sender addresses
        val upiAddresses = listOf(
            "UPI-GPAY", "UPI-GPay", "UPI-Gpay", "Google Pay", "GPAY",
            "UPI-PHONEPE", "UPI-PhonePe", "UPI-Phonepe", "PhonePe", "PHONEPE",
            "UPI-PAYTM", "UPI-Paytm", "Paytm", "PAYTM",
            "KotakUPI", "HDFCBK", "ICICIUPI", "AXISUPI",
            "YESUPI", "SBUPI", "BOBUPI", "PNBUPI",
            "UPI", "upi"
        )
        val upiKeywords = listOf(
            "gpay", "google pay", "phonepe", "paytm",
            "upi", "unified payments interface",
            "ybl", "pay", "vpa"
        )

        val projection = arrayOf(
            Telephony.Sms.Inbox.BODY,
            Telephony.Sms.Inbox.ADDRESS,
            Telephony.Sms.Inbox.DATE
        )
        val selection = "${Telephony.Sms.Inbox.ADDRESS} LIKE ? OR ${Telephony.Sms.Inbox.BODY} LIKE ? OR ${Telephony.Sms.Inbox.BODY} LIKE ?"
        val selectionArgs = arrayOf(
            "%UPI%",                           // UPI-sender addresses
            "%Rs.%",                           // contains amount format
            "%₹%",                             // contains rupee symbol
        )

        try {
            val cursor: Cursor? = activity.contentResolver.query(
                uri, projection, selection, selectionArgs,
                "${Telephony.Sms.Inbox.DATE} DESC LIMIT 100"
            )
            cursor?.use { c ->
                while (c.moveToNext()) {
                    val body = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.Inbox.BODY)) ?: continue
                    val address = c.getString(c.getColumnIndexOrThrow(Telephony.Sms.Inbox.ADDRESS)) ?: ""
                    val timestamp = c.getLong(c.getColumnIndexOrThrow(Telephony.Sms.Inbox.DATE))
                    val lowerBody = body.lowercase()
                    // Filter to only UPI/direction-related messages
                    val isUpi = upiAddresses.any { address.contains(it, ignoreCase = true) } ||
                                upiKeywords.any { lowerBody.contains(it) } ||
                                lowerBody.contains("credited") ||
                                lowerBody.contains("debited") ||
                                lowerBody.contains("debit") ||
                                lowerBody.contains("spent") ||
                                lowerBody.contains("paid")
                    if (isUpi) {
                        messages.add(mapOf("body" to body, "timestamp" to timestamp))
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scanning inbox", e)
        }

        result.success(messages)
    }

    fun destroy() {
        stopListening(object : Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }
}

/** Broadcast receiver for Android 12 and below */
class SmsBroadcastReceiver(private val onSmsReceived: (String, Long) -> Unit) : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val body = sms.displayMessageBody ?: continue
                if (body.isNotBlank()) {
                    onSmsReceived(body, sms.timestampMillis)
                }
            }
        }
    }
}

/** Broadcast receiver for SMS User Consent (Android 13+) */
class SmsUserConsentReceiver(private val activity: Activity, private val service: SmsService) : BroadcastReceiver() {
    private var consentIntent: Intent? = null

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == SmsRetriever.SMS_RETRIEVED_ACTION) {
            consentIntent = intent
            // Show consent dialog to user
            val consentIntent = SmsRetriever.getConsentIntent(intent)
            if (consentIntent != null) {
                try {
                    activity.startActivityForResult(consentIntent, SmsService.SMS_CONSENT_REQUEST)
                } catch (e: Exception) {
                    Log.e("SmsUserConsent", "Failed to start consent activity", e)
                }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == SmsService.SMS_CONSENT_REQUEST && consentIntent != null) {
            if (resultCode == Activity.RESULT_OK) {
                // User consented - extract SMS
                val message = SmsRetriever.getSmsMessage(consentIntent!!, data)
                message?.let {
                    service.emitSmsReceived(it.messageBody ?: "", it.timestampMillis)
                }
            } else {
                // User denied or timed out
                Log.d("SmsUserConsent", "User denied consent or timed out")
            }
            consentIntent = null
        }
    }
}

/** Extension to emit SMS from SmsUserConsentReceiver */
private fun SmsService.emitSmsReceived(body: String, timestamp: Long) {
    eventSink?.success(mapOf("type" to "sms_received", "body" to body, "timestamp" to timestamp))
}