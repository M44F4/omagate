import QtQuick
import qs.Ui
import qs.Commons

// The one row style every OmaGate list uses, Settings included. Mirrors the
// native Bluetooth/Wi-Fi rows: a CursorSurface that lights up on hover, a
// fixed-width icon slot (so titles line up whatever the glyph width), a body
// title over an optional caption subtitle, and a trailing slot for controls.
//
// Hover comes from a HoverHandler rather than a MouseArea: it is passive, so
// the row stays lit while the pointer sits on one of its own trailing
// buttons instead of flickering off.
CursorSurface {
  id: row

  required property QtObject bar

  property string icon: ""
  property color iconColor: bar.foreground
  property string title: ""
  property string subtitle: ""
  property color subtitleColor: Qt.darker(bar.foreground, 1.5)
  property bool wrapSubtitle: false
  property string tooltipText: ""
  property bool clickable: false

  default property alias trailing: trailingRow.data

  signal clicked()

  hasCursor: rowHover.hovered
  foreground: bar.foreground
  implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX

  HoverHandler { id: rowHover }

  // Declared before the content so trailing controls stay on top of it and
  // keep their own clicks.
  MouseArea {
    anchors.fill: parent
    enabled: row.clickable
    cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: row.clicked()
  }

  Item {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    implicitHeight: Math.max(iconGlyph.implicitHeight, info.implicitHeight, trailingRow.implicitHeight)

    Item {
      id: iconSlot
      visible: row.icon !== ""
      width: visible ? Math.round(Style.font.heading * 1.35) : 0
      height: iconGlyph.implicitHeight
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter

      Text {
        id: iconGlyph
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: row.icon
        color: row.iconColor
        font.family: row.bar.fontFamily
        font.pixelSize: Style.font.heading
      }
    }

    Column {
      id: info
      anchors.left: iconSlot.right
      anchors.leftMargin: iconSlot.visible ? Style.space(10) : 0
      anchors.right: trailingRow.left
      anchors.rightMargin: trailingRow.width > 0 ? Style.space(8) : 0
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        textFormat: Text.PlainText
        text: row.title
        color: row.bar.foreground
        font.family: row.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        textFormat: Text.PlainText
        visible: row.subtitle !== ""
        text: row.subtitle
        color: row.subtitleColor
        font.family: row.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: row.wrapSubtitle ? Text.WordWrap : Text.NoWrap
        elide: row.wrapSubtitle ? Text.ElideNone : Text.ElideRight
        width: parent.width
      }
    }

    Row {
      id: trailingRow
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      HoverHandler { id: trailingHover }
    }
  }

  // Suppressed over the trailing controls, which carry their own tooltips.
  PanelToolTip {
    visible: row.tooltipText !== "" && rowHover.hovered && !trailingHover.hovered
    text: row.tooltipText
    fontFamily: row.bar.fontFamily
  }
}
