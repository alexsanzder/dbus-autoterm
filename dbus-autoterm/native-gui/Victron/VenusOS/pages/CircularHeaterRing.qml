import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS

Item {
	id: root

	property real valueRatio: 0.0
	property real strokeWidth: 22
	property color progressColor: Theme.color_blue
	property color remainderColor: Theme.color_gray1
	property color centerFillColor: Qt.rgba(0, 0, 0, 0.18)
	property color centerStrokeColor: Qt.rgba(1, 1, 1, 0.06)
	property color primaryValueColor: Theme.color_font_primary
	property color secondaryValueColor: Theme.color_listItem_secondaryText
	property color captionValueColor: Theme.color_listItem_secondaryText
	property string primaryValue: ""
	property string primaryUnit: ""
	property string secondaryValue: ""
	property string captionValue: ""
	property string captionUnit: ""
	property string statusValue: ""
	property real primaryValueFontScale: 1.8
	property real secondaryValueFontScale: 1.2

	readonly property real normalizedRatio: clamp(valueRatio, 0.0, 1.0)
	readonly property real startAngle: 225
	readonly property real endAngle: 495
	readonly property real arcRadius: (Math.min(width, height) / 2) - (strokeWidth / 2) - 2
	readonly property real centerDiameter: (arcRadius * 2) - (strokeWidth * 1.9)

	function clamp(value, minValue, maxValue) {
		return Math.max(minValue, Math.min(maxValue, value))
	}

	Item {
		id: ringBounds
		anchors.fill: parent

		ProgressArc {
			anchors.fill: parent
			radius: root.arcRadius
			strokeWidth: root.strokeWidth
			startAngle: root.startAngle
			endAngle: root.endAngle
			value: root.normalizedRatio * 100
			progressColor: root.progressColor
			remainderColor: root.remainderColor
		}

		Rectangle {
			width: root.centerDiameter
			height: root.centerDiameter
			anchors.centerIn: parent
			radius: width / 2
			color: root.centerFillColor
			border.width: 1
			border.color: root.centerStrokeColor

			Column {
				anchors.centerIn: parent
				spacing: 6

				// Active mode, right above the big value
				Label {
					anchors.horizontalCenter: parent.horizontalCenter
					visible: text !== ""
					text: root.statusValue
					font.pixelSize: Theme.font_size_caption
					color: root.captionValueColor
				}

				// Big center value: number with optional superscript unit (same style as captionValue/captionUnit)
				Item {
					id: primaryValueContainer
					anchors.horizontalCenter: parent.horizontalCenter
					width: primaryNumber.paintedWidth + (root.primaryUnit !== "" ? primaryUnitItem.paintedWidth + 3 : 0)
					height: Math.max(primaryNumber.paintedHeight, root.primaryUnit !== "" ? primaryUnitItem.paintedHeight : 0)
					visible: root.primaryValue !== ""

					Label {
						id: primaryNumber
						anchors.verticalCenter: parent.verticalCenter
						text: root.primaryValue
						font.pixelSize: Theme.font_size_h1 * root.primaryValueFontScale
						font.weight: Font.DemiBold
						color: root.primaryValueColor
					}

					Label {
						id: primaryUnitItem
						anchors {
							left: primaryNumber.right
							leftMargin: 3
							top: primaryNumber.top
							topMargin: 8
						}
						visible: root.primaryUnit !== ""
						text: root.primaryUnit
						font.pixelSize: Theme.font_size_body2
						color: root.primaryValueColor
					}
				}

				Label {
					anchors.horizontalCenter: parent.horizontalCenter
					visible: text !== ""
					text: root.secondaryValue
					font.pixelSize: Theme.font_size_body1 * root.secondaryValueFontScale
					font.bold: true
					color: root.secondaryValueColor
				}

				// HA thermostat style state caption under the big value
				// Current temperature with a thermometer icon at its left
				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					spacing: 6
					visible: root.captionValue !== ""

					CP.ColorImage {
						anchors.verticalCenter: parent.verticalCenter
						width: 20
						height: 20
						source: "qrc:/images/icon_temp_32.svg"
						fillMode: Image.PreserveAspectFit
						color: root.captionValueColor
					}

					// Number with the unit superscripted (e.g. 21°C)
					Item {
						width: captionNumber.paintedWidth + captionUnit.paintedWidth + 3
						height: Math.max(captionNumber.paintedHeight, captionUnit.paintedHeight)

						Label {
							id: captionNumber
							anchors.verticalCenter: parent.verticalCenter
							text: root.captionValue
							font.pixelSize: Theme.font_size_body1 * 1.4
							color: root.captionValueColor
						}

						// Superscript unit: smaller font raised to sit at the value's cap height.
						Label {
							id: captionUnit
							anchors {
								left: captionNumber.right
								leftMargin: 1
								top: captionNumber.top
								topMargin: 2
							}
							text: root.captionUnit
							font.pixelSize: Theme.font_size_caption
							color: root.captionValueColor
						}
					}
				}
			}
		}
	}
}
