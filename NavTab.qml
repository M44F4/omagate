import QtQuick
import qs.Ui
import qs.Commons

// Icon-only tab in the OmaGate tab bar. Hover paints the shared hover fill;
// the active tab is full opacity with an accent underline. `badge` > 0 shows
// a small count (blocked devices on the USB tab).
CursorSurface {
  id: tab

  required property QtObject bar
  property string icon: ""
  property string label: ""
  property bool active: false
  property int badge: 0

  signal clicked()

  hasCursor: mouse.containsMouse
  foreground: bar.foreground
  implicitHeight: Style.space(32)

  Text {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Style.space(1)
    textFormat: Text.PlainText
    text: tab.icon
    color: tab.bar.foreground
    opacity: tab.active ? 1.0 : (mouse.containsMouse ? 0.8 : 0.5)
    font.family: tab.bar.fontFamily
    font.pixelSize: Style.font.heading

    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  Rectangle {
    visible: tab.active
    width: Style.space(20)
    height: Style.space(2)
    radius: height / 2
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(2)
    color: Color.accent
  }

  Rectangle {
    visible: tab.badge > 0
    width: Math.max(height, badgeText.implicitWidth + Style.space(6))
    height: Style.space(14)
    radius: height / 2
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: Style.space(4)
    anchors.topMargin: Style.space(2)
    color: Color.accent

    Text {
      id: badgeText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tab.badge > 99 ? "99+" : String(tab.badge)
      color: Color.background
      font.family: tab.bar.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tab.clicked()
  }

  PanelToolTip {
    visible: mouse.containsMouse
    text: tab.label
    fontFamily: tab.bar.fontFamily
  }
}
