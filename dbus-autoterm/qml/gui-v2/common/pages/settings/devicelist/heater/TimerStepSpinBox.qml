import QtQuick
import Victron.VenusOS

// Row for editing one of the HeaterPage "+minutes" step buttons. Built on
// ListButton (not ListSpinBox) so a single custom dialog opens. Shows the
// value with a "+" prefix, e.g. "+5min stepper   [+5min]".
ListButton {
	id: root

	property int from: 5
	property int to: 720
	property int stepSize: 5

	readonly property int _value: dataItem.valid ? dataItem.value : from

	readonly property alias dataItem: dataItem

	text: "+" + _value + "min stepper"
	secondaryText: "+" + _value + "min"
	enabled: dataItem.uid === "" || dataItem.valid

	onClicked: Global.dialogLayer.open(stepDialogComponent)

	VeQuickItem {
		id: dataItem
	}

	Component {
		id: stepDialogComponent

		ModalDialog {
			id: dialog

			property int minutes: root._value

			title: root.text
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_SetAndCancel
			acceptText: qsTr("Set")

			contentItem: ModalDialog.FocusableContentItem {
				Row {
					anchors.centerIn: parent
					spacing: Theme.geometry_listItem_content_spacing * 2

					Button {
						anchors.verticalCenter: parent.verticalCenter
						width: 64
						height: 64
						text: "−"
						font.pixelSize: Theme.font_size_h2
						flat: false
						backgroundColor: Theme.color_blue
						borderColor: Theme.color_blue
						enabled: dialog.minutes > root.from
						opacity: enabled ? 1.0 : 0.5
						onClicked: dialog.minutes = dialog.minutes - root.stepSize
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: "+" + dialog.minutes + "min"
						font.pixelSize: Theme.font_size_h1 * 1.2
						color: Theme.color_white
					}

					Button {
						anchors.verticalCenter: parent.verticalCenter
						width: 64
						height: 64
						text: "+"
						font.pixelSize: Theme.font_size_h2
						flat: false
						backgroundColor: Theme.color_blue
						borderColor: Theme.color_blue
						enabled: dialog.minutes < root.to
						opacity: enabled ? 1.0 : 0.5
						onClicked: dialog.minutes = dialog.minutes + root.stepSize
					}
				}
			}

			onAccepted: {
				dataItem.setValue(dialog.minutes)
			}
		}
	}
}
