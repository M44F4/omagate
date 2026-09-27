import QtQuick
import qs.Ui
import qs.Commons

// One USB device in the OmaGate USB tab, drawn with the shared ListRow.
//
// Storage rows carry eject plus a write-protect lock; other USB devices carry
// the block switch. Write-protect and block are privileged (pkexec) and only
// ever shown while Port Guard itself is on (`guardEnabled`): a control that
// still fires privileged actions while its own master switch reads "off" is
// exactly the confusing half-state this row is built to avoid. Block is also
// gated on the three safety guards (`blockEligible`, computed by the caller
// -- see Panel.qml), which omagate-block.sh re-verifies itself regardless of
// what this row believes. Both also need the root-owned helper to be
// installed and current (`helperReady`); until then they stay hidden.
ListRow {
  id: row

  required property var device
  required property bool guardEnabled
  // The root-owned privileged helper is installed and current.
  property bool helperReady: false
  property bool blockEligible: false
  property bool busy: false
  property bool writeProtectBusy: false
  property bool blockBusy: false

  signal ejectRequested()
  signal writeProtectToggled(bool readOnly)
  signal blockToggled(bool blocked)

  readonly property bool isStorage: !!device && device.kind === "storage"
  readonly property bool isBlocked: !!device && device.authorized === false
  readonly property bool isReadOnly: !!device && device.readonly === true
  // Read-only set by something else (a udev rule, a write blocker): shown,
  // but OmaGate never offers to undo it.
  readonly property bool foreignReadOnly: row.isReadOnly && device.omagateReadOnly !== true
  readonly property bool showWriteProtect: row.isStorage && row.guardEnabled && row.helperReady && !row.foreignReadOnly
  readonly property bool ownBlock: !!device && device.omagateBlocked === true
  readonly property bool showBlock: !row.isStorage && row.guardEnabled && row.helperReady
    && ((row.blockEligible && !row.isBlocked) || row.ownBlock)

  function hasInterfaceClass(cls) {
    var list = String(row.device && row.device.interfaceClass || "").split(",")
    return list.indexOf(cls) !== -1
  }

  readonly property string typeIcon: {
    if (row.isBlocked) return "󰦝"
    if (row.isStorage) return "󱊞"
    var hid = row.device ? row.device.hidKind : ""
    if (hid === "mouse") return "󰍽"
    if (hid === "keyboard") return "󰌌"
    if (row.hasInterfaceClass("01")) return "󰋋"
    if (row.hasInterfaceClass("0e")) return "󰖠"
    if (row.hasInterfaceClass("e0")) return "󰂯"
    if (row.hasInterfaceClass("07")) return "󰐪"
    // A phone shows up as MTP/PTP (class 06), often with USB tethering
    // (02/0a) too, so check for it before the network adapter case.
    if (row.hasInterfaceClass("06") || /android|iphone|phone/i.test(row.device ? row.device.name : "")) return "󰄜"
    if (row.hasInterfaceClass("02") || row.hasInterfaceClass("0a")) return "󰈀"
    return "󱇰"
  }

  readonly property string statusText: {
    if (row.isStorage) {
      if (row.busy) return "Ejecting…"
      var parts = [row.device.mountpoint ? row.device.mountpoint : "Not mounted"]
      if (row.isReadOnly) parts.push(row.foreignReadOnly ? "Read-only (set outside OmaGate)" : "Read-only")
      return parts.join("  ·  ")
    }
    if (row.isBlocked) return row.ownBlock ? "Blocked" : "Blocked by another policy"
    if (row.device && row.device.trusted) return "Trusted"
    if (row.device && row.device.removable === false) return "Internal"
    return "Connected"
  }

  icon: row.typeIcon
  iconColor: row.isBlocked ? row.bar.urgent : row.bar.foreground
  title: row.device ? row.device.name : ""
  subtitle: row.statusText
  subtitleColor: row.isBlocked
    ? row.bar.urgent
    : (row.isStorage && row.device.mountpoint ? row.bar.foreground : Qt.darker(row.bar.foreground, 1.5))
  tooltipText: row.device && row.device.sysfsPort ? "USB port " + row.device.sysfsPort : ""

  PanelActionButton {
    visible: row.showWriteProtect
    anchors.verticalCenter: parent.verticalCenter
    iconText: row.writeProtectBusy ? "󰔟" : (row.isReadOnly ? "󰌾" : "󰿆")
    tooltipText: row.isReadOnly ? "Allow writes" : "Make read-only"
    foreground: row.isReadOnly ? Color.accent : row.bar.foreground
    fontFamily: row.bar.fontFamily
    enabled: !row.writeProtectBusy && !row.busy
    onClicked: row.writeProtectToggled(!row.isReadOnly)
  }

  PanelActionButton {
    visible: row.isStorage
    anchors.verticalCenter: parent.verticalCenter
    iconText: row.busy ? "󰔟" : "󰇪"
    tooltipText: "Eject"
    foreground: row.bar.foreground
    fontFamily: row.bar.fontFamily
    enabled: !row.busy
    onClicked: row.ejectRequested()
  }

  ToggleSwitch {
    id: blockSwitch
    visible: row.showBlock
    anchors.verticalCenter: parent.verticalCenter
    checked: row.isBlocked
    busy: row.blockBusy
    foreground: row.bar.foreground
    onToggled: row.blockToggled(!row.isBlocked)

    PanelToolTip {
      visible: blockSwitch.containsMouse
      text: row.isBlocked ? "Reauthorize device" : "Block device at the port"
      fontFamily: row.bar.fontFamily
    }
  }
}
