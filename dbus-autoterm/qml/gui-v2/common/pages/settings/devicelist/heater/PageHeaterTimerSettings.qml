import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	title: "Timer settings"

	GradientListView {
		model: VisibleItemModel {
			Repeater {
				model: 3

				delegate: ListSpinBox {
					required property int index
					text: "Preset " + (index + 1)
					dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/" + index
					from: 30
					to: 720
					stepSize: 5
					suffix: "min"
				}
			}
		}
	}
}
