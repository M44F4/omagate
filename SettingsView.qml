import QtQuick
import qs.Ui
import qs.Commons

// Settings page. Every row is a ListRow, so the page reads like the device
// lists. Switch rows toggle from anywhere on the row; choice rows use the
// native ButtonGroup chips. All values live on the Panel root (`panel`),
// which persists them to settings.json.
Column {
  id: settings

  required property var panel
  readonly property QtObject bar: panel.bar

  spacing: Style.space(14)

  // Inline components cannot see this file's `settings` id, so each one
  // takes `bar` explicitly from its call site.
  component Section: Column {
    id: section
    property QtObject bar: null
    property string title: ""
    width: parent ? parent.width : 0
    spacing: Style.space(4)

    PanelSectionHeader {
      text: section.title
      foreground: section.bar ? section.bar.foreground : Color.foreground
      fontFamily: section.bar ? section.bar.fontFamily : Style.font.family
    }
  }

  component SwitchRow: ListRow {
    id: switchRow
    property bool checked: false
    signal toggled(bool value)

    width: parent ? parent.width : 0
    wrapSubtitle: true
    clickable: true
    onClicked: switchRow.toggled(!switchRow.checked)

    ToggleSwitch {
      anchors.verticalCenter: parent.verticalCenter
      checked: switchRow.checked
      interactive: false
      foreground: switchRow.bar.foreground
    }
  }

  component ChoiceRow: ListRow {
    id: choiceRow
    property var options: []
    property string value: ""
    signal chosen(string value)

    width: parent ? parent.width : 0
    wrapSubtitle: true

    ButtonGroup {
      anchors.verticalCenter: parent.verticalCenter
      options: choiceRow.options
      value: choiceRow.value
      focusable: false
      spacing: Style.space(4)
      foreground: choiceRow.bar.foreground
      fontFamily: choiceRow.bar.fontFamily
      fontSize: Style.font.caption
      onChanged: function(v) { choiceRow.chosen(v) }
    }
  }

  Section {
    bar: settings.bar
    title: "GENERAL"

    ChoiceRow {
      bar: settings.bar
      icon: "󰋜"
      title: "Open on"
      subtitle: "Tab shown when OmaGate opens"
      options: [{ value: "usb", label: "USB" }, { value: "last", label: "Last tab" }]
      value: settings.panel.startView
      onChosen: function(v) { settings.panel.startView = v }
    }

    ChoiceRow {
      bar: settings.bar
      icon: "󰑐"
      title: "Auto-refresh"
      subtitle: "While open"
      options: [
        { value: "1", label: "1s" },
        { value: "2", label: "2s" },
        { value: "5", label: "5s" },
        { value: "0", label: "Off" }
      ]
      value: String(settings.panel.refreshInterval)
      onChosen: function(v) { settings.panel.refreshInterval = parseInt(v, 10) }
    }
  }

  Section {
    bar: settings.bar
    title: "TABS"

    SwitchRow {
      bar: settings.bar
      icon: "󰤨"
      title: "Network"
      checked: settings.panel.showNetworkTab
      onToggled: function(v) { settings.panel.showNetworkTab = v }
    }

    SwitchRow {
      bar: settings.bar
      icon: "󰍹"
      title: "Displays"
      checked: settings.panel.showDisplaysTab
      onToggled: function(v) { settings.panel.showDisplaysTab = v }
    }

    SwitchRow {
      bar: settings.bar
      icon: "󱐋"
      title: "Thunderbolt"
      checked: settings.panel.showThunderboltTab
      onToggled: function(v) { settings.panel.showThunderboltTab = v }
    }

    SwitchRow {
      bar: settings.bar
      icon: "󰆍"
      title: "Dev Ports"
      checked: settings.panel.showDevPortsTab
      onToggled: function(v) { settings.panel.showDevPortsTab = v }
    }
  }

  Section {
    bar: settings.bar
    title: "PORT GUARD"

    SwitchRow {
      bar: settings.bar
      icon: "󰂚"
      title: "Notify on new devices"
      subtitle: "Desktop notification when an untrusted USB device is plugged in while Port Guard is on"
      checked: settings.panel.notifyNewDevices
      onToggled: function(v) { settings.panel.notifyNewDevices = v }
    }

    ListRow {
      bar: settings.bar
      width: parent.width
      wrapSubtitle: true
      icon: "󰒃"
      title: "Trusted devices"
      subtitle: settings.panel.anyBlocked
        ? "Unblock devices before re-trusting"
        : settings.panel.trustedSummary

      Button {
        anchors.verticalCenter: parent.verticalCenter
        text: settings.panel.retrustBusy ? "Saving…" : "Re-trust"
        bordered: true
        foreground: settings.bar.foreground
        fontFamily: settings.bar.fontFamily
        fontSize: Style.font.caption
        verticalPadding: Style.spacing.md
        enabled: settings.panel.canRetrust
        opacity: enabled ? 1.0 : 0.45
        tooltipText: "Trust everything connected right now"
        onClicked: settings.panel.retrustDevices()
      }
    }

    // Always visible here, so the helper is discoverable even while Port
    // Guard is off (the USB tab only mentions it when Port Guard is on).
    ListRow {
      bar: settings.bar
      width: parent.width
      wrapSubtitle: true
      icon: settings.panel.helperReady ? "󰒃" : "󰀦"
      title: "Root helper"
      subtitle: settings.panel.helperReady
        ? "Installed (" + settings.panel.helperVersion + "). Block and write-protect are available"
        : (settings.panel.helperVersion === ""
            ? "Not installed. Block and write-protect need it: copy the command and run it in a terminal"
            : "Out of date (" + settings.panel.helperVersion + "). Copy the command and run it in a terminal")
      subtitleColor: settings.panel.helperReady ? Qt.darker(settings.bar.foreground, 1.5) : Color.accent
      tooltipText: settings.panel.helperReady ? "" : settings.panel.helperInstallCommand

      Button {
        visible: !settings.panel.helperReady
        anchors.verticalCenter: parent.verticalCenter
        text: settings.panel.helperCommandJustCopied ? "Copied" : "Copy command"
        bordered: true
        foreground: settings.bar.foreground
        fontFamily: settings.bar.fontFamily
        fontSize: Style.font.caption
        verticalPadding: Style.spacing.md
        tooltipText: settings.panel.helperInstallCommand
        onClicked: settings.panel.copyHelperCommand()
      }
    }
  }

  Section {
    bar: settings.bar
    title: "LISTS"

    SwitchRow {
      bar: settings.bar
      icon: "󱇰"
      title: "Show internal USB devices"
      subtitle: "Built-in parts such as the webcam, fingerprint reader or Bluetooth radio"
      checked: settings.panel.showInternalUsb
      onToggled: function(v) { settings.panel.showInternalUsb = v }
    }

    SwitchRow {
      bar: settings.bar
      icon: "󰩠"
      title: "Show virtual interfaces"
      subtitle: "Loopback, Docker, VPN and bridge interfaces in the Network tab"
      checked: settings.panel.showVirtualInterfaces
      onToggled: function(v) { settings.panel.showVirtualInterfaces = v }
    }
  }

  Section {
    bar: settings.bar
    title: "DEV PORTS"

    ChoiceRow {
      bar: settings.bar
      icon: "󰆍"
      title: "Show"
      subtitle: "Only dev servers can be stopped"
      options: [{ value: "dev", label: "Dev servers" }, { value: "all", label: "All" }]
      value: settings.panel.devPortsScope
      onChosen: function(v) { settings.panel.devPortsScope = v }
    }

    SwitchRow {
      bar: settings.bar
      icon: "󰀦"
      title: "Confirm before stopping"
      subtitle: "Click the stop button twice to end a process"
      checked: settings.panel.confirmStop
      onToggled: function(v) { settings.panel.confirmStop = v }
    }
  }

  PanelSeparator { foreground: settings.bar.foreground }

  ListRow {
    bar: settings.bar
    width: parent.width
    icon: "󰦛"
    title: "Reset settings to defaults"
    subtitle: "Port Guard and the trusted snapshot stay as they are"
    wrapSubtitle: true
    clickable: true
    onClicked: settings.panel.resetSettings()
  }
}
