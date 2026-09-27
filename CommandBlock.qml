import QtQuick
import qs.Ui
import qs.Commons

// Bordered strip with a monospace command and a copy button that swaps to a
// checkmark while `justCopied` is set. Clicking anywhere on the strip copies.
BorderSurface {
  id: block

  required property QtObject bar
  property string command: ""
  property bool justCopied: false

  signal copyRequested()

  width: parent ? parent.width : 0
  implicitHeight: Math.max(blockText.implicitHeight, copyButton.implicitHeight) + Style.space(12)
  radius: Style.cornerRadius

  color: stripMouse.containsMouse
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : Style.normalFillFor(bar.foreground, Color.accent)
  borderSpec: Border.controlSpec(stripMouse.containsMouse ? "hover-cursor" : "normal", bar.foreground, Color.accent)

  Behavior on color { ColorAnimation { duration: 60 } }

  MouseArea {
    id: stripMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: block.copyRequested()
  }

  Text {
    id: blockText
    anchors.left: parent.left
    anchors.right: copyButton.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(6)
    textFormat: Text.PlainText
    wrapMode: Text.WrapAnywhere
    text: block.command
    color: block.bar.foreground
    font.family: "monospace"
    font.pixelSize: Style.font.caption
  }

  PanelActionButton {
    id: copyButton
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: Style.space(4)
    iconText: block.justCopied ? "󰄬" : "󰆏"
    tooltipText: block.justCopied ? "Copied!" : "Copy"
    foreground: block.justCopied ? Color.accent : block.bar.foreground
    fontFamily: block.bar.fontFamily
    onClicked: block.copyRequested()
  }
}
