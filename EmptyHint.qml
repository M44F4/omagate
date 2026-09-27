import QtQuick
import qs.Commons

// Empty / loading line under a section header, styled like the native
// Bluetooth panel's "Scanning for devices…" text.
Text {
  required property QtObject bar

  width: parent ? parent.width : 0
  textFormat: Text.PlainText
  color: Qt.darker(bar.foreground, 1.5)
  font.family: bar.fontFamily
  font.pixelSize: Style.font.bodySmall
  wrapMode: Text.WordWrap
}
