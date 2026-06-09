package com.matapps.nonetcom

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.OpenableColumns
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.util.PriorityQueue
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    private val serviceUuid: UUID = UUID.fromString("6d2f9877-2c82-456b-b3f5-09f0fd2f9a11")
    private val identityUuid: UUID = UUID.fromString("6d2f9877-2c82-456b-b3f5-09f0fd2f9a12")
    private val rxUuid: UUID = UUID.fromString("6d2f9877-2c82-456b-b3f5-09f0fd2f9a13")
    private val txUuid: UUID = UUID.fromString("6d2f9877-2c82-456b-b3f5-09f0fd2f9a14")
    private val cccdUuid: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    private lateinit var bluetoothManager: BluetoothManager
    private val adapter: BluetoothAdapter? by lazy { bluetoothManager.adapter }
    private var gattServer: BluetoothGattServer? = null
    private var sink: EventChannel.EventSink? = null
    private var displayName: String = "NoNetCom"
    private var publicKey: String = ""
    private val centralGatts = mutableMapOf<String, BluetoothGatt>()
    private val serverPeers = mutableMapOf<String, BluetoothDevice>()
    private val rxCharacteristics = mutableMapOf<String, BluetoothGattCharacteristic>()
    private val identityCharacteristics = mutableMapOf<String, BluetoothGattCharacteristic>()
    private val centralReady = mutableSetOf<String>()
    private val centralWriteQueues = mutableMapOf<String, PriorityQueue<PendingWrite>>()
    private val centralWriting = mutableSetOf<String>()
    private val serverWriteQueues = mutableMapOf<String, PriorityQueue<PendingWrite>>()
    private val serverNotifying = mutableSetOf<String>()
    private val negotiatedMtu = mutableMapOf<String, Int>()
    private val sequence = AtomicLong()
    private val transportMessageSequence = AtomicLong()
    private val inboundFragments = mutableMapOf<String, InboundFragments>()
    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private val utf8: Charset = Charsets.UTF_8
    private val permissionRequestCode = 8124
    private val pickFileRequestCode = 9125
    private val handler = Handler(Looper.getMainLooper())
    private var pendingFilePickResult: MethodChannel.Result? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(NoNetComApplication.engineId)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        (application as NoNetComApplication).ensureDartStarted()
    }

    private data class PendingWrite(
        val data: ByteArray,
        val priority: Int,
        val sequence: Long,
        val queuedAt: Long = System.currentTimeMillis(),
    )

    private data class InboundFragments(
        val total: Int,
        val chunks: MutableMap<Int, ByteArray> = mutableMapOf(),
    )

    private fun newQueue(): PriorityQueue<PendingWrite> =
        PriorityQueue(compareBy<PendingWrite> { it.priority }.thenBy { it.sequence })

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "skybridge/files")
            .setMethodCallHandler { call, result -> handleFileMethod(call, result) }

        if ((application as NoNetComApplication).claimBleBridge()) {
            bluetoothManager =
                getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "skybridge/ble")
                .setMethodCallHandler { call, result -> handleMethod(call, result) }

            EventChannel(flutterEngine.dartExecutor.binaryMessenger, "skybridge/ble/events")
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        sink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        sink = null
                    }
                })
        }
    }

    private fun handleFileMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFile" -> {
                if (pendingFilePickResult != null) {
                    result.error("busy", "A file picker is already open", null)
                    return
                }
                pendingFilePickResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                startActivityForResult(intent, pickFileRequestCode)
            }
            else -> result.notImplemented()
        }
    }

    @SuppressLint("MissingPermission")
    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                displayName = call.argument<String>("displayName") ?: "NoNetCom"
                publicKey = call.argument<String>("publicKey") ?: ""
                try {
                    ensureReady()
                    startGattServer()
                    startAdvertising()
                    NoNetComBleService.start(this)
                    emit(mapOf("type" to "status", "peerId" to "", "payload" to "background_service_active"))
                    result.success(null)
                } catch (error: IllegalStateException) {
                    result.error("bluetooth_unavailable", error.message, null)
                }
            }
            "scan" -> {
                try {
                    ensureReady()
                    startScan()
                    result.success(null)
                } catch (error: IllegalStateException) {
                    result.error("scan_unavailable", error.message, null)
                }
            }
            "send" -> {
                val peerId = call.argument<String>("peerId")
                val payload = call.argument<String>("payload")
                val priority = call.argument<Int>("priority") ?: 2
                if (peerId == null || payload == null) {
                    result.error("bad_args", "peerId and payload are required", null)
                    return
                }
                sendToPeer(peerId, payload, priority)
                result.success(null)
            }
            "stopBackground" -> {
                NoNetComBleService.stop(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureReady() {
        val currentAdapter = adapter ?: throw IllegalStateException("Bluetooth adapter not found")
        if (!currentAdapter.isEnabled) throw IllegalStateException("Bluetooth is disabled")
        val missing = missingPermissions()
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), permissionRequestCode)
            throw IllegalStateException("Bluetooth permission is missing; approve it and try again")
        }
    }

    private fun missingPermissions(): List<String> {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return permissions.filter { permission ->
            ActivityCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickFileRequestCode) return
        val result = pendingFilePickResult ?: return
        pendingFilePickResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            result.success(copyPickedFile(uri))
        } catch (error: Exception) {
            result.error("copy_failed", error.message, null)
        }
    }

    private fun copyPickedFile(uri: Uri): Map<String, Any> {
        val name = queryDisplayName(uri) ?: "plik"
        val directory = File(cacheDir, "skybridge-picked").also { it.mkdirs() }
        val destination = File(directory, "${System.currentTimeMillis()}-${safeFileName(name)}")
        contentResolver.openInputStream(uri).use { input ->
            FileOutputStream(destination).use { output ->
                requireNotNull(input) { "Cannot open selected file" }.copyTo(output)
            }
        }
        return mapOf(
            "path" to destination.absolutePath,
            "name" to name,
            "size" to destination.length(),
        )
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
        cursor.use {
            if (it != null && it.moveToFirst()) {
                val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) return it.getString(index)
            }
        }
        return uri.lastPathSegment
    }

    private fun safeFileName(name: String): String {
        return name.replace(Regex("[^A-Za-z0-9._ -]"), "_").ifBlank { "plik" }
    }

    @SuppressLint("MissingPermission")
    private fun startGattServer() {
        gattServer?.close()
        val service = BluetoothGattService(serviceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val identity = BluetoothGattCharacteristic(
            identityUuid,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        val rx = BluetoothGattCharacteristic(
            rxUuid,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        val tx = BluetoothGattCharacteristic(
            txUuid,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        tx.addDescriptor(BluetoothGattDescriptor(cccdUuid, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
        service.addCharacteristic(identity)
        service.addCharacteristic(rx)
        service.addCharacteristic(tx)
        txCharacteristic = tx
        gattServer = bluetoothManager.openGattServer(this, serverCallback).also { server ->
            server.addService(service)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        val advertiser = adapter?.bluetoothLeAdvertiser ?: throw IllegalStateException("BLE advertising is not supported")
        advertiser.stopAdvertising(advertiseCallback)
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(serviceUuid))
            .build()
        advertiser.startAdvertising(settings, data, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    private fun startScan() {
        val scanner = adapter?.bluetoothLeScanner ?: throw IllegalStateException("BLE scanning is not supported")
        val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(serviceUuid)).build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        scanner.stopScan(scanCallback)
        scanner.startScan(listOf(filter), settings, scanCallback)
    }

    @SuppressLint("MissingPermission")
    private fun connect(device: BluetoothDevice) {
        if (centralGatts.containsKey(device.address)) return
        val gatt = device.connectGatt(this, false, centralCallback, BluetoothDevice.TRANSPORT_LE)
        centralGatts[device.address] = gatt
        emit(mapOf("type" to "peer", "peerId" to device.address, "name" to (device.name ?: "Kontakt")))
    }

    @SuppressLint("MissingPermission")
    private fun sendToPeer(peerId: String, payload: String, priority: Int) {
        val writes = fragmentPayload(
            payload.toByteArray(utf8),
            priority.coerceIn(0, 3),
        )
        val centralGatt = centralGatts[peerId]
        val rx = rxCharacteristics[peerId]
        if (centralGatt != null && rx != null) {
            centralWriteQueues.getOrPut(peerId, ::newQueue).addAll(writes)
            emitQueuePressure(peerId, centralWriteQueues[peerId]?.size ?: 0)
            pumpCentralWrites(peerId)
            return
        }

        val serverDevice = serverPeers[peerId]
        val tx = txCharacteristic
        if (serverDevice != null && tx != null) {
            serverWriteQueues.getOrPut(peerId, ::newQueue).addAll(writes)
            emitQueuePressure(peerId, serverWriteQueues[peerId]?.size ?: 0)
            pumpServerNotifications(peerId)
            return
        }
        emit(mapOf("type" to "status", "peerId" to peerId, "payload" to "transport_v2_peer_not_ready"))
    }

    private fun fragmentPayload(payload: ByteArray, priority: Int): List<PendingWrite> {
        val messageId = transportMessageSequence.incrementAndGet()
        val chunkSize = 150
        val total = maxOf(1, (payload.size + chunkSize - 1) / chunkSize)
        return (0 until total).map { index ->
            val start = index * chunkSize
            val end = minOf(start + chunkSize, payload.size)
            val chunk = payload.copyOfRange(start, end)
            val buffer = ByteBuffer.allocate(14 + chunk.size)
            buffer.put(0x4e.toByte())
            buffer.put(0x32.toByte())
            buffer.putLong(messageId)
            buffer.putShort(index.toShort())
            buffer.putShort(total.toShort())
            buffer.put(chunk)
            PendingWrite(
                data = buffer.array(),
                priority = priority,
                sequence = sequence.incrementAndGet(),
            )
        }
    }

    private fun acceptTransportFragment(peerId: String, value: ByteArray): String? {
        if (value.size < 14 || value[0] != 0x4e.toByte() || value[1] != 0x32.toByte()) {
            return value.toString(utf8)
        }
        val buffer = ByteBuffer.wrap(value)
        buffer.get()
        buffer.get()
        val messageId = buffer.long
        val index = buffer.short.toInt() and 0xffff
        val total = buffer.short.toInt() and 0xffff
        if (total <= 0 || index >= total || total > 4096) return null
        val chunk = ByteArray(buffer.remaining())
        buffer.get(chunk)
        val key = "$peerId:$messageId"
        val inbound = inboundFragments.getOrPut(key) { InboundFragments(total) }
        if (inbound.total != total) {
            inboundFragments.remove(key)
            return null
        }
        inbound.chunks[index] = chunk
        if (inbound.chunks.size != total) return null
        val output = ByteArrayOutputStream()
        for (chunkIndex in 0 until total) {
            output.write(inbound.chunks[chunkIndex] ?: return null)
        }
        inboundFragments.remove(key)
        return output.toByteArray().toString(utf8)
    }

    @SuppressLint("MissingPermission")
    private fun pumpCentralWrites(peerId: String) {
        if (peerId in centralWriting || peerId !in centralReady) return
        val queue = centralWriteQueues[peerId] ?: return
        val write = queue.peek() ?: return
        val gatt = centralGatts[peerId] ?: return
        val characteristic = rxCharacteristics[peerId] ?: return
        val maximum = (negotiatedMtu[peerId] ?: 23) - 3
        if (write.data.size > maximum) {
            handler.postDelayed({ pumpCentralWrites(peerId) }, 100)
            return
        }
        centralWriting.add(peerId)
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(
                characteristic,
                write.data,
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
            ) == android.bluetooth.BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = write.data
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(characteristic)
        }
        if (!started) {
            centralWriting.remove(peerId)
            handler.postDelayed({ pumpCentralWrites(peerId) }, 40)
        }
    }

    @SuppressLint("MissingPermission")
    private fun pumpServerNotifications(peerId: String) {
        if (peerId in serverNotifying) return
        val queue = serverWriteQueues[peerId] ?: return
        val write = queue.peek() ?: return
        val device = serverPeers[peerId] ?: return
        val characteristic = txCharacteristic ?: return
        val maximum = (negotiatedMtu[peerId] ?: 23) - 3
        if (write.data.size > maximum) {
            handler.postDelayed({ pumpServerNotifications(peerId) }, 100)
            return
        }
        serverNotifying.add(peerId)
        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gattServer?.notifyCharacteristicChanged(
                device,
                characteristic,
                false,
                write.data,
            ) == android.bluetooth.BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = write.data
            @Suppress("DEPRECATION")
            gattServer?.notifyCharacteristicChanged(device, characteristic, false) == true
        }
        if (!started) {
            serverNotifying.remove(peerId)
            handler.postDelayed({ pumpServerNotifications(peerId) }, 40)
        }
    }

    private fun emitQueuePressure(peerId: String, size: Int) {
        if (size == 10 || size == 25 || size == 50) {
            emit(
                mapOf(
                    "type" to "status",
                    "peerId" to peerId,
                    "payload" to "transport_v2_queue_$size",
                ),
            )
        }
    }

    private fun identityPayload(): ByteArray {
        return """{"type":"hello","name":${json(displayName)},"publicKey":${json(publicKey)},"protocolVersion":2,"capabilities":["transport-v2","e2ee-v2","file-transfer","live-voice"]}""".toByteArray(utf8)
    }

    private fun json(value: String): String = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

    private fun emit(event: Map<String, Any?>) {
        runOnUiThread { sink?.success(event) }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) {
            emit(mapOf("type" to "status", "peerId" to "", "payload" to "advertise_error_$errorCode"))
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            connect(result.device)
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                serverPeers[device.address] = device
                emit(mapOf("type" to "peer", "peerId" to device.address, "name" to (device.name ?: "Kontakt")))
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                serverPeers.remove(device.address)
                serverWriteQueues.remove(device.address)
                serverNotifying.remove(device.address)
                emit(mapOf("type" to "disconnected", "peerId" to device.address))
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            negotiatedMtu[device.address] = mtu
            emit(mapOf("type" to "status", "peerId" to device.address, "payload" to "transport_v2_mtu_$mtu"))
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            val peerId = device.address
            if (status == BluetoothGatt.GATT_SUCCESS) {
                serverWriteQueues[peerId]?.poll()
            } else {
                emit(mapOf("type" to "status", "peerId" to peerId, "payload" to "transport_v2_notify_error_$status"))
            }
            serverNotifying.remove(peerId)
            pumpServerNotifications(peerId)
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, characteristic: BluetoothGattCharacteristic) {
            val value = if (characteristic.uuid == identityUuid) identityPayload() else ByteArray(0)
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            if (characteristic.uuid == rxUuid) {
                acceptTransportFragment(device.address, value)?.let { payload ->
                    emit(mapOf("type" to "payload", "peerId" to device.address, "payload" to payload))
                }
            }
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }
        }
    }

    private val centralCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                negotiatedMtu[gatt.device.address] = 23
                if (!gatt.requestMtu(517)) {
                    gatt.discoverServices()
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                val device = gatt.device
                centralGatts.remove(gatt.device.address)
                rxCharacteristics.remove(gatt.device.address)
                identityCharacteristics.remove(gatt.device.address)
                centralReady.remove(gatt.device.address)
                centralWriteQueues.remove(gatt.device.address)
                centralWriting.remove(gatt.device.address)
                negotiatedMtu.remove(gatt.device.address)
                emit(mapOf("type" to "disconnected", "peerId" to gatt.device.address))
                handler.postDelayed({ connect(device) }, 1500)
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val service = gatt.getService(serviceUuid) ?: return
            service.getCharacteristic(rxUuid)?.let { rxCharacteristics[gatt.device.address] = it }
            service.getCharacteristic(identityUuid)?.let {
                identityCharacteristics[gatt.device.address] = it
            }
            val tx = service.getCharacteristic(txUuid)
            if (tx != null) {
                gatt.setCharacteristicNotification(tx, true)
                val descriptor = tx.getDescriptor(cccdUuid)
                if (descriptor != null) {
                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    gatt.writeDescriptor(descriptor)
                    return
                }
            }
            readIdentityOrMarkReady(gatt)
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                negotiatedMtu[gatt.device.address] = mtu
                emit(mapOf("type" to "status", "peerId" to gatt.device.address, "payload" to "transport_v2_mtu_$mtu"))
            }
            gatt.discoverServices()
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int,
        ) {
            if (descriptor.uuid == cccdUuid) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    emit(mapOf("type" to "status", "peerId" to gatt.device.address, "payload" to "transport_v2_cccd_error_$status"))
                }
                readIdentityOrMarkReady(gatt)
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            if (characteristic.uuid != rxUuid) return
            val peerId = gatt.device.address
            if (status == BluetoothGatt.GATT_SUCCESS) {
                centralWriteQueues[peerId]?.poll()
            } else {
                emit(mapOf("type" to "status", "peerId" to peerId, "payload" to "transport_v2_write_error_$status"))
            }
            centralWriting.remove(peerId)
            pumpCentralWrites(peerId)
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (characteristic.uuid == identityUuid) {
                emit(mapOf("type" to "payload", "peerId" to gatt.device.address, "payload" to characteristic.value.toString(utf8)))
                markCentralReady(gatt.device.address)
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (characteristic.uuid == txUuid) {
                acceptTransportFragment(gatt.device.address, characteristic.value)?.let { payload ->
                    emit(mapOf("type" to "payload", "peerId" to gatt.device.address, "payload" to payload))
                }
            }
        }

        @SuppressLint("MissingPermission")
        private fun readIdentityOrMarkReady(gatt: BluetoothGatt) {
            val identity = identityCharacteristics.remove(gatt.device.address)
            if (identity == null || !gatt.readCharacteristic(identity)) {
                markCentralReady(gatt.device.address)
            }
        }

        private fun markCentralReady(peerId: String) {
            centralReady.add(peerId)
            emit(mapOf("type" to "status", "peerId" to peerId, "payload" to "transport_v2_ready"))
            pumpCentralWrites(peerId)
        }
    }
}
