import QtQuick
import qs.Ui
import qs.Commons

// About page: what OmaGate does, shortcuts, version, update command and repo
// link. `panel` is the OmaGate Panel root (separate files cannot see its id).
Column {
  id: about

  required property var panel
  readonly property QtObject bar: panel.bar

  spacing: Style.space(12)

  Text {
    width: parent.width
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: "OmaGate keeps watch over what is plugged into your machine. Eject "
      + "or write-protect USB drives in one click, and block USB devices you "
      + "don't trust. The other tabs show your network interfaces, displays, "
      + "Thunderbolt devices, and the dev servers listening on your ports."
    color: Qt.darker(about.bar.foreground, 1.2)
    font.family: about.bar.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: "Port Guard trusts everything connected the first time you turn it "
      + "on (re-trust any time in Settings), so your keyboard, mouse, and "
      + "dock are never blocked. Only devices plugged in later can be. "
      + "Turning it off restores access to everything at once."
    color: Qt.darker(about.bar.foreground, 1.4)
    font.family: about.bar.fontFamily
    font.pixelSize: Style.font.caption
  }

  PanelSeparator { foreground: about.bar.foreground }

  PanelSectionHeader {
    text: "SHORTCUTS"
    foreground: about.bar.foreground
    fontFamily: about.bar.fontFamily
  }

  Column {
    width: parent.width
    spacing: Style.space(4)

    Repeater {
      model: [
        { key: "h / l", label: "Previous / next tab" },
        { key: "r", label: "Refresh the current tab" },
        { key: "Esc", label: "Close OmaGate" },
        { key: "Right-click", label: "Bar icon: turn Port Guard on or off" }
      ]

      Item {
        required property var modelData
        width: parent.width
        implicitHeight: Math.max(keyText.implicitHeight, labelText.implicitHeight)

        Text {
          id: keyText
          width: Style.space(90)
          textFormat: Text.PlainText
          text: modelData.key
          color: about.bar.foreground
          font.family: about.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          id: labelText
          anchors.left: keyText.right
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: modelData.label
          color: Qt.darker(about.bar.foreground, 1.4)
          font.family: about.bar.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  PanelSeparator { foreground: about.bar.foreground }

  Item {
    width: parent.width
    implicitHeight: Math.max(aboutSectionLabel.implicitHeight, aboutVersionText.implicitHeight)

    PanelSectionHeader {
      id: aboutSectionLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "ABOUT"
      foreground: about.bar.foreground
      fontFamily: about.bar.fontFamily
    }

    Text {
      id: aboutVersionText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "OmaGate" + (about.panel.appVersion.length > 0 ? " " + about.panel.appVersion : "")
      color: Qt.darker(about.bar.foreground, 1.4)
      font.family: about.bar.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  CommandBlock {
    bar: about.bar
    command: about.panel.updateCommand
    justCopied: about.panel.updateCommandJustCopied
    onCopyRequested: about.panel.copyUpdateCommand()
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: "Enjoying OmaGate? A star helps others find it:"
    color: Qt.darker(about.bar.foreground, 1.4)
    font.family: about.bar.fontFamily
    font.pixelSize: Style.font.caption
  }

  CommandBlock {
    bar: about.bar
    command: about.panel.repoUrl
    justCopied: about.panel.repoUrlJustCopied
    onCopyRequested: about.panel.copyRepoUrl()
  }
}
