import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "m44f4.omagate"
  ipcTarget: "m44f4.omagate"

  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("Panel.qml"))
    var path = decodeURIComponent(url.indexOf("file://") === 0 ? url.substring(7) : url)
    var tail = "/Panel.qml"
    if (path.length > tail.length && path.lastIndexOf(tail) === path.length - tail.length)
      return path.substring(0, path.length - tail.length)
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/m44f4.omagate"
  }

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/m44f4.omagate"

  // ==============================================================
  // Privileged helpers
  // ==============================================================

  // pkexec only ever runs these root-owned copies, installed once by the
  // user with omagate-install-helper.sh. The scripts in the plugin folder
  // are writable by the desktop user, so running them as root would let
  // any process of that user swap in its own code before the password
  // prompt. Block and write-protect stay hidden until the installed helper
  // matches this plugin's version.
  readonly property string helperDir: "/usr/local/libexec/omagate"
  property string helperVersion: ""
  readonly property bool helperReady:
    root.helperVersion !== "" && root.helperVersion === root.appVersion
  // Quoted only when needed, so the usual path stays readable but a home
  // directory with spaces or shell characters still pastes safely.
  readonly property string helperInstallCommand: {
    var path = root.pluginDir + "/bin/omagate-install-helper.sh"
    return "sudo bash " + (/^[A-Za-z0-9_.\/-]+$/.test(path) ? path : Util.shellQuote(path))
  }
  property bool helperCommandJustCopied: false

  function copyHelperCommand() {
    root.copyToClipboard(root.helperInstallCommand)
    root.helperCommandJustCopied = true
    helperCommandCopiedResetTimer.restart()
  }

  Timer {
    id: helperCommandCopiedResetTimer
    interval: 2200
    onTriggered: root.helperCommandJustCopied = false
  }

  FileView {
    id: helperVersionFile
    path: root.helperDir + "/VERSION"
    watchChanges: false
    printErrors: false

    onLoaded: root.helperVersion = String(text() || "").trim()
    onLoadFailed: root.helperVersion = ""
  }

  // ==============================================================
  // Manifest, About links
  // ==============================================================

  property string appVersion: ""
  property string appId: ""

  FileView {
    id: appManifestFile
    path: root.pluginDir + "/manifest.json"
    watchChanges: false
    printErrors: false

    onLoaded: {
      try {
        var data = JSON.parse(text())
        root.appVersion = data.version || ""
        root.appId = data.id || ""
      } catch (e) {}
    }
  }

  readonly property string updateCommand:
    "omarchy plugin update " + (root.appId.length > 0 ? root.appId : "m44f4.omagate")
  readonly property string repoUrl: "https://github.com/M44F4/omagate"

  property bool updateCommandJustCopied: false
  property bool repoUrlJustCopied: false

  function copyToClipboard(value) {
    Util.execDetached("printf '%s' " + Util.shellQuote(value) + " | wl-copy")
  }

  function copyUpdateCommand() {
    root.copyToClipboard(root.updateCommand)
    root.updateCommandJustCopied = true
    updateCommandCopiedResetTimer.restart()
  }

  function copyRepoUrl() {
    root.copyToClipboard(root.repoUrl)
    root.repoUrlJustCopied = true
    repoUrlCopiedResetTimer.restart()
  }

  Timer {
    id: updateCommandCopiedResetTimer
    interval: 2200
    onTriggered: root.updateCommandJustCopied = false
  }

  Timer {
    id: repoUrlCopiedResetTimer
    interval: 2200
    onTriggered: root.repoUrlJustCopied = false
  }

  // ==============================================================
  // Settings (persisted to <stateDir>/settings.json)
  // ==============================================================

  property bool settingsLoaded: false

  property string startView: "usb"          // "usb" | "last"
  property string lastView: "usb"
  property int refreshInterval: 2           // seconds; 0 = manual only
  property bool showNetworkTab: true
  property bool showDisplaysTab: true
  property bool showThunderboltTab: true
  property bool showDevPortsTab: true
  property bool notifyNewDevices: false
  property bool showInternalUsb: false
  property bool showVirtualInterfaces: false
  property string devPortsScope: "dev"      // "dev" | "all"
  property bool confirmStop: true

  function resetSettings() {
    root.startView = "usb"
    root.refreshInterval = 2
    root.showNetworkTab = true
    root.showDisplaysTab = true
    root.showThunderboltTab = true
    root.showDevPortsTab = true
    root.notifyNewDevices = false
    root.showInternalUsb = false
    root.showVirtualInterfaces = false
    root.devPortsScope = "dev"
    root.confirmStop = true
  }

  function applySettings(raw) {
    var d = {}
    try { d = JSON.parse(raw || "{}") || {} } catch (e) { d = {} }

    if (d.startView === "usb" || d.startView === "last") root.startView = d.startView
    if (typeof d.lastView === "string") root.lastView = d.lastView
    if ([0, 1, 2, 5].indexOf(d.refreshInterval) !== -1) root.refreshInterval = d.refreshInterval
    if (typeof d.showNetworkTab === "boolean") root.showNetworkTab = d.showNetworkTab
    if (typeof d.showDisplaysTab === "boolean") root.showDisplaysTab = d.showDisplaysTab
    if (typeof d.showThunderboltTab === "boolean") root.showThunderboltTab = d.showThunderboltTab
    if (typeof d.showDevPortsTab === "boolean") root.showDevPortsTab = d.showDevPortsTab
    if (typeof d.notifyNewDevices === "boolean") root.notifyNewDevices = d.notifyNewDevices
    if (typeof d.showInternalUsb === "boolean") root.showInternalUsb = d.showInternalUsb
    if (typeof d.showVirtualInterfaces === "boolean") root.showVirtualInterfaces = d.showVirtualInterfaces
    if (d.devPortsScope === "dev" || d.devPortsScope === "all") root.devPortsScope = d.devPortsScope
    if (typeof d.confirmStop === "boolean") root.confirmStop = d.confirmStop

    // Port Guard state is persisted explicitly. Older versions inferred it
    // from "a trusted snapshot exists", which never went away when the guard
    // was turned off; that check is kept only as a first-run fallback.
    if (typeof d.guardEnabled === "boolean")
      root.portGuardEnabled = d.guardEnabled
    else
      snapshotCheckProc.running = true

    root.settingsLoaded = true
  }

  // Any change to a persisted value re-evaluates this, which schedules a save.
  readonly property var settingsPayload: ({
    guardEnabled: root.portGuardEnabled,
    startView: root.startView,
    lastView: root.lastView,
    refreshInterval: root.refreshInterval,
    showNetworkTab: root.showNetworkTab,
    showDisplaysTab: root.showDisplaysTab,
    showThunderboltTab: root.showThunderboltTab,
    showDevPortsTab: root.showDevPortsTab,
    notifyNewDevices: root.notifyNewDevices,
    showInternalUsb: root.showInternalUsb,
    showVirtualInterfaces: root.showVirtualInterfaces,
    devPortsScope: root.devPortsScope,
    confirmStop: root.confirmStop
  })

  onSettingsPayloadChanged: if (root.settingsLoaded) settingsSaveTimer.restart()

  Timer {
    id: settingsSaveTimer
    interval: 250
    onTriggered: settingsFile.setText(JSON.stringify(root.settingsPayload, null, 2) + "\n")
  }

  Process {
    id: ensureStateDirProc
    command: ["mkdir", "-p", root.stateDir]
  }

  FileView {
    id: settingsFile
    path: root.stateDir + "/settings.json"
    watchChanges: false
    printErrors: false

    onLoaded: root.applySettings(text())
    onLoadFailed: root.applySettings("{}")
  }

  onDevPortsScopeChanged: if (root.settingsLoaded) root.refreshDevPorts()

  // ==============================================================
  // Trusted snapshot (read-only view for Settings)
  // ==============================================================

  property int trustedCount: 0
  property string trustedCreatedAt: ""

  FileView {
    id: trustedSnapshotFile
    path: root.stateDir + "/trusted-snapshot.json"
    watchChanges: true
    printErrors: false

    onFileChanged: reload()

    onLoaded: {
      try {
        var data = JSON.parse(text())
        root.trustedCount = Array.isArray(data.devices) ? data.devices.length : 0
        root.trustedCreatedAt = data.createdAt || ""
      } catch (e) {
        root.trustedCount = 0
        root.trustedCreatedAt = ""
      }
    }

    onLoadFailed: {
      root.trustedCount = 0
      root.trustedCreatedAt = ""
    }
  }

  readonly property string trustedSummary: {
    if (root.trustedCreatedAt === "")
      return "No snapshot yet. Turning Port Guard on takes one"
    var count = root.trustedCount + (root.trustedCount === 1 ? " device" : " devices")
    var when = new Date(root.trustedCreatedAt)
    return isNaN(when.getTime())
      ? count
      : count + "  ·  since " + Qt.formatDate(when, "d MMM yyyy")
  }

  // ==============================================================
  // Device state
  // ==============================================================

  property bool portGuardEnabled: false
  property bool portGuardBusy: false
  property bool retrustBusy: false

  property var devices: []
  property bool devicesLoaded: false
  property var knownDeviceKeys: ({})

  property var networkDevices: []
  property bool networkLoaded: false

  property var thunderboltDevices: []
  property bool thunderboltAvailable: true
  property bool thunderboltController: true
  property bool thunderboltLoaded: false

  property var externalDisplays: []
  property bool externalLoaded: false

  property var devPorts: []
  property bool devPortsLoaded: false

  property string ejectingDevpath: ""
  property string pendingWriteProtect: ""
  property string pendingBlock: ""
  property int pendingDevPortKill: -1
  property int confirmingStopPid: -1

  readonly property var storageDevices: root.devices.filter(function(d) {
    return d && d.kind === "storage"
  })

  // Every other USB device. Internal parts (removable === false) only when
  // asked for; a blocked device is always listed so it can be restored.
  readonly property var usbDevices: root.devices.filter(function(d) {
    return d && d.kind === "usb"
      && (d.removable === true || d.authorized === false || root.showInternalUsb)
  })

  readonly property var networkRows: root.networkDevices.filter(function(d) {
    return d && (root.showVirtualInterfaces || d.type === "Wi-Fi" || d.type === "Ethernet")
  })

  // Only blocks OmaGate made itself. A device another policy (USBGuard, for
  // example) denied is shown, but never counted, unblocked, or undone.
  readonly property int blockedDeviceCount: root.devices.filter(function(d) {
    return d && d.omagateBlocked === true
  }).length

  readonly property bool anyBlocked: root.blockedDeviceCount > 0

  readonly property bool canRetrust:
    !root.anyBlocked && !root.portGuardBusy && !root.retrustBusy && !snapshotProc.running

  function isBlockEligible(d) {
    return !!d
      && d.trusted === false
      && d.removable === true
      && d.hidPresent === false
  }

  function deviceKey(d) {
    return d.sysfsPort + "|" + d.name
  }

  function handleDevices(list) {
    var previous = root.knownDeviceKeys
    var next = {}

    for (var i = 0; i < list.length; i++) {
      var d = list[i]
      if (!d || !d.sysfsPort)
        continue

      var key = root.deviceKey(d)
      next[key] = true

      if (root.devicesLoaded
          && !previous[key]
          && root.notifyNewDevices
          && root.portGuardEnabled
          && d.authorized !== false
          && root.isBlockEligible(d))
        root.notifyNewDevice(d)
    }

    root.knownDeviceKeys = next
    root.devices = list
    root.devicesLoaded = true
  }

  function notifyNewDevice(d) {
    Quickshell.execDetached([
      "notify-send",
      "-a", "OmaGate",
      "-i", "drive-removable-media-usb",
      "New USB device",
      (d.name || "A USB device") + " was plugged in. Open OmaGate to block it."
    ])
  }

  // ==============================================================
  // Refresh
  // ==============================================================

  function refreshDevices() {
    if (!devicesProc.running)
      devicesProc.running = true
  }

  function refreshNetwork() {
    if (!networkProc.running)
      networkProc.running = true
  }

  function refreshThunderbolt() {
    if (!thunderboltProc.running)
      thunderboltProc.running = true
  }

  function refreshExternal() {
    if (!externalProc.running)
      externalProc.running = true
  }

  function refreshDevPorts() {
    if (!devPortsProc.running)
      devPortsProc.running = true
  }

  function refreshView(view) {
    if (view === "usb") root.refreshDevices()
    else if (view === "network") root.refreshNetwork()
    else if (view === "external") root.refreshExternal()
    else if (view === "thunderbolt") root.refreshThunderbolt()
    else if (view === "devports") root.refreshDevPorts()
  }

  function viewBusy(view) {
    if (view === "usb") return devicesProc.running
    if (view === "network") return networkProc.running
    if (view === "external") return externalProc.running
    if (view === "thunderbolt") return thunderboltProc.running
    if (view === "devports") return devPortsProc.running
    return false
  }

  // The icon only spins for a refresh you asked for, never for polling, and
  // for at least one full turn so a fast refresh is still visible.
  // Button.iconSpinning snaps the glyph back to 0° when it stops.
  property bool manualRefreshPending: false

  readonly property bool refreshSpinning:
    root.manualRefreshPending && (minSpinTimer.running || root.viewBusy(root.activeView))

  onRefreshSpinningChanged: if (!root.refreshSpinning) root.manualRefreshPending = false

  function manualRefresh() {
    if (!root.isListView(root.activeView))
      return
    root.manualRefreshPending = true
    minSpinTimer.restart()
    root.refreshView(root.activeView)
  }

  Timer {
    id: minSpinTimer
    interval: 900
  }

  Timer {
    interval: Math.max(1, root.refreshInterval) * 1000
    running: root.opened && root.refreshInterval > 0 && root.isListView(root.activeView)
    repeat: true
    onTriggered: root.refreshView(root.activeView)
  }

  // Hotplug watcher: keeps the device list (and so the bar icon, the badge
  // and new-device notifications) current while the panel is closed. The
  // devices script only runs when udev reports a change.
  Process {
    id: hotplugMonitor
    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb", "--subsystem-match=block"]

    stdout: SplitParser {
      onRead: function(line) {
        if (/\s(add|remove|change|bind|unbind)\s/.test(line))
          hotplugDebounce.restart()
      }
    }

    onExited: hotplugRestartTimer.restart()
  }

  Timer {
    id: hotplugDebounce
    interval: 500
    onTriggered: root.refreshDevices()
  }

  Timer {
    id: hotplugRestartTimer
    interval: 5000
    onTriggered: hotplugMonitor.running = true
  }

  // ==============================================================
  // Processes
  // ==============================================================

  Process {
    id: devicesProc
    command: ["bash", root.pluginDir + "/bin/omagate-devices.sh"]

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        var parsed = []
        try { parsed = JSON.parse(String(text || "[]")) } catch (e) { parsed = [] }
        root.handleDevices(Array.isArray(parsed) ? parsed : [])
      }
    }
  }

  Process {
    id: networkProc
    command: ["bash", root.pluginDir + "/bin/omagate-network.sh"]

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.networkDevices = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.networkDevices = []
        }
        root.networkLoaded = true
      }
    }
  }

  Process {
    id: thunderboltProc
    command: ["bash", root.pluginDir + "/bin/omagate-thunderbolt.sh"]

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "{}"))
          root.thunderboltAvailable = parsed.available !== false
          root.thunderboltController = parsed.controller !== false
          root.thunderboltDevices = Array.isArray(parsed.devices) ? parsed.devices : []
        } catch (e) {
          root.thunderboltAvailable = false
          root.thunderboltDevices = []
        }
        root.thunderboltLoaded = true
      }
    }
  }

  Process {
    id: externalProc
    command: ["bash", root.pluginDir + "/bin/omagate-external.sh"]

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.externalDisplays = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.externalDisplays = []
        }
        root.externalLoaded = true
      }
    }
  }

  Process {
    id: devPortsProc
    command: root.devPortsScope === "all"
      ? ["bash", root.pluginDir + "/bin/omagate-devports.sh", "--all"]
      : ["bash", root.pluginDir + "/bin/omagate-devports.sh"]

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.devPorts = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.devPorts = []
        }
        root.devPortsLoaded = true
      }
    }
  }

  // ==============================================================
  // Actions
  // ==============================================================

  function ejectDevice(devpath) {
    if (!devpath || root.ejectingDevpath !== "")
      return

    root.ejectingDevpath = devpath
    ejectProc.command = ["bash", root.pluginDir + "/bin/omagate-eject.sh", devpath]
    ejectProc.running = true
  }

  function setWriteProtect(devpath, readOnly) {
    if (!root.helperReady || !devpath || root.pendingWriteProtect !== "")
      return

    root.pendingWriteProtect = devpath
    writeProtectProc.command = [
      "pkexec", root.helperDir + "/omagate-writeprotect.sh",
      devpath, readOnly ? "ro" : "rw"
    ]
    writeProtectProc.running = true
  }

  function setBlocked(sysfsPort, blocked) {
    if (!root.helperReady || !sysfsPort || root.pendingBlock !== "")
      return

    root.pendingBlock = sysfsPort
    blockProc.command = [
      "pkexec", root.helperDir + "/omagate-block.sh",
      sysfsPort, blocked ? "0" : "1"
    ]
    blockProc.running = true
  }

  // A dev port row is one service: `pid` plus any listening child processes
  // folded into it (`pids`), which are stopped along with it.
  function requestStopDevPort(service) {
    if (!service || root.pendingDevPortKill !== -1)
      return

    if (root.confirmStop && root.confirmingStopPid !== service.pid) {
      root.confirmingStopPid = service.pid
      confirmStopTimer.restart()
      return
    }

    root.confirmingStopPid = -1
    root.killDevPort(service)
  }

  function killDevPort(service) {
    if (!service || !service.pid || service.pid <= 1 || root.pendingDevPortKill !== -1)
      return

    var pids = Array.isArray(service.pids) && service.pids.length > 0 ? service.pids : [service.pid]

    root.pendingDevPortKill = service.pid
    devPortKillProc.command = ["bash", root.pluginDir + "/bin/omagate-kill-devport.sh"]
      .concat(pids.map(function(p) { return String(p) }))
    devPortKillProc.running = true
  }

  Timer {
    id: confirmStopTimer
    interval: 3000
    onTriggered: root.confirmingStopPid = -1
  }

  // Network, display and Thunderbolt actions. Each script re-checks its own
  // safety rules (see bin/), so the panel is never the only guard. Anything
  // that turns something off needs a second click; turning back on does not.
  property string confirmingAction: ""
  property string pendingAction: ""
  property string copiedAddress: ""

  function runAction(key, command, needsConfirm) {
    if (root.pendingAction !== "")
      return

    if (needsConfirm && root.confirmingAction !== key) {
      root.confirmingAction = key
      confirmActionTimer.restart()
      return
    }

    root.confirmingAction = ""
    root.pendingAction = key
    actionProc.command = command
    actionProc.running = true
  }

  function setInterfaceConnected(iface, connect) {
    root.runAction("net:" + iface,
      ["bash", root.pluginDir + "/bin/omagate-network-action.sh", connect ? "connect" : "disconnect", iface],
      !connect)
  }

  function setDisplayOn(connector, on) {
    root.runAction("display:" + connector,
      ["bash", root.pluginDir + "/bin/omagate-display-action.sh", on ? "on" : "off", connector],
      !on)
  }

  function authorizeThunderbolt(uuid) {
    root.runAction("tb:" + uuid,
      ["bash", root.pluginDir + "/bin/omagate-thunderbolt-authorize.sh", uuid],
      false)
  }

  function copyAddress(address) {
    if (!address)
      return
    root.copyToClipboard(address)
    root.copiedAddress = address
    copiedAddressTimer.restart()
  }

  Timer {
    id: confirmActionTimer
    interval: 3000
    onTriggered: root.confirmingAction = ""
  }

  Timer {
    id: copiedAddressTimer
    interval: 2200
    onTriggered: root.copiedAddress = ""
  }

  Process {
    id: actionProc

    stderr: StdioCollector { id: actionStderr }

    onExited: function(exitCode) {
      root.pendingAction = ""
      if (exitCode !== 0) {
        Quickshell.execDetached([
          "notify-send", "-a", "OmaGate", "OmaGate",
          String(actionStderr.text || "The action did not complete").trim()
        ])
      }
      root.refreshView(root.activeView)
    }
  }

  Process {
    id: devPortKillProc
    onExited: {
      root.pendingDevPortKill = -1
      root.refreshDevPorts()
    }
  }

  Process {
    id: ejectProc
    onExited: {
      root.ejectingDevpath = ""
      root.refreshDevices()
    }
  }

  Process {
    id: writeProtectProc
    onExited: {
      root.pendingWriteProtect = ""
      root.refreshDevices()
    }
  }

  Process {
    id: blockProc
    onExited: {
      root.pendingBlock = ""
      root.refreshDevices()
    }
  }

  // ==============================================================
  // Port Guard
  // ==============================================================

  function togglePortGuard() {
    if (root.portGuardBusy || root.retrustBusy)
      return

    if (root.portGuardEnabled) {
      if (!root.anyBlocked) {
        root.portGuardEnabled = false
        return
      }

      root.portGuardBusy = true
      unblockAllProc.running = true
    } else {
      root.portGuardBusy = true
      snapshotCheckProc.forToggleOn = true
      snapshotCheckProc.running = true
    }
  }

  // Replace the trusted snapshot with whatever is connected right now.
  function retrustDevices() {
    if (!root.canRetrust)
      return

    root.retrustBusy = true
    snapshotProc.enablesGuard = false
    snapshotProc.running = true
  }

  Process {
    id: snapshotCheckProc

    property bool forToggleOn: false

    command: ["test", "-f", root.stateDir + "/trusted-snapshot.json"]

    onExited: function(exitCode) {
      var exists = exitCode === 0

      if (!snapshotCheckProc.forToggleOn) {
        // First-run fallback only (no persisted guard state yet).
        root.portGuardEnabled = exists
        return
      }

      snapshotCheckProc.forToggleOn = false

      if (exists) {
        root.portGuardEnabled = true
        root.portGuardBusy = false
        root.refreshDevices()
      } else {
        snapshotProc.enablesGuard = true
        snapshotProc.running = true
      }
    }
  }

  Process {
    id: snapshotProc

    property bool enablesGuard: false

    command: ["bash", root.pluginDir + "/bin/omagate-snapshot.sh"]

    onExited: function(exitCode) {
      // Only report Guard ON after snapshot creation actually succeeded.
      if (snapshotProc.enablesGuard) {
        if (exitCode === 0)
          root.portGuardEnabled = true
        root.portGuardBusy = false
      }

      snapshotProc.enablesGuard = false
      root.retrustBusy = false
      trustedSnapshotFile.reload()
      root.refreshDevices()
    }
  }

  Process {
    id: unblockAllProc
    command: ["pkexec", root.helperDir + "/omagate-unblock-all.sh"]

    onExited: function(exitCode) {
      // Only report Guard OFF after every unblock succeeded. A failed or
      // cancelled privileged operation must leave Guard enabled.
      if (exitCode === 0)
        root.portGuardEnabled = false

      root.portGuardBusy = false
      root.refreshDevices()
    }
  }

  Component.onCompleted: {
    ensureStateDirProc.running = true
    root.refreshDevices()
  }

  // ==============================================================
  // Views and tabs
  // ==============================================================

  property string activeView: "usb"

  readonly property var allTabs: [
    { id: "usb", icon: "󱇰", label: "USB devices" },
    { id: "network", icon: "󰤨", label: "Network" },
    { id: "external", icon: "󰍹", label: "Displays" },
    { id: "thunderbolt", icon: "󱐋", label: "Thunderbolt" },
    { id: "devports", icon: "󰆍", label: "Dev ports" }
  ]

  function tabVisible(id) {
    if (id === "usb") return true
    if (id === "network") return root.showNetworkTab
    if (id === "external") return root.showDisplaysTab
    if (id === "thunderbolt") return root.showThunderboltTab
    if (id === "devports") return root.showDevPortsTab
    return false
  }

  readonly property var visibleTabs: root.allTabs.filter(function(t) {
    return root.tabVisible(t.id)
  })

  onVisibleTabsChanged: {
    if (root.isListView(root.activeView) && !root.tabVisible(root.activeView))
      root.showView("usb")
  }

  function isListView(view) {
    return view !== "settings" && view !== "about"
  }

  function showView(view) {
    root.activeView = view
    root.confirmingStopPid = -1
    root.confirmingAction = ""
    viewFlickable.contentY = 0
    helperVersionFile.reload()

    if (root.isListView(view)) {
      root.lastView = view
      root.refreshView(view)
    }
  }

  function stepTab(delta) {
    var tabs = root.visibleTabs
    if (tabs.length === 0)
      return

    var index = -1
    for (var i = 0; i < tabs.length; i++)
      if (tabs[i].id === root.activeView) index = i

    var next = index === -1
      ? (delta > 0 ? 0 : tabs.length - 1)
      : (index + delta + tabs.length) % tabs.length
    root.showView(tabs[next].id)
  }

  function scrollBy(dy) {
    var maxY = Math.max(0, viewFlickable.contentHeight - viewFlickable.height)
    viewFlickable.contentY = Util.clamp(viewFlickable.contentY + dy * Style.space(48), 0, maxY)
  }

  function toggleSettingsView() {
    root.showView(root.activeView === "settings" ? root.lastView : "settings")
  }

  function toggleAboutView() {
    root.showView(root.activeView === "about" ? root.lastView : "about")
  }

  onOpenedChanged: {
    if (!root.opened)
      return

    helperVersionFile.reload()

    var view = root.startView === "last" ? root.lastView : "usb"
    if (!root.isListView(view) || !root.tabVisible(view))
      view = "usb"
    root.showView(view)

    if (view !== "usb")
      root.refreshDevices()
  }

  // ==============================================================
  // Icon and status
  // ==============================================================

  readonly property string icon:
    root.anyBlocked ? "󰦝" : (root.portGuardEnabled ? "󰒃" : "󰦜")

  readonly property string blockedText:
    root.blockedDeviceCount + (root.blockedDeviceCount === 1 ? " device blocked" : " devices blocked")

  readonly property bool awaitingAuth:
    root.pendingWriteProtect !== ""
    || root.pendingBlock !== ""
    || unblockAllProc.running

  readonly property string heroStatusText: {
    if (root.awaitingAuth) return "Waiting for password…"
    if (root.anyBlocked) return root.blockedText
    return root.portGuardEnabled ? "Port Guard on" : "Port Guard off"
  }

  readonly property string barTooltip:
    "OmaGate · " + (root.anyBlocked
      ? root.blockedText
      : (root.portGuardEnabled ? "Port Guard on" : "Port Guard off"))

  readonly property string toggleHint:
    root.portGuardEnabled ? "Turn Port Guard off" : "Turn Port Guard on"

  function titleCase(value) {
    var s = String(value || "")
    return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() : ""
  }

  function folderName(path) {
    if (!path) return ""
    if (path === Quickshell.env("HOME")) return "~"
    var parts = String(path).split("/")
    return parts[parts.length - 1] || path
  }

  function devPortIcon(kind) {
    if (kind === "jupyter") return ""
    if (kind === "python") return "󰌠"
    if (kind === "node") return "󰎙"
    if (kind === "docker") return "󰡨"
    if (kind === "database") return "󰆼"
    if (kind === "java") return "󰬷"
    if (kind === "rust") return "󱘗"
    if (kind === "go") return "󰟓"
    return "󰆍"
  }

  function devPortExposure(exposure) {
    if (exposure === "local") return "Local only"
    if (exposure === "network") return "Open to network"
    return exposure ? "On " + exposure : ""
  }

  // "2 kernels" for JupyterLab, "3 subprocesses" for anything else.
  function devPortChildren(children) {
    var n = (children || []).length
    if (n === 0) return ""
    var kernels = children.every(function(c) { return c.name === "Jupyter kernel" })
    return n + (kernels
      ? (n === 1 ? " kernel" : " kernels")
      : (n === 1 ? " subprocess" : " subprocesses"))
  }

  // ==============================================================
  // Bar button
  // ==============================================================

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    tooltipText: root.barTooltip

    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePortGuard()
      else root.toggle()
    }
  }

  // ==============================================================
  // Panel
  // ==============================================================

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.stepTab(dx)
        else if (dy !== 0) root.scrollBy(dy)
      }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.manualRefresh()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero: state icon · title + status · actions ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.portGuardEnabled || root.anyBlocked ? 1.0 : 0.5

            Behavior on opacity { NumberAnimation { duration: 140 } }
          }

          // Refresh sits leftmost so hiding it on Settings/About never shifts
          // the buttons you are about to click.
          RowLayout {
            id: heroActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              visible: root.isListView(root.activeView)
              iconText: "󰑐"
              tooltipText: "Refresh"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              iconSize: Style.font.subtitle * 1.5
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              iconSpinning: root.refreshSpinning
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.manualRefresh()
            }

            Button {
              iconText: "󰋼"
              tooltipText: root.activeView === "about" ? "Close About" : "About OmaGate"
              selected: root.activeView === "about"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              iconSize: Style.font.subtitle * 1.5
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.toggleAboutView()
            }

            Button {
              iconText: "󰒓"
              tooltipText: root.activeView === "settings" ? "Close Settings" : "Settings"
              selected: root.activeView === "settings"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              iconSize: Style.font.subtitle * 1.5
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.toggleSettingsView()
            }

            ToggleSwitch {
              id: powerSwitch
              checked: root.portGuardEnabled
              busy: root.portGuardBusy
              foreground: root.bar.foreground
              Layout.alignment: Qt.AlignVCenter
              Layout.leftMargin: Style.space(4)
              onToggled: root.togglePortGuard()

              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: root.toggleHint
                fontFamily: root.bar.fontFamily
              }
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroActions.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "OmaGate"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.heroStatusText.toUpperCase()
              color: root.anyBlocked ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        Text {
          visible: root.awaitingAuth
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: "Enter your password, or press Esc to cancel"
          color: Color.accent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        // ---------- Tabs ----------
        Row {
          id: tabBar
          visible: root.visibleTabs.length > 1
          width: parent.width

          Repeater {
            model: root.visibleTabs

            NavTab {
              required property var modelData
              width: tabBar.width / Math.max(1, root.visibleTabs.length)
              bar: root.bar
              icon: modelData.icon
              label: modelData.label
              active: root.activeView === modelData.id
              badge: modelData.id === "usb" ? root.blockedDeviceCount : 0
              onClicked: root.showView(modelData.id)
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        // ---------- Active view ----------
        // One scroll area for every view, with the same stock ScrollBar the
        // native Wi-Fi and Bluetooth panels use.
        Flickable {
          id: viewFlickable
          width: parent.width
          height: Math.min(contentHeight, Style.space(360))
          contentWidth: width
          contentHeight: views.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: views
            width: viewFlickable.width

            // ======================= USB =======================
            Column {
              visible: root.activeView === "usb"
              width: parent.width
              spacing: Style.space(14)

              Column {
                visible: root.portGuardEnabled && !root.helperReady
                width: parent.width
                spacing: Style.space(6)

                EmptyHint {
                  bar: root.bar
                  color: Color.accent
                  text: root.helperVersion === ""
                    ? "Block and write-protect need OmaGate's root-owned helper. Install it once from a terminal:"
                    : "OmaGate was updated. Update its root-owned helper from a terminal:"
                }

                CommandBlock {
                  bar: root.bar
                  command: root.helperInstallCommand
                  justCopied: root.helperCommandJustCopied
                  onCopyRequested: root.copyHelperCommand()
                }
              }

              Column {
                id: storageList
                width: parent.width
                spacing: Style.space(4)

                PanelSectionHeader {
                  text: "STORAGE"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                }

                EmptyHint {
                  bar: root.bar
                  visible: root.storageDevices.length === 0
                  text: root.devicesLoaded ? "No USB storage connected" : "Reading USB devices…"
                }

                Repeater {
                  model: root.storageDevices

                  DeviceRow {
                    required property var modelData
                    width: storageList.width
                    bar: root.bar
                    device: modelData
                    guardEnabled: root.portGuardEnabled
                    helperReady: root.helperReady
                    blockEligible: root.isBlockEligible(modelData)
                    busy: root.ejectingDevpath === modelData.devpath
                    writeProtectBusy: root.pendingWriteProtect === modelData.devpath
                    onEjectRequested: root.ejectDevice(modelData.devpath)
                    onWriteProtectToggled: function(readOnly) { root.setWriteProtect(modelData.devpath, readOnly) }
                  }
                }
              }

              PanelSeparator {
                foreground: root.bar.foreground
              }

              Column {
                id: usbList
                width: parent.width
                spacing: Style.space(4)

                PanelSectionHeader {
                  text: "USB DEVICES"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                }

                EmptyHint {
                  bar: root.bar
                  visible: root.usbDevices.length === 0
                  text: root.devicesLoaded ? "No other USB devices connected" : "Reading USB devices…"
                }

                Repeater {
                  model: root.usbDevices

                  DeviceRow {
                    required property var modelData
                    width: usbList.width
                    bar: root.bar
                    device: modelData
                    guardEnabled: root.portGuardEnabled
                    helperReady: root.helperReady
                    blockEligible: root.isBlockEligible(modelData)
                    blockBusy: root.pendingBlock === modelData.sysfsPort
                    onBlockToggled: function(blocked) { root.setBlocked(modelData.sysfsPort, blocked) }
                  }
                }
              }
            }

            // ===================== NETWORK =====================
            Column {
              id: networkList
              visible: root.activeView === "network"
              width: parent.width
              spacing: Style.space(4)

              PanelSectionHeader {
                text: "INTERFACES"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              EmptyHint {
                bar: root.bar
                visible: root.networkRows.length === 0
                text: root.networkLoaded ? "No network interfaces detected" : "Reading network interfaces…"
              }

              Repeater {
                model: root.networkRows

                ListRow {
                  id: netRow
                  required property var modelData
                  readonly property bool isUp: modelData.state === "UP"
                  readonly property var addresses: modelData.addresses || []
                  readonly property string actionKey: "net:" + modelData.name
                  readonly property bool confirming: root.confirmingAction === actionKey
                  readonly property bool working: root.pendingAction === actionKey

                  width: networkList.width
                  bar: root.bar
                  icon: modelData.type === "Wi-Fi" ? "󰖩" : (modelData.type === "Ethernet" ? "󰈀" : "󰩠")
                  title: modelData.name
                  subtitle: {
                    if (addresses.length > 0 && root.copiedAddress === addresses[0])
                      return "Copied " + addresses[0]
                    var parts = [modelData.type, root.titleCase(modelData.state)]
                    if (addresses.length > 0) parts.push(addresses[0])
                    return parts.join("  ·  ")
                  }
                  subtitleColor: isUp ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.5)
                  clickable: addresses.length > 0
                  onClicked: root.copyAddress(addresses[0])
                  tooltipText: {
                    var lines = []
                    if (addresses.length > 0) lines.push("Click to copy " + addresses[0])
                    if (modelData.mac) lines.push("MAC " + modelData.mac)
                    for (var i = 1; i < addresses.length; i++) lines.push(addresses[i])
                    return lines.join("\n")
                  }

                  PanelActionButton {
                    visible: netRow.modelData.canDisconnect === true || netRow.modelData.canConnect === true
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: netRow.working ? "󰔟"
                      : (netRow.confirming ? "󰄬"
                        : (netRow.modelData.canDisconnect ? "󰌙" : "󰌘"))
                    tooltipText: netRow.confirming
                      ? "Click again to disconnect"
                      : (netRow.modelData.canDisconnect ? "Disconnect" : "Connect")
                    foreground: netRow.confirming ? root.bar.urgent : root.bar.foreground
                    hoverColor: netRow.modelData.canDisconnect ? root.bar.urgent : root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    enabled: root.pendingAction === ""
                    onClicked: root.setInterfaceConnected(netRow.modelData.name, !netRow.modelData.canDisconnect)
                  }
                }
              }
            }

            // ===================== DISPLAYS ====================
            Column {
              id: displayList
              visible: root.activeView === "external"
              width: parent.width
              spacing: Style.space(4)

              PanelSectionHeader {
                text: "DISPLAYS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              EmptyHint {
                bar: root.bar
                visible: root.externalDisplays.length === 0
                text: root.externalLoaded
                  ? "No external displays. Monitors on HDMI, DisplayPort, or USB-C show up here and can be turned off or on. Your laptop screen is never touched."
                  : "Reading displays…"
              }

              Repeater {
                model: root.externalDisplays

                ListRow {
                  id: displayRow
                  required property var modelData
                  readonly property string actionKey: "display:" + modelData.connector
                  readonly property bool confirming: root.confirmingAction === actionKey
                  readonly property bool working: root.pendingAction === actionKey

                  width: displayList.width
                  bar: root.bar
                  icon: "󰍹"
                  title: modelData.name || "External display"
                  subtitle: [modelData.connector, modelData.mode, modelData.status]
                    .filter(function(x) { return !!x }).join("  ·  ")
                  subtitleColor: modelData.status === "Enabled"
                    ? root.bar.foreground
                    : Qt.darker(root.bar.foreground, 1.5)
                  tooltipText: modelData.status === "Enabled" && modelData.canTurnOff !== true
                    ? "This is the only screen that is on, so it can't be turned off"
                    : ""

                  PanelActionButton {
                    visible: displayRow.modelData.canTurnOff === true || displayRow.modelData.canTurnOn === true
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: displayRow.working ? "󰔟"
                      : (displayRow.confirming ? "󰄬"
                        : (displayRow.modelData.canTurnOff ? "󰶐" : "󰍹"))
                    tooltipText: displayRow.confirming
                      ? "Click again to turn off (it comes back on reload, logout, or reboot)"
                      : (displayRow.modelData.canTurnOff ? "Turn off" : "Turn back on")
                    foreground: displayRow.confirming ? root.bar.urgent : root.bar.foreground
                    hoverColor: displayRow.modelData.canTurnOff ? root.bar.urgent : root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    enabled: root.pendingAction === ""
                    onClicked: root.setDisplayOn(displayRow.modelData.connector, !displayRow.modelData.canTurnOff)
                  }
                }
              }
            }

            // =================== THUNDERBOLT ===================
            Column {
              id: thunderboltList
              visible: root.activeView === "thunderbolt"
              width: parent.width
              spacing: Style.space(4)

              PanelSectionHeader {
                text: "THUNDERBOLT"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              EmptyHint {
                bar: root.bar
                visible: root.thunderboltDevices.length === 0
                text: !root.thunderboltLoaded
                  ? "Reading Thunderbolt devices…"
                  : (!root.thunderboltAvailable
                      ? "Thunderbolt support unavailable (boltctl not installed)"
                      : (!root.thunderboltController
                          ? "This computer has no Thunderbolt or USB4 port, so nothing will show up here. You can hide this tab in Settings."
                          : "Nothing connected. Thunderbolt docks, eGPUs, and drives show up here, and new ones can be authorized."))
              }

              Repeater {
                model: root.thunderboltDevices

                ListRow {
                  id: tbRow
                  required property var modelData
                  readonly property bool working: root.pendingAction === "tb:" + modelData.uuid

                  width: thunderboltList.width
                  bar: root.bar
                  icon: "󱐋"
                  title: modelData.name || "Thunderbolt device"
                  subtitle: [modelData.vendor, modelData.type, modelData.status]
                    .filter(function(x) { return !!x }).join("  ·  ") || "Connected"
                  subtitleColor: String(modelData.status).indexOf("authorized") !== -1
                    ? root.bar.foreground
                    : Qt.darker(root.bar.foreground, 1.5)
                  tooltipText: modelData.uuid ? "UUID " + modelData.uuid : ""

                  PanelActionButton {
                    visible: tbRow.modelData.canAuthorize === true
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: tbRow.working ? "󰔟" : "󰕥"
                    tooltipText: "Authorize for this session (unplugging undoes it)"
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                    enabled: root.pendingAction === ""
                    onClicked: root.authorizeThunderbolt(tbRow.modelData.uuid)
                  }
                }
              }
            }

            // ==================== DEV PORTS ====================
            Column {
              id: devPortList
              visible: root.activeView === "devports"
              width: parent.width
              spacing: Style.space(4)

              PanelSectionHeader {
                text: "LISTENING PORTS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              EmptyHint {
                bar: root.bar
                visible: root.devPorts.length === 0
                text: !root.devPortsLoaded
                  ? "Reading listening ports…"
                  : (root.devPortsScope === "all"
                      ? "Nothing of yours is listening on a port"
                      : "No dev servers listening")
              }

              Repeater {
                model: root.devPorts

                ListRow {
                  id: portRow
                  required property var modelData
                  readonly property bool confirming: root.confirmingStopPid === modelData.pid
                  readonly property bool stopping: root.pendingDevPortKill === modelData.pid
                  readonly property var ports: modelData.ports || [modelData.port]
                  readonly property var folded: modelData.children || []
                  readonly property string childSummary: root.devPortChildren(folded)

                  width: devPortList.width
                  bar: root.bar
                  icon: root.devPortIcon(modelData.kind)
                  title: (modelData.name || modelData.process) + "  :" + modelData.port
                  subtitle: {
                    var parts = [root.devPortExposure(modelData.exposure)]
                    if (modelData.protocol === "udp") parts.push("UDP")
                    if (ports.length > 1) parts.push(ports.length + " ports")
                    if (childSummary) parts.push(childSummary)
                    parts.push(root.folderName(modelData.project))
                    return parts.filter(function(x) { return !!x }).join("  ·  ")
                  }
                  tooltipText: {
                    var lines = [modelData.command, modelData.cwd]
                    lines.push("PID " + modelData.pid + "  ·  "
                      + (ports.length === 1 ? "port " : "ports ") + ports.join(", "))
                    for (var i = 0; i < folded.length; i++) {
                      var c = folded[i]
                      var where = root.folderName(c.project)
                      lines.push(c.name + (where ? " in " + where : "") + "  ·  PID " + c.pid)
                    }
                    return lines.filter(function(x) { return !!x }).join("\n")
                  }

                  PanelActionButton {
                    visible: portRow.modelData.killable === true
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: portRow.stopping ? "󰔟" : (portRow.confirming ? "󰄬" : "󰅖")
                    tooltipText: portRow.confirming
                      ? "Click again to stop"
                      : (portRow.childSummary ? "Stop, with its " + portRow.childSummary : "Stop process")
                    foreground: portRow.confirming ? root.bar.urgent : root.bar.foreground
                    hoverColor: root.bar.urgent
                    fontFamily: root.bar.fontFamily
                    enabled: root.pendingDevPortKill === -1
                    onClicked: root.requestStopDevPort(portRow.modelData)
                  }
                }
              }
            }

            // ===================== SETTINGS ====================
            SettingsView {
              visible: root.activeView === "settings"
              width: parent.width
              panel: root
            }

            // ====================== ABOUT ======================
            AboutView {
              visible: root.activeView === "about"
              width: parent.width
              panel: root
            }
          }
        }
      }
    }
  }
}
