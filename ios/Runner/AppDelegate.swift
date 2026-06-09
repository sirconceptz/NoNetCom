import Flutter
import CoreBluetooth
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bleBridge: NoNetComBle?
  private var fileBridge: NoNetComFilePicker?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NoNetComBle") else {
      return
    }
    bleBridge = NoNetComBle(messenger: registrar.messenger())
    fileBridge = NoNetComFilePicker(messenger: registrar.messenger())
  }
}

final class NoNetComFilePicker: NSObject, UIDocumentPickerDelegate {
  private var pendingResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "skybridge/files", binaryMessenger: messenger)
      .setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickFile":
      guard pendingResult == nil else {
        result(FlutterError(code: "busy", message: "A file picker is already open", details: nil))
        return
      }
      pendingResult = result
      let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      rootController()?.present(picker, animated: true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(nil)
    pendingResult = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    do {
      let copied = try copyPickedFile(url)
      result(copied)
    } catch {
      result(FlutterError(code: "copy_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func copyPickedFile(_ url: URL) throws -> [String: Any] {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("skybridge-picked", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = url.lastPathComponent.isEmpty ? "plik" : url.lastPathComponent
    let destination = directory.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))-\(safeFileName(name))")
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: url, to: destination)
    let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
    let size = attributes[.size] as? NSNumber
    return ["path": destination.path, "name": name, "size": size?.intValue ?? 0]
  }

  private func safeFileName(_ name: String) -> String {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._ -")
    return name.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
  }

  private func rootController() -> UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  }
}

final class NoNetComBle: NSObject, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
  private let serviceUuid = CBUUID(string: "6d2f9877-2c82-456b-b3f5-09f0fd2f9a11")
  private let identityUuid = CBUUID(string: "6d2f9877-2c82-456b-b3f5-09f0fd2f9a12")
  private let rxUuid = CBUUID(string: "6d2f9877-2c82-456b-b3f5-09f0fd2f9a13")
  private let txUuid = CBUUID(string: "6d2f9877-2c82-456b-b3f5-09f0fd2f9a14")

  private var central: CBCentralManager!
  private var peripheralManager: CBPeripheralManager!
  private var sink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []
  private var displayName = "NoNetCom"
  private var publicKey = ""
  private var peripherals: [String: CBPeripheral] = [:]
  private var rxCharacteristics: [String: CBCharacteristic] = [:]
  private var subscribedCentrals: [String: CBCentral] = [:]
  private var txCharacteristic: CBMutableCharacteristic?
  private var centralWriteQueues: [String: [PendingWrite]] = [:]
  private var centralWriting = Set<String>()
  private var centralReady = Set<String>()
  private var notificationQueues: [String: [PendingWrite]] = [:]
  private var writeSequence: UInt64 = 0
  private var transportMessageSequence: UInt64 = 0
  private var inboundFragments: [String: InboundFragments] = [:]
  private var restoredPeripheralState = false

  private struct PendingWrite {
    let data: Data
    let priority: Int
    let sequence: UInt64
    let queuedAt: Date
  }

  private struct InboundFragments {
    let total: Int
    var chunks: [Int: Data] = [:]
  }

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "skybridge/ble", binaryMessenger: messenger)
      .setMethodCallHandler(handle)
    FlutterEventChannel(name: "skybridge/ble/events", binaryMessenger: messenger)
      .setStreamHandler(self)
    central = CBCentralManager(
      delegate: self,
      queue: nil,
      options: [
        CBCentralManagerOptionRestoreIdentifierKey: "com.matapps.nonetcom.central"
      ]
    )
    peripheralManager = CBPeripheralManager(
      delegate: self,
      queue: nil,
      options: [
        CBPeripheralManagerOptionRestoreIdentifierKey: "com.matapps.nonetcom.peripheral"
      ]
    )
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    for event in pendingEvents {
      events(event)
    }
    pendingEvents.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      let args = call.arguments as? [String: Any]
      displayName = args?["displayName"] as? String ?? "NoNetCom"
      publicKey = args?["publicKey"] as? String ?? ""
      guard central.state == .poweredOn, peripheralManager.state == .poweredOn else {
        result(FlutterError(code: "bluetooth_unavailable", message: "Bluetooth is not powered on", details: nil))
        return
      }
      if !restoredPeripheralState {
        configurePeripheral()
      }
      startAdvertising()
      emit(["type": "status", "peerId": "", "payload": "background_restoration_active"])
      result(nil)
    case "scan":
      guard central.state == .poweredOn else {
        result(FlutterError(code: "scan_unavailable", message: "Bluetooth is not powered on", details: nil))
        return
      }
      central.scanForPeripherals(withServices: [serviceUuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      result(nil)
    case "send":
      guard
        let args = call.arguments as? [String: Any],
        let peerId = args["peerId"] as? String,
        let payload = args["payload"] as? String,
        let priority = args["priority"] as? Int,
        let data = payload.data(using: .utf8)
      else {
        result(FlutterError(code: "bad_args", message: "peerId and payload are required", details: nil))
        return
      }
      send(peerId: peerId, data: data, priority: priority)
      result(nil)
    case "stopBackground":
      central.stopScan()
      peripheralManager.stopAdvertising()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    emit(["type": "status", "peerId": "", "payload": "central_\(central.state.rawValue)"])
  }

  func centralManager(
    _ central: CBCentralManager,
    willRestoreState dict: [String: Any]
  ) {
    let restored =
      dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    for peripheral in restored {
      let peerId = peripheral.identifier.uuidString
      peripherals[peerId] = peripheral
      peripheral.delegate = self
      emit(["type": "peer", "peerId": peerId, "name": peripheral.name ?? "Kontakt"])
      if peripheral.state == .connected {
        peripheral.discoverServices([serviceUuid])
      } else {
        central.connect(peripheral)
      }
    }
    emit([
      "type": "status",
      "peerId": "",
      "payload": "background_restored_central_\(restored.count)"
    ])
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    emit(["type": "status", "peerId": "", "payload": "peripheral_\(peripheral.state.rawValue)"])
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    willRestoreState dict: [String: Any]
  ) {
    restoredPeripheralState = true
    let services =
      dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []
    for service in services where service.uuid == serviceUuid {
      for characteristic in service.characteristics ?? [] {
        if characteristic.uuid == txUuid {
          txCharacteristic = characteristic as? CBMutableCharacteristic
        }
      }
    }
    emit([
      "type": "status",
      "peerId": "",
      "payload": "background_restored_peripheral_\(services.count)"
    ])
  }

  private func configurePeripheral() {
    peripheralManager.removeAllServices()
    let identity = CBMutableCharacteristic(
      type: identityUuid,
      properties: [.read],
      value: nil,
      permissions: [.readable]
    )
    let rx = CBMutableCharacteristic(
      type: rxUuid,
      properties: [.write, .writeWithoutResponse],
      value: nil,
      permissions: [.writeable]
    )
    let tx = CBMutableCharacteristic(
      type: txUuid,
      properties: [.notify],
      value: nil,
      permissions: [.readable]
    )
    let service = CBMutableService(type: serviceUuid, primary: true)
    service.characteristics = [identity, rx, tx]
    txCharacteristic = tx
    peripheralManager.add(service)
  }

  private func startAdvertising() {
    peripheralManager.stopAdvertising()
    peripheralManager.startAdvertising([
      CBAdvertisementDataServiceUUIDsKey: [serviceUuid],
      CBAdvertisementDataLocalNameKey: "NoNetCom"
    ])
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    let id = peripheral.identifier.uuidString
    guard peripherals[id] == nil else { return }
    peripherals[id] = peripheral
    peripheral.delegate = self
    emit(["type": "peer", "peerId": id, "name": peripheral.name ?? "Kontakt"])
    central.connect(peripheral)
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    peripheral.discoverServices([serviceUuid])
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    let peerId = peripheral.identifier.uuidString
    centralWriteQueues.removeValue(forKey: peerId)
    centralWriting.remove(peerId)
    centralReady.remove(peerId)
    emit(["type": "disconnected", "peerId": peerId])
    central.connect(peripheral)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    peripheral.services?
      .filter { $0.uuid == serviceUuid }
      .forEach { peripheral.discoverCharacteristics([identityUuid, rxUuid, txUuid], for: $0) }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    let peerId = peripheral.identifier.uuidString
    service.characteristics?.forEach { characteristic in
      if characteristic.uuid == rxUuid {
        rxCharacteristics[peerId] = characteristic
      } else if characteristic.uuid == identityUuid {
        peripheral.readValue(for: characteristic)
      } else if characteristic.uuid == txUuid {
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard characteristic.uuid == txUuid else { return }
    let peerId = peripheral.identifier.uuidString
    if let error {
      emit([
        "type": "status",
        "peerId": peerId,
        "payload": "transport_v2_notify_setup_error_\(error.localizedDescription)"
      ])
    }
    centralReady.insert(peerId)
    emit(["type": "status", "peerId": peerId, "payload": "transport_v2_ready"])
    pumpCentralWrites(peerId: peerId)
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    let peerId = peripheral.identifier.uuidString
    guard
      let value = characteristic.value,
      let payload = acceptTransportFragment(peerId: peerId, value: value)
    else { return }
    emit(["type": "payload", "peerId": peerId, "payload": payload])
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    guard characteristic.uuid == rxUuid else { return }
    let peerId = peripheral.identifier.uuidString
    if error == nil {
      if !(centralWriteQueues[peerId]?.isEmpty ?? true) {
        centralWriteQueues[peerId]?.removeFirst()
      }
    } else {
      emit([
        "type": "status",
        "peerId": peerId,
        "payload": "transport_v2_write_error_\(error!.localizedDescription)"
      ])
    }
    centralWriting.remove(peerId)
    pumpCentralWrites(peerId: peerId)
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    guard request.characteristic.uuid == identityUuid else {
      peripheral.respond(to: request, withResult: .attributeNotFound)
      return
    }
    request.value = identityPayload()
    peripheral.respond(to: request, withResult: .success)
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    requests.forEach { request in
      let peerId = request.central.identifier.uuidString
      guard
        request.characteristic.uuid == rxUuid,
        let value = request.value,
        let payload = acceptTransportFragment(peerId: peerId, value: value)
      else { return }
      emit(["type": "payload", "peerId": peerId, "payload": payload])
    }
    if let first = requests.first {
      peripheral.respond(to: first, withResult: .success)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    subscribedCentrals[central.identifier.uuidString] = central
    emit(["type": "peer", "peerId": central.identifier.uuidString, "name": "Kontakt"])
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    let peerId = central.identifier.uuidString
    subscribedCentrals.removeValue(forKey: peerId)
    notificationQueues.removeValue(forKey: peerId)
    emit(["type": "disconnected", "peerId": peerId])
  }

  private func send(peerId: String, data: Data, priority: Int) {
    writeSequence += 1
    let write = PendingWrite(
      data: data,
      priority: min(max(priority, 0), 3),
      sequence: writeSequence,
      queuedAt: Date()
    )
    let writes = fragmentPayload(data: write.data, priority: write.priority)
    if peripherals[peerId] != nil {
      for fragment in writes {
        enqueue(fragment, in: &centralWriteQueues, peerId: peerId)
      }
      pumpCentralWrites(peerId: peerId)
      return
    }
    if subscribedCentrals[peerId] != nil {
      for fragment in writes {
        enqueue(fragment, in: &notificationQueues, peerId: peerId)
      }
      pumpNotifications(peerId: peerId)
      return
    }
    emit(["type": "status", "peerId": peerId, "payload": "transport_v2_peer_not_ready"])
  }

  private func fragmentPayload(data: Data, priority: Int) -> [PendingWrite] {
    transportMessageSequence += 1
    let messageId = transportMessageSequence
    let chunkSize = 150
    let total = max(1, Int(ceil(Double(data.count) / Double(chunkSize))))
    return (0..<total).map { index in
      let start = index * chunkSize
      let end = min(start + chunkSize, data.count)
      var frame = Data([0x4e, 0x32])
      frame.append(contentsOf: integerBytes(messageId, count: 8))
      frame.append(contentsOf: integerBytes(UInt64(index), count: 2))
      frame.append(contentsOf: integerBytes(UInt64(total), count: 2))
      if start < end {
        frame.append(data.subdata(in: start..<end))
      }
      writeSequence += 1
      return PendingWrite(
        data: frame,
        priority: priority,
        sequence: writeSequence,
        queuedAt: Date()
      )
    }
  }

  private func acceptTransportFragment(peerId: String, value: Data) -> String? {
    let bytes = [UInt8](value)
    guard bytes.count >= 14, bytes[0] == 0x4e, bytes[1] == 0x32 else {
      return String(data: value, encoding: .utf8)
    }
    let messageId = readInteger(bytes, start: 2, count: 8)
    let index = Int(readInteger(bytes, start: 10, count: 2))
    let total = Int(readInteger(bytes, start: 12, count: 2))
    guard total > 0, total <= 4096, index < total else { return nil }
    let key = "\(peerId):\(messageId)"
    var inbound = inboundFragments[key] ?? InboundFragments(total: total)
    guard inbound.total == total else {
      inboundFragments.removeValue(forKey: key)
      return nil
    }
    inbound.chunks[index] = value.subdata(in: 14..<value.count)
    inboundFragments[key] = inbound
    guard inbound.chunks.count == total else { return nil }
    var output = Data()
    for chunkIndex in 0..<total {
      guard let chunk = inbound.chunks[chunkIndex] else { return nil }
      output.append(chunk)
    }
    inboundFragments.removeValue(forKey: key)
    return String(data: output, encoding: .utf8)
  }

  private func integerBytes(_ value: UInt64, count: Int) -> [UInt8] {
    (0..<count).map { offset in
      UInt8((value >> UInt64((count - offset - 1) * 8)) & 0xff)
    }
  }

  private func readInteger(_ bytes: [UInt8], start: Int, count: Int) -> UInt64 {
    (0..<count).reduce(UInt64(0)) { result, offset in
      (result << 8) | UInt64(bytes[start + offset])
    }
  }

  private func enqueue(
    _ write: PendingWrite,
    in queues: inout [String: [PendingWrite]],
    peerId: String
  ) {
    queues[peerId, default: []].append(write)
    queues[peerId]?.sort {
      $0.priority == $1.priority
        ? $0.sequence < $1.sequence
        : $0.priority < $1.priority
    }
    let count = queues[peerId]?.count ?? 0
    if count == 10 || count == 25 || count == 50 {
      emit(["type": "status", "peerId": peerId, "payload": "transport_v2_queue_\(count)"])
    }
  }

  private func pumpCentralWrites(peerId: String) {
    guard
      !centralWriting.contains(peerId),
      centralReady.contains(peerId),
      let peripheral = peripherals[peerId],
      peripheral.state == .connected,
      let characteristic = rxCharacteristics[peerId],
      let write = centralWriteQueues[peerId]?.first
    else { return }
    let maximum = peripheral.maximumWriteValueLength(for: .withResponse)
    guard write.data.count <= maximum else {
      centralWriteQueues[peerId]?.removeFirst()
      emit([
        "type": "status",
        "peerId": peerId,
        "payload": "transport_v2_payload_too_large_\(write.data.count)_mtu_\(maximum)"
      ])
      pumpCentralWrites(peerId: peerId)
      return
    }
    centralWriting.insert(peerId)
    peripheral.writeValue(write.data, for: characteristic, type: .withResponse)
  }

  private func pumpNotifications(peerId: String) {
    guard
      let tx = txCharacteristic,
      let central = subscribedCentrals[peerId],
      let write = notificationQueues[peerId]?.first
    else { return }
    guard write.data.count <= central.maximumUpdateValueLength else {
      notificationQueues[peerId]?.removeFirst()
      emit([
        "type": "status",
        "peerId": peerId,
        "payload": "transport_v2_payload_too_large_\(write.data.count)_mtu_\(central.maximumUpdateValueLength)"
      ])
      pumpNotifications(peerId: peerId)
      return
    }
    if peripheralManager.updateValue(write.data, for: tx, onSubscribedCentrals: [central]) {
      notificationQueues[peerId]?.removeFirst()
      pumpNotifications(peerId: peerId)
    }
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    for peerId in notificationQueues.keys {
      pumpNotifications(peerId: peerId)
    }
  }

  private func identityPayload() -> Data {
    let map: [String: Any] = [
      "type": "hello",
      "name": displayName,
      "publicKey": publicKey,
      "protocolVersion": 2,
      "capabilities": ["transport-v2", "e2ee-v2", "file-transfer", "live-voice"]
    ]
    return (try? JSONSerialization.data(withJSONObject: map)) ?? Data()
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async {
      if let sink = self.sink {
        sink(event)
      } else {
        self.pendingEvents.append(event)
      }
    }
  }
}
